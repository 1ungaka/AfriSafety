import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/alert_codec.dart';
import '../../../core/crypto/location_codec.dart';
import '../../../core/logging/safe_logger.dart';
import '../../circles/domain/circles_controller.dart';
import '../../circles/domain/models.dart';
import '../../session/domain/session_controller.dart';
import '../../sharing/domain/sharing_controller.dart';

const _log = SafeLogger('panic');

enum PanicPhase { idle, countingDown, active }

enum DeliveryStatus { sending, sent, delivered, seen }

class Delivery {
  const Delivery({
    required this.userId,
    required this.name,
    required this.status,
  });

  final String userId;
  final String name;
  final DeliveryStatus status;
}

class PanicState {
  const PanicState({
    this.phase = PanicPhase.idle,
    this.secondsLeft = 0,
    this.incidentId,
    this.fix,
    this.deliveries = const [],
    this.allSent = false,
    this.showSmsFallback = false,
    this.noCircles = false,
  });

  final PanicPhase phase;
  final int secondsLeft;
  final String? incidentId;
  final LocationFix? fix;
  final List<Delivery> deliveries;

  /// Every Circle's alert is stored on the server.
  final bool allSent;

  /// No server acknowledgement in time (no data?): offer the SMS app.
  final bool showSmsFallback;

  /// Not in any Circle yet: only SMS and emergency numbers can help.
  final bool noCircles;

  PanicState copyWith({
    PanicPhase? phase,
    int? secondsLeft,
    String? incidentId,
    LocationFix? fix,
    List<Delivery>? deliveries,
    bool? allSent,
    bool? showSmsFallback,
    bool? noCircles,
  }) => PanicState(
    phase: phase ?? this.phase,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    incidentId: incidentId ?? this.incidentId,
    fix: fix ?? this.fix,
    deliveries: deliveries ?? this.deliveries,
    allSent: allSent ?? this.allSent,
    showSmsFallback: showSmsFallback ?? this.showSmsFallback,
    noCircles: noCircles ?? this.noCircles,
  );
}

/// Seconds between pressing SOS and the alert going out; cancel any time.
const panicCountdownSeconds = 3;

/// If the server hasn't confirmed by then, offer SMS straight away.
const smsFallbackAfter = Duration(seconds: 10);

final panicControllerProvider = NotifierProvider<PanicController, PanicState>(
  PanicController.new,
);

class PanicController extends Notifier<PanicState> {
  Timer? _countdown;
  Timer? _fallback;
  StreamSubscription<void>? _receiptSub;
  final Map<String, String> _alertCircle = {}; // alertId -> circleId
  final Set<String> _sent = {};
  bool _resolved = false;

  @override
  PanicState build() {
    ref.onDispose(_cleanup);
    return const PanicState();
  }

  void _cleanup() {
    _countdown?.cancel();
    _fallback?.cancel();
    _receiptSub?.cancel();
  }

