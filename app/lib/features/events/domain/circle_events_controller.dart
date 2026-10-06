import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/event_codec.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../circles/domain/circles_controller.dart';
import '../../keys/domain/key_sync_service.dart';
import '../../session/domain/session_controller.dart';
import '../data/circle_events_repository.dart';

const _log = SafeLogger('events');

final circleEventsRepositoryProvider = Provider<CircleEventsRepository>(
  (ref) => SupabaseCircleEventsRepository(ref.watch(supabaseProvider)),
);

/// Sends an encrypted event to every Circle where the user is sharing.
/// Paused Circles get nothing: an event reveals where you are.
final circleEventSenderProvider = Provider<CircleEventSender>(
  CircleEventSender.new,
);

class CircleEventSender {
  CircleEventSender(this._ref);

  final Ref _ref;

  Future<void> broadcast(CircleEvent event) async {
    final keys = _ref.read(keySyncServiceProvider);
    final identity = _ref.read(identityProvider);
    if (keys == null || identity == null) return;
    final circles =
        _ref.read(circlesControllerProvider).value?.sharingIn ?? const [];
    final repo = _ref.read(circleEventsRepositoryProvider);
    for (final c in circles) {
      final circleId = c.circle.id;
      // Nobody here can see my location, so nobody could read it either.
      if (c.liveViewerCount == 0) continue;
      final id = const Uuid().v4();
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          var sealed = keys.encryptEvent(circleId, event);
          if (sealed == null) {
            await keys.syncCircle(circleId);
            sealed = keys.encryptEvent(circleId, event);
          }
          if (sealed == null) break;
          await repo.post(
            id: id,
            circleId: circleId,
            deviceId: identity.deviceId,
            keyVersion: sealed.keyVersion,
            ciphertext: sealed.ciphertext,
          );
          break;
        } on Object catch (e) {
          _log.warning('Event upload failed (attempt ${attempt + 1})', e);
          await Future<void>.delayed(Duration(seconds: 2 << attempt));
        }
      }
    }
  }
}

class FeedItem {
  const FeedItem({
    required this.id,
    required this.senderName,
    required this.circleName,
    required this.event,
    required this.postedAt,
  });

  final String id;
  final String senderName;
  final String circleName;
  final CircleEvent event;
  final DateTime postedAt;
}

final circleEventsFeedProvider =
    AsyncNotifierProvider<CircleEventsFeed, List<FeedItem>>(
      CircleEventsFeed.new,
    );

/// Other members' events from the last 24 hours that this device can
/// decrypt, newest first. Events from people who share "SOS only" with us
/// can't be opened and are simply left out.
class CircleEventsFeed extends AsyncNotifier<List<FeedItem>> {
  @override
  Future<List<FeedItem>> build() async {
    final circles = ref.watch(circlesControllerProvider).value;
    if (ref.watch(identityProvider) == null || circles == null) return const [];
    final sub = ref
        .read(circleEventsRepositoryProvider)
        .changes()
        .listen((_) => unawaited(refresh()));
    ref.onDispose(sub.cancel);
    return _load(circles);
  }

  Future<void> refresh() async {
    final circles = ref.read(circlesControllerProvider).value;
    if (circles == null) return;
    try {
      state = AsyncData(await _load(circles));
    } on Object catch (e) {
      _log.warning('Feed refresh failed', e);
    }
  }

  Future<List<FeedItem>> _load(CirclesState circles) async {
    final keys = ref.read(keySyncServiceProvider);
    if (keys == null) return const [];
    final rows = await ref
        .read(circleEventsRepositoryProvider)
        .recentFromOthers(const Duration(hours: 24));
    if (rows.isNotEmpty) await keys.loadReceivedKeys();
    final items = <FeedItem>[];
    final seen = <String>{};
    for (final r in rows) {
      final view = circles.circles
          .where((c) => c.circle.id == r.circleId)
          .firstOrNull;
      if (view == null) continue;
      final opened = keys.decryptEvent(
        circleId: r.circleId,
        senderId: r.senderId,
        senderDeviceId: r.senderDeviceId,
        keyVersion: r.keyVersion,
        ciphertext: r.ciphertext,
      );
      if (opened is! OpenedOk<CircleEvent>) continue;
      // The same event goes to each shared Circle; show it once.
      final dedupe = '${r.senderId}|${opened.value.kind}|${opened.value.at}';
      if (!seen.add(dedupe)) continue;
      items.add(
        FeedItem(
          id: r.id,
          senderName:
              view.members
                  .where((m) => m.userId == r.senderId)
                  .firstOrNull
                  ?.displayName ??
              '',
          circleName: view.circle.name,
          event: opened.value,
          postedAt: r.createdAt,
        ),
      );
    }
    return items;
  }
}
