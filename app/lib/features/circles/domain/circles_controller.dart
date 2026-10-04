import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/key_envelope.dart';
import '../../../core/logging/safe_logger.dart';
import '../../session/domain/session_controller.dart';
import '../data/circles_repository.dart';
import 'models.dart';

const _log = SafeLogger('circles');

class CircleView {
  const CircleView({
    required this.circle,
    required this.members,
    required this.mySosOnlyViewers,
    required this.sharersLimitingMe,
    required this.myUserId,
  });

  final Circle circle;
  final List<CircleMember> members;

  /// Members I've limited to SOS alerts only.
  final Set<String> mySosOnlyViewers;

  /// Members who've limited me to SOS alerts only.
  final Set<String> sharersLimitingMe;
  final String myUserId;

  CircleMember? get me =>
      members.where((m) => m.userId == myUserId).firstOrNull;

  List<CircleMember> get others =>
      members.where((m) => m.userId != myUserId).toList();

  bool get iAmSharing => !(me?.sharingPaused ?? true);

  /// People who can see my live location here.
  int get liveViewerCount =>
      others.where((m) => !mySosOnlyViewers.contains(m.userId)).length;
}

class CirclesState {
  const CirclesState({
    required this.circles,
    required this.selectedId,
    this.locationKeyRotations = 0,
  });

  final List<CircleView> circles;
  final String? selectedId;

  /// Increments whenever this device's location key rotates, so the
  /// sharing controller can re-upload under the new key immediately.
  final int locationKeyRotations;

  CircleView? get selected =>
      circles.where((c) => c.circle.id == selectedId).firstOrNull ??
      circles.firstOrNull;

  /// Circles where my location is currently shared.
  List<CircleView> get sharingIn => circles.where((c) => c.iAmSharing).toList();

  /// Distinct people across Circles who can see my live location.
  int get liveViewerCount => {
    for (final c in sharingIn)
      for (final m in c.others)
        if (!c.mySosOnlyViewers.contains(m.userId)) m.userId,
  }.length;

  CirclesState copyWith({
    List<CircleView>? circles,
    String? selectedId,
    int? locationKeyRotations,
  }) => CirclesState(
    circles: circles ?? this.circles,
    selectedId: selectedId ?? this.selectedId,
    locationKeyRotations: locationKeyRotations ?? this.locationKeyRotations,
  );
}

final circlesControllerProvider =
    AsyncNotifierProvider<CirclesController, CirclesState>(
      CirclesController.new,
    );

/// Loads the user's Circles, keeps them fresh over Realtime and runs the
/// D7 key sync after every change (new member, leaver, share-level change).
class CirclesController extends AsyncNotifier<CirclesState> {
  CirclesRepository get _repo => ref.read(circlesRepositoryProvider);

  Timer? _debounce;

  @override
  Future<CirclesState> build() async {
    final identity = ref.watch(identityProvider);
    if (identity == null) {
      return const CirclesState(circles: [], selectedId: null);
    }
    final sub = _repo.changes().listen((_) => _scheduleReload());
    ref.onDispose(() {
      sub.cancel();
      _debounce?.cancel();
    });
    return _load(identity.userId, selectedId: null, rotations: 0);
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), reload);
  }

  Future<CirclesState> _load(
    String myUserId, {
    required String? selectedId,
    required int rotations,
  }) async {
    final circles = await _repo.myCircles();
    final views = await Future.wait([
      for (final c in circles)
        () async {
          final results = await Future.wait([
            _repo.members(c.id),
            _repo.mySosOnlyViewers(c.id),
            _repo.sharersLimitingMe(c.id),
          ]);
          return CircleView(
            circle: c,
            members: results[0] as List<CircleMember>,
            mySosOnlyViewers: results[1] as Set<String>,
            sharersLimitingMe: results[2] as Set<String>,
            myUserId: myUserId,
          );
        }(),
    ]);

    final rotated = await _syncKeys([for (final c in circles) c.id]);
    return CirclesState(
      circles: views,
      selectedId: views.any((v) => v.circle.id == selectedId)
          ? selectedId
          : views.firstOrNull?.circle.id,
      locationKeyRotations: rotations + (rotated ? 1 : 0),
    );
  }

  /// Returns true if any location key rotated.
  Future<bool> _syncKeys(List<String> circleIds) async {
    final keys = ref.read(keySyncServiceProvider);
    if (keys == null) return false;
    var rotated = false;
    try {
      await keys.loadReceivedKeys();
      for (final id in circleIds) {
        final channels = await keys.syncCircle(id);
        rotated |= channels.contains(KeyChannel.location);
      }
      // Pick up keys others sealed to us during the same round.
      await keys.loadReceivedKeys();
    } on Object catch (e) {
      // Key sync retries on the next change or reload; the UI shows members
      // as "waiting for keys" meanwhile.
      _log.warning('Key sync failed', e);
    }
    return rotated;
  }

  Future<void> reload() async {
    final identity = ref.read(identityProvider);
    if (identity == null) return;
    final current = state.value;
    state = AsyncData(
      await _load(
        identity.userId,
        selectedId: current?.selectedId,
        rotations: current?.locationKeyRotations ?? 0,
      ),
    );
  }

  void select(String circleId) {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(selectedId: circleId));
    }
  }

  Future<String> create(String name) async {
    final id = await _repo.createCircle(name);
    await reload();
    select(id);
    return id;
  }

  Future<String> createInvite(String circleId) => _repo.createInvite(circleId);

  Future<InvitePreview?> preview(String code) => _repo.previewInvite(code);

  Future<String?> accept(String code) async {
    final id = await _repo.acceptInvite(code);
    if (id != null) {
      await reload();
      select(id);
    }
    return id;
  }

  /// Never blocked: the server only checks membership.
  Future<void> leave(String circleId) async {
    await _repo.leave(circleId);
    ref.read(keySyncServiceProvider)?.forgetCircle(circleId);
    await reload();
  }

  Future<void> setPaused({String? circleId, required bool paused}) async {
    await _repo.setPaused(circleId: circleId, paused: paused);
    await reload();
  }

  Future<void> setShareLevel(
    String circleId,
    String viewerId,
    ShareLevel level,
  ) async {
    await _repo.setShareLevel(circleId, viewerId, level);
    // Reload runs key sync, which rotates the location key on a downgrade
    // so the viewer is cut off from the next update onwards.
    await reload();
  }
}
