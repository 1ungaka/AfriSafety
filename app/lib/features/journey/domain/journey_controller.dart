import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/alert_codec.dart';
import '../../../core/crypto/event_codec.dart';
import '../../../core/crypto/location_codec.dart';
import '../../../core/geo/geo.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/storage/local_vault.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../circles/domain/circles_controller.dart';
import '../../events/domain/circle_events_controller.dart';
import '../../session/domain/session_controller.dart';
import '../../sharing/data/location_source.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/checkins_repository.dart';
import 'eta.dart';

const _log = SafeLogger('journey');

final checkInsRepositoryProvider = Provider<CheckInsRepository>(
  (ref) => SupabaseCheckInsRepository(ref.watch(supabaseProvider)),
);

/// Where a journey is heading. Kept on this phone only; the Circle sees
/// just the name in the encrypted "on the way" event.
class Destination {
  const Destination({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;

  @override
  String toString() => 'Destination(redacted)';
}

class ActiveCheckIn {
  const ActiveCheckIn({
    required this.id,
    required this.kind,
    required this.deadline,
    this.destination,
    this.expectedBy,
    this.missed = false,
  });

  final String id;
  final CheckInKind kind;

  /// When the server raises the alert if nobody checks in.
  final DateTime deadline;
  final Destination? destination;

  /// Journeys: the expected arrival (the deadline adds a grace period).
  final DateTime? expectedBy;

  /// The deadline passed and the Circle was alerted.
  final bool missed;

  ActiveCheckIn copyWith({
    DateTime? deadline,
    DateTime? expectedBy,
    bool? missed,
  }) => ActiveCheckIn(
    id: id,
    kind: kind,
    deadline: deadline ?? this.deadline,
    destination: destination,
    expectedBy: expectedBy ?? this.expectedBy,
    missed: missed ?? this.missed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': destination?.name,
    'lat': destination?.latitude,
    'lon': destination?.longitude,
    'eta': expectedBy?.toIso8601String(),
  };
}

enum JourneyError { startFailed, finishFailed, noCircles }

class JourneyState {
  const JourneyState({this.active, this.busy = false, this.error});

  final ActiveCheckIn? active;
  final bool busy;
  final JourneyError? error;
}

typedef JourneyNotificationText = SharingNotificationText Function(
  ActiveCheckIn active,
);

final journeyControllerProvider =
    NotifierProvider<JourneyController, JourneyState>(JourneyController.new);

/// Check-in timer and "Walk me home".
///
/// Starting one stores a deadline on the server plus an escrowed alert for
/// each Circle (end-to-end encrypted; the server can't read it). Checking
/// in deletes the escrows. If the deadline passes first, the server's
/// watchdog releases them, so help is raised even if this phone is off,
/// broken or taken. While one runs, the phone tracks closely, refreshes the
/// escrowed location every couple of minutes, and ends a journey by itself
/// on arrival.
class JourneyController extends Notifier<JourneyState> {
  static const _vaultFile = 'journey';
  static const escrowRefreshEvery = Duration(minutes: 2);

  JourneyNotificationText? _notificationText;
  final Map<String, String> _alertIds = {};
  DateTime? _escrowedAt;
  bool _refreshing = false;

  CheckInsRepository get _repo => ref.read(checkInsRepositoryProvider);

  @override
  JourneyState build() {
    if (ref.watch(identityProvider) == null) return const JourneyState();
    ref.listen<LocationFix?>(
      sharingControllerProvider.select((s) => s.lastFix),
      (_, fix) {
        if (fix != null) unawaited(_onFix(fix));
      },
    );
    final sub = _repo.changes().listen((_) => unawaited(_syncStatus()));
    ref.onDispose(sub.cancel);
    unawaited(_restore());
    return const JourneyState();
  }

  /// Supplies the notification text (needs l10n), shown while one runs.
  void configure(JourneyNotificationText text) {
    final first = _notificationText == null;
    _notificationText = text;
    final active = state.active;
    if (first && active != null) unawaited(_track(active));
  }

  Future<void> startTimer(Duration duration) => _start(
    kind: CheckInKind.timer,
    deadline: DateTime.now().toUtc().add(duration),
  );

  Future<void> startJourney(Destination destination, int etaMinutes) {
    final expectedBy = DateTime.now().toUtc().add(
      Duration(minutes: etaMinutes),
    );
    return _start(
      kind: CheckInKind.journey,
      deadline: expectedBy.add(journeyGrace),
      destination: destination,
      expectedBy: expectedBy,
    );
  }

  Future<void> _start({
    required CheckInKind kind,
    required DateTime deadline,
    Destination? destination,
    DateTime? expectedBy,
  }) async {
    if (state.active != null || state.busy) return;
    final circles = ref.read(circlesControllerProvider).value?.circles ?? [];
    if (circles.isEmpty) {
      state = const JourneyState(error: JourneyError.noCircles);
      return;
    }
    state = const JourneyState(busy: true);
    final active = ActiveCheckIn(
      id: const Uuid().v4(),
      kind: kind,
      deadline: deadline,
      destination: destination,
      expectedBy: expectedBy,
    );
    _alertIds.clear();
    try {
      await _repo.start(id: active.id, kind: kind, deadline: deadline);
      // Every escrow must be in place before we say "you're covered".
      await _escrowAll(active, await _freshFix());
    } on Object catch (e) {
      _log.warning('Could not start check-in', e);
      try {
        await _repo.finish(active.id, cancelled: true);
      } on Object catch (_) {}
      state = const JourneyState(error: JourneyError.startFailed);
      return;
    }
    state = JourneyState(active: active);
    await _save(active);
    await _track(active);
    unawaited(
      _broadcast(
        kind == CheckInKind.journey
            ? CircleEvent(
                kind: CircleEventKind.journeyStarted,
                at: DateTime.now().toUtc(),
                label: destination?.name ?? '',
                until: expectedBy,
              )
            : CircleEvent(
                kind: CircleEventKind.checkInStarted,
                at: DateTime.now().toUtc(),
                until: deadline,
              ),
      ),
    );
  }

  /// "I'm OK" (timer) or "I've arrived" (journey).
  Future<void> checkIn() => _finish(cancelled: false);

  /// Ends a journey without claiming to have arrived.
  Future<void> cancel() => _finish(cancelled: true);

  /// Adds time, e.g. when a walk takes longer than expected.
  Future<void> extend(Duration by) async {
    final active = state.active;
    if (active == null || active.missed || state.busy) return;
    final next = active.copyWith(
      deadline: active.deadline.add(by),
      expectedBy: active.expectedBy?.add(by),
    );
    state = JourneyState(active: active, busy: true);
    try {
      await _repo.extend(active.id, next.deadline);
      state = JourneyState(active: next);
      await _save(next);
      await _track(next);
      unawaited(_refreshEscrows(force: true));
    } on Object catch (e) {
      _log.warning('Could not extend check-in', e);
      state = JourneyState(active: active, error: JourneyError.finishFailed);
    }
  }

  /// After a missed check-in: tell the Circle you're fine.
  Future<void> resolveMissed() async {
    final active = state.active;
    if (active == null || !active.missed) return;
    state = JourneyState(active: active, busy: true);
    try {
      await ref.read(alertsRepositoryProvider).resolveIncident(active.id);
    } on Object catch (e) {
      _log.warning('Could not resolve missed check-in', e);
      state = JourneyState(active: active, error: JourneyError.finishFailed);
      return;
    }
    unawaited(
      _broadcast(
        CircleEvent(
          kind: CircleEventKind.checkInOk,
          at: DateTime.now().toUtc(),
        ),
      ),
    );
    await _clear();
  }

  void dismissError() {
    state = JourneyState(active: state.active);
  }

  Future<void> _finish({required bool cancelled}) async {
    final active = state.active;
    if (active == null || active.missed || state.busy) return;
    state = JourneyState(active: active, busy: true);
    try {
      await _repo.finish(active.id, cancelled: cancelled);
    } on Object catch (e) {
      // Offline: keep the timer visibly running. The server will still
      // alert the Circle at the deadline unless this gets through.
      _log.warning('Could not finish check-in', e);
      state = JourneyState(active: active, error: JourneyError.finishFailed);
      return;
    }
    final now = DateTime.now().toUtc();
    final label = active.destination?.name ?? '';
    unawaited(
      _broadcast(switch ((active.kind, cancelled)) {
        (CheckInKind.journey, false) => CircleEvent(
          kind: CircleEventKind.journeyArrived,
          at: now,
          label: label,
        ),
        (CheckInKind.journey, true) => CircleEvent(
          kind: CircleEventKind.journeyEnded,
          at: now,
          label: label,
        ),
        (CheckInKind.timer, _) => CircleEvent(
          kind: CircleEventKind.checkInOk,
          at: now,
        ),
      }),
    );
    await _clear();
  }

  Future<void> _clear() async {
    state = const JourneyState();
    _alertIds.clear();
    _escrowedAt = null;
    try {
      await ref.read(localVaultProvider).writeJson(_vaultFile, null);
    } on Object catch (e) {
      _log.warning('Could not clear saved journey', e);
    }
    await ref.read(sharingControllerProvider.notifier).setJourney(false);
  }

  Future<void> _track(ActiveCheckIn active) async {
    await ref
        .read(sharingControllerProvider.notifier)
        .setJourney(true, text: _notificationText?.call(active));
  }

  @visibleForTesting
  Future<void> onFix(LocationFix fix) => _onFix(fix);

  Future<void> _onFix(LocationFix fix) async {
    final active = state.active;
    if (active == null || active.missed || state.busy) return;
    final dest = active.destination;
    if (dest != null &&
        fix.accuracyMeters <= 100 &&
        distanceMeters(
              fix.latitude,
              fix.longitude,
              dest.latitude,
              dest.longitude,
            ) <=
            arrivalRadiusMeters) {
      await checkIn();
      return;
    }
    await _refreshEscrows();
  }

  Future<void> _refreshEscrows({bool force = false}) async {
    final active = state.active;
    final last = _escrowedAt;
    if (active == null || _refreshing) return;
    if (!force &&
        last != null &&
        DateTime.now().toUtc().difference(last) < escrowRefreshEvery) {
      return;
    }
    _refreshing = true;
    try {
      await _escrowAll(active, ref.read(sharingControllerProvider).lastFix);
    } on Object catch (e) {
      // The earlier escrow still stands; try again on a later fix.
      _log.warning('Escrow refresh failed', e);
    } finally {
      _refreshing = false;
    }
  }

  /// Seals a "missed check-in" alert for every Circle and stores it with
  /// the server. Like an SOS, it goes to every Circle, paused or not.
  Future<void> _escrowAll(ActiveCheckIn active, LocationFix? fix) async {
    final keys = ref.read(keySyncServiceProvider);
    final identity = ref.read(identityProvider);
    if (keys == null || identity == null) throw StateError('not signed in');
    final payload = AlertPayload(
      kind: AlertKind.checkInMissed,
      raisedAt: active.deadline,
      fix: fix,
    );
    final circles = ref.read(circlesControllerProvider).value?.circles ?? [];
    for (final c in circles) {
      final circleId = c.circle.id;
      var sealed = keys.encryptAlert(circleId, payload);
      if (sealed == null) {
        await keys.syncCircle(circleId);
        sealed = keys.encryptAlert(circleId, payload);
      }
      if (sealed == null) throw StateError('no alert key yet');
      await _repo.putEscrow(
        checkInId: active.id,
        circleId: circleId,
        alertId: _alertIds.putIfAbsent(circleId, () => const Uuid().v4()),
        deviceId: identity.deviceId,
        keyVersion: sealed.keyVersion,
        ciphertext: sealed.ciphertext,
      );
    }
    _escrowedAt = DateTime.now().toUtc();
  }

  Future<LocationFix?> _freshFix() async {
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

  Future<void> _broadcast(CircleEvent event) async {
    try {
      await ref.read(circleEventSenderProvider).broadcast(event);
    } on Object catch (e) {
      _log.warning('Journey event failed', e);
    }
  }

  Future<void> _save(ActiveCheckIn active) async {
    try {
      await ref.read(localVaultProvider).writeJson(_vaultFile, active.toJson());
    } on Object catch (e) {
      _log.warning('Could not save journey', e);
    }
  }

  /// After a restart: pick up a running or missed check-in from the server,
  /// and its destination from the vault.
  Future<void> _restore() async {
    try {
      final row = await _repo.current();
      if (row == null) return;
      final saved = await ref.read(localVaultProvider).readJson(_vaultFile);
      final local = saved is Map<String, dynamic> && saved['id'] == row.id
          ? saved
          : null;
      final lat = local?['lat'];
      final lon = local?['lon'];
      final active = ActiveCheckIn(
        id: row.id,
        kind: row.kind,
        deadline: row.deadline,
        missed: row.status == CheckInStatus.missed,
        destination: lat is num && lon is num
            ? Destination(
                name: local?['name'] as String? ?? '',
                latitude: lat.toDouble(),
                longitude: lon.toDouble(),
              )
            : null,
        expectedBy: local?['eta'] is String
            ? DateTime.tryParse(local!['eta'] as String)
            : null,
      );
      if (state.active != null) return; // started meanwhile
      state = JourneyState(active: active);
      await _track(active);
    } on Object catch (e) {
      _log.warning('Could not restore check-in', e);
    }
  }

  Future<void> _syncStatus() async {
    final active = state.active;
    if (active == null || active.missed) return;
    try {
      final row = await _repo.current();
      if (row?.id == active.id && row?.status == CheckInStatus.missed) {
        state = JourneyState(active: active.copyWith(missed: true));
      }
    } on Object catch (e) {
      _log.warning('Check-in status refresh failed', e);
    }
  }
}