  /// SOS pressed: start the cancellable countdown.
  void start() {
    if (state.phase != PanicPhase.idle) return;
    state = const PanicState(
      phase: PanicPhase.countingDown,
      secondsLeft: panicCountdownSeconds,
    );
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      final left = state.secondsLeft - 1;
      if (left <= 0) {
        t.cancel();
        unawaited(_send());
      } else {
        state = state.copyWith(secondsLeft: left);
      }
    });
  }

  void cancel() {
    if (state.phase != PanicPhase.countingDown) return;
    _countdown?.cancel();
    state = const PanicState();
  }

  /// Skip the countdown (the "Send now" button).
  void sendNow() {
    if (state.phase != PanicPhase.countingDown) return;
    _countdown?.cancel();
    unawaited(_send());
  }

  Future<void> _send() async {
    _resolved = false;
    _alertCircle.clear();
    _sent.clear();
    final incidentId = const Uuid().v4();
    final circles = ref.read(circlesControllerProvider).value?.circles ?? [];
    state = state.copyWith(
      phase: PanicPhase.active,
      incidentId: incidentId,
      noCircles: circles.isEmpty,
      showSmsFallback: circles.isEmpty,
      deliveries: _initialDeliveries(circles),
    );
    if (circles.isEmpty) return;

    unawaited(ref.read(sharingControllerProvider.notifier).setEmergency(true));
    _fallback = Timer(smsFallbackAfter, () {
      if (!state.allSent) state = state.copyWith(showSmsFallback: true);
    });

    final fix = await _bestFix();
    if (fix != null) state = state.copyWith(fix: fix);
    final payload = AlertPayload(
      kind: AlertKind.panic,
      raisedAt: DateTime.now().toUtc(),
      fix: fix,
    );

    _receiptSub = ref
        .read(alertsRepositoryProvider)
        .receiptChanges()
        .listen((_) => unawaited(_refreshReceipts()));

    await Future.wait([
      for (final c in circles) _sendToCircle(c.circle.id, incidentId, payload),
    ]);
  }

  /// A recent fix from the sharing stream, else a quick fresh one. The alert
  /// never waits more than a few seconds for GPS.
  Future<LocationFix?> _bestFix() async {
    final recent = ref.read(sharingControllerProvider).lastFix;
    if (recent != null &&
        DateTime.now().toUtc().difference(recent.recordedAt) <
            const Duration(minutes: 2)) {
      return recent;
    }
    return ref
        .read(locationSourceProvider)
        .current(timeout: const Duration(seconds: 5));
  }

  /// Retries with backoff until stored or the user marks themselves safe.
  Future<void> _sendToCircle(
    String circleId,
    String incidentId,
    AlertPayload payload,
  ) async {
    final keys = ref.read(keySyncServiceProvider);
    final identity = ref.read(identityProvider);
    if (keys == null || identity == null) return;
    final repo = ref.read(alertsRepositoryProvider);
    final alertId = const Uuid().v4();
    _alertCircle[alertId] = circleId;

    var attempt = 0;
    while (!_resolved) {
      try {
        var sealed = keys.encryptAlert(circleId, payload);
        if (sealed == null) {
          await keys.syncCircle(circleId);
          sealed = keys.encryptAlert(circleId, payload);
        }
        if (sealed == null) throw StateError('no alert key yet');
        await repo.insert(
          id: alertId,
          incidentId: incidentId,
          circleId: circleId,
          deviceId: identity.deviceId,
          keyVersion: sealed.keyVersion,
          ciphertext: sealed.ciphertext,
        );
        _sent.add(alertId);
        _markSent(circleId);
        // Push is best effort: Realtime also delivers while apps are open.
        unawaited(
          repo
              .dispatch([alertId])
              .catchError(
                (Object e) => _log.warning('Push dispatch failed', e),
              ),
        );
        if (_sent.length == _alertCircle.length) {
          state = state.copyWith(allSent: true);
        }
        return;
      } on Object catch (e) {
        attempt++;
        _log.warning('Alert send failed (attempt $attempt); retrying', e);
        final wait = Duration(seconds: math.min(15, 1 << math.min(attempt, 4)));
        await Future<void>.delayed(wait);
      }
    }
  }

  List<Delivery> _initialDeliveries(List<CircleView> circles) {
    final seen = <String>{};
    return [
      for (final c in circles)
        for (final m in c.others)
          if (seen.add(m.userId))
            Delivery(
              userId: m.userId,
              name: m.displayName,
              status: DeliveryStatus.sending,
            ),
    ];
  }

  void _markSent(String circleId) {
    final circle = ref
        .read(circlesControllerProvider)
        .value
        ?.circles
        .where((c) => c.circle.id == circleId)
        .firstOrNull;
    final members = {
      for (final m in circle?.others ?? const <CircleMember>[]) m.userId,
    };
    state = state.copyWith(
      deliveries: [
        for (final d in state.deliveries)
          members.contains(d.userId) && d.status == DeliveryStatus.sending
              ? Delivery(
                  userId: d.userId,
                  name: d.name,
                  status: DeliveryStatus.sent,
                )
              : d,
      ],
    );
  }

  Future<void> _refreshReceipts() async {
    if (_sent.isEmpty) return;
    final receipts = await ref
        .read(alertsRepositoryProvider)
        .receipts(_sent.toList());
    final best = <String, DeliveryStatus>{};
    for (final r in receipts) {
      final status = r.seen ? DeliveryStatus.seen : DeliveryStatus.delivered;
      final prev = best[r.recipientId];
      if (prev == null || status.index > prev.index) {
        best[r.recipientId] = status;
      }
    }
    state = state.copyWith(
      deliveries: [
        for (final d in state.deliveries)
          if (best[d.userId] case final s? when s.index > d.status.index)
            Delivery(userId: d.userId, name: d.name, status: s)
          else
            d,
      ],
    );
  }

  /// "I am safe, end alert".
  Future<void> resolve() async {
    _resolved = true;
    final incidentId = state.incidentId;
    _cleanup();
    state = const PanicState();
    unawaited(ref.read(sharingControllerProvider.notifier).setEmergency(false));
    if (incidentId != null) {
      try {
        await ref.read(alertsRepositoryProvider).resolveIncident(incidentId);
      } on Object catch (e) {
        _log.warning('Could not mark incident resolved', e);
      }
    }
  }
}
