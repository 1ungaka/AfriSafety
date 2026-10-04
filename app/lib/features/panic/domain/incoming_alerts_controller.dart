import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/alert_codec.dart';
import '../../../core/logging/safe_logger.dart';
import '../../circles/domain/circles_controller.dart';
import '../../keys/domain/key_sync_service.dart';
import '../../session/domain/session_controller.dart';
import '../data/alerts_repository.dart';

const _log = SafeLogger('alerts');

class IncomingAlert {
  const IncomingAlert({
    required this.alert,
    required this.senderName,
    required this.circleName,
    required this.payload,
  });

  final EncryptedAlert alert;
  final String senderName;
  final String circleName;

  /// Null if the alert couldn't be decrypted (keys not yet arrived). The
  /// alert is still shown: someone needs help even if details are missing.
  final AlertPayload? payload;
}

final incomingAlertsProvider =
    AsyncNotifierProvider<IncomingAlertsController, List<IncomingAlert>>(
      IncomingAlertsController.new,
    );

/// Unresolved alerts from other members (last 24 hours), kept live over
/// Realtime. Each one is acknowledged as delivered as soon as it's seen
/// here, so the sender's SOS screen updates.
class IncomingAlertsController extends AsyncNotifier<List<IncomingAlert>> {
  final Set<String> _acknowledged = {};

  @override
  Future<List<IncomingAlert>> build() async {
    final circles = ref.watch(circlesControllerProvider).value;
    if (ref.watch(identityProvider) == null || circles == null) return const [];
    final sub = ref
        .read(alertsRepositoryProvider)
        .alertChanges()
        .listen((_) => unawaited(refresh()));
    ref.onDispose(sub.cancel);
    return _load(circles);
  }

  Future<void> refresh() async {
    final circles = ref.read(circlesControllerProvider).value;
    if (circles == null) return;
    state = AsyncData(await _load(circles));
  }

  Future<List<IncomingAlert>> _load(CirclesState circles) async {
    final repo = ref.read(alertsRepositoryProvider);
    final keys = ref.read(keySyncServiceProvider);
    final alerts = await repo.activeAlertsForMe();
    if (alerts.isNotEmpty) await keys?.loadReceivedKeys();

    final result = <IncomingAlert>[];
    for (final a in alerts) {
      final view = circles.circles
          .where((c) => c.circle.id == a.circleId)
          .firstOrNull;
      final opened = keys?.decryptAlert(
        circleId: a.circleId,
        senderId: a.senderId,
        senderDeviceId: a.senderDeviceId,
        keyVersion: a.keyVersion,
        ciphertext: a.ciphertext,
      );
      result.add(
        IncomingAlert(
          alert: a,
          senderName:
              view?.members
                  .where((m) => m.userId == a.senderId)
                  .firstOrNull
                  ?.displayName ??
              '',
          circleName: view?.circle.name ?? '',
          payload: opened is OpenedOk<AlertPayload> ? opened.value : null,
        ),
      );
      if (_acknowledged.add(a.id)) {
        unawaited(
          repo
              .acknowledge(a.id, seen: false)
              .catchError((Object e) => _log.warning('Ack failed', e)),
        );
      }
    }
    return result;
  }

  /// The user opened the alert.
  Future<void> markSeen(String alertId) async {
    try {
      await ref.read(alertsRepositoryProvider).acknowledge(alertId, seen: true);
    } on Object catch (e) {
      _log.warning('Seen ack failed', e);
    }
  }
}
