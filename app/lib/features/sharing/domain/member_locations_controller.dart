import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/location_codec.dart';
import '../../circles/domain/circles_controller.dart';
import '../../circles/domain/models.dart';
import '../../keys/domain/key_sync_service.dart';
import '../../session/domain/session_controller.dart';
import 'sharing_controller.dart';

enum MemberLocationStatus {
  /// Decrypted and shown.
  live,

  /// The member paused sharing (shown honestly as "Paused").
  paused,

  /// The member limited you to SOS alerts only.
  sosOnly,

  /// A location exists but your key hasn't arrived yet.
  waitingForKeys,

  /// Nothing shared yet (or the member's phone hasn't uploaded).
  noLocation,

  /// The ciphertext failed verification: never shown.
  unverifiable,
}

class MemberLocation {
  const MemberLocation({
    required this.member,
    required this.status,
    required this.isMe,
    this.fix,
    this.updatedAt,
  });

  final CircleMember member;
  final MemberLocationStatus status;
  final bool isMe;
  final LocationFix? fix;
  final DateTime? updatedAt;
}

final memberLocationsProvider =
    AsyncNotifierProvider<MemberLocationsController, List<MemberLocation>>(
      MemberLocationsController.new,
    );

/// Decrypts the selected Circle's locations on this device and keeps them
/// live over Realtime. The server only ever sends ciphertext.
class MemberLocationsController extends AsyncNotifier<List<MemberLocation>> {
  Timer? _debounce;

  @override
  Future<List<MemberLocation>> build() async {
    final view = ref.watch(circlesControllerProvider).value?.selected;
    // Re-render my own marker from the local fix as it changes.
    ref.watch(sharingControllerProvider.select((s) => s.lastFix));
    if (view == null) return const [];

    final sub = ref
        .read(locationRepositoryProvider)
        .changes(view.circle.id)
        .listen((_) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 300), () async {
            state = AsyncData(await _load(view));
          });
        });
    ref.onDispose(() {
      sub.cancel();
      _debounce?.cancel();
    });
    return _load(view);
  }

  Future<List<MemberLocation>> _load(CircleView view) async {
    final keys = ref.read(keySyncServiceProvider);
    final myFix = ref.read(sharingControllerProvider).lastFix;
    final rows = await ref
        .read(locationRepositoryProvider)
        .fetch(view.circle.id);
    final byUser = {for (final r in rows) r.userId: r};

    return [
      for (final m in view.members)
        if (m.userId == view.myUserId)
          MemberLocation(
            member: m,
            isMe: true,
            status: m.sharingPaused
                ? MemberLocationStatus.paused
                : (myFix == null
                      ? MemberLocationStatus.noLocation
                      : MemberLocationStatus.live),
            fix: m.sharingPaused ? null : myFix,
            updatedAt: myFix?.recordedAt,
          )
        else if (m.sharingPaused)
          MemberLocation(
            member: m,
            isMe: false,
            status: MemberLocationStatus.paused,
          )
        else if (byUser[m.userId] case final row?)
          switch (keys?.decryptLocation(
            circleId: row.circleId,
            senderId: row.userId,
            senderDeviceId: row.senderDeviceId,
            keyVersion: row.keyVersion,
            ciphertext: row.ciphertext,
          )) {
            OpenedOk(:final value) => MemberLocation(
              member: m,
              isMe: false,
              status: MemberLocationStatus.live,
              fix: value,
              updatedAt: row.updatedAt,
            ),
            OpenedTampered() => MemberLocation(
              member: m,
              isMe: false,
              status: MemberLocationStatus.unverifiable,
              updatedAt: row.updatedAt,
            ),
            _ => MemberLocation(
              member: m,
              isMe: false,
              status: view.sharersLimitingMe.contains(m.userId)
                  ? MemberLocationStatus.sosOnly
                  : MemberLocationStatus.waitingForKeys,
              updatedAt: row.updatedAt,
            ),
          }
        else
          MemberLocation(
            member: m,
            isMe: false,
            status: view.sharersLimitingMe.contains(m.userId)
                ? MemberLocationStatus.sosOnly
                : MemberLocationStatus.noLocation,
          ),
    ];
  }
}
