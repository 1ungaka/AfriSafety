import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/location_codec.dart';
import '../../../core/logging/safe_logger.dart';
import '../../circles/domain/circles_controller.dart';
import '../../session/domain/session_controller.dart';
import '../data/location_source.dart';
import 'location_policy.dart';

const _log = SafeLogger('sharing');

final locationSourceProvider = Provider<LocationSource>(
  (ref) => GeolocatorLocationSource(),
);

class SharingState {
  const SharingState({
    this.permission = LocationPermissionLevel.denied,
    this.running = false,
    this.mode = TrackingMode.moving,
    this.lastFix,
    this.lastUploadAt,
    this.pendingUploads = 0,
  });

  final LocationPermissionLevel permission;

  /// The foreground service (and its notification) is active.
  final bool running;
  final TrackingMode mode;
  final LocationFix? lastFix;
  final DateTime? lastUploadAt;

  /// Circles whose latest location is waiting for a connection.
  final int pendingUploads;

  SharingState copyWith({
    LocationPermissionLevel? permission,
    bool? running,
    TrackingMode? mode,
    LocationFix? lastFix,
    DateTime? lastUploadAt,
    int? pendingUploads,
  }) => SharingState(
    permission: permission ?? this.permission,
    running: running ?? this.running,
    mode: mode ?? this.mode,
    lastFix: lastFix ?? this.lastFix,
    lastUploadAt: lastUploadAt ?? this.lastUploadAt,
    pendingUploads: pendingUploads ?? this.pendingUploads,
  );
}

final sharingControllerProvider =
    NotifierProvider<SharingController, SharingState>(SharingController.new);

/// Shares this device's location with every Circle where the user hasn't
/// paused. The location stream only runs while at least one Circle is
/// shared, so the foreground notification is an honest indicator.
///
/// Offline handling: the newest fix per Circle is kept and retried; older
/// unsent fixes are simply superseded (a stale location has no value and
/// costs data).
class SharingController extends Notifier<SharingState> {
  StreamSubscription<LocationFix>? _sub;
  SharingNotificationText? _text;
  final List<LocationFix> _recent = [];
  final Map<String, LocationFix> _pending = {};
  LocationFix? _lastUploaded;
  Timer? _retry;
  bool _emergency = false;

  LocationSource get _source => ref.read(locationSourceProvider);

  @override
  SharingState build() {
    ref.listen(circlesControllerProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (after == null) return;
      unawaited(_reconcileRunning());
      // A rotated location key means some viewers must stop seeing us:
      // re-upload now under the new key instead of at the next fix.
      if (before != null &&
          after.locationKeyRotations != before.locationKeyRotations) {
        unawaited(uploadNow());
      }
    });
    ref.onDispose(() {
      _sub?.cancel();
      _retry?.cancel();
    });
    unawaited(_refreshPermission());
    return const SharingState();
  }

  /// Supplies the notification text (needs a BuildContext for l10n) and
  /// starts sharing if the user shares in any Circle.
  Future<void> configure(SharingNotificationText text) async {
    _text = text;
    await _refreshPermission();
    await _reconcileRunning();
  }

  Future<void> _refreshPermission() async {
    final permission = await _source.permission();
    state = state.copyWith(permission: permission);
  }

  /// Emergency mode (during a panic): fastest, most accurate tracking.
  Future<void> setEmergency(bool on) async {
    if (_emergency == on) return;
    _emergency = on;
    await _restart(on ? TrackingMode.emergency : TrackingMode.moving);
  }

  Future<void> _reconcileRunning() async {
    final circles = ref.read(circlesControllerProvider).value;
    final shouldRun =
        (circles?.sharingIn.isNotEmpty ?? false) &&
        state.permission.canTrack &&
        _text != null;
    if (shouldRun && _sub == null) {
      await _restart(state.mode);
    } else if (!shouldRun && _sub != null && !_emergency) {
      await _stop();
    }
  }

  Future<void> _restart(TrackingMode mode) async {
    await _sub?.cancel();
    _sub = null;
    final text = _text;
    if (text == null || !state.permission.canTrack) return;
    _sub = _source
        .watch(LocationPolicy.specFor(mode), text)
        .listen(
          _onFix,
          onError: (Object e) => _log.warning('Location error', e),
        );
    state = state.copyWith(running: true, mode: mode);
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _pending.clear();
    state = state.copyWith(running: false, pendingUploads: 0);
  }

  Future<void> _onFix(LocationFix raw) async {
    final now = DateTime.now().toUtc();
    final battery = await _source.batteryPercent();
    final fix = LocationFix(
      latitude: raw.latitude,
      longitude: raw.longitude,
      accuracyMeters: raw.accuracyMeters,
      recordedAt: raw.recordedAt,
      speedMetersPerSecond: raw.speedMetersPerSecond,
      batteryPercent: battery,
      isMoving: state.mode == TrackingMode.moving,
      isMocked: raw.isMocked,
    );
    _recent
      ..add(fix)
      ..removeWhere(
        (f) => now.difference(f.recordedAt) > LocationPolicy.stillWindow * 2,
      );
    state = state.copyWith(lastFix: fix);

    final mode = LocationPolicy.modeFor(
      recent: _recent,
      batteryPercent: battery,
      emergency: _emergency,
      now: now,
    );
    if (mode != state.mode) {
      _log.info('Tracking mode: ${mode.name}');
      await _restart(mode);
    }

    if (LocationPolicy.shouldUpload(
      fix: fix,
      lastUploaded: _lastUploaded,
      lastUploadAt: state.lastUploadAt,
      spec: LocationPolicy.specFor(state.mode),
      now: now,
    )) {
      await _uploadEverywhere(fix);
    }
  }

  /// Uploads the latest fix to every shared Circle right away.
  Future<void> uploadNow() async {
    final fix = state.lastFix;
    if (fix != null) await _uploadEverywhere(fix);
  }

  Future<void> _uploadEverywhere(LocationFix fix) async {
    final circles = ref.read(circlesControllerProvider).value?.sharingIn ?? [];
    for (final c in circles) {
      _pending[c.circle.id] = fix;
    }
    await _flush();
  }

  Future<void> _flush() async {
    final keys = ref.read(keySyncServiceProvider);
    final identity = ref.read(identityProvider);
    if (keys == null || identity == null) return;
    final repo = ref.read(locationRepositoryProvider);
    final sharing = {
      for (final c
          in ref.read(circlesControllerProvider).value?.sharingIn ??
              const <CircleView>[])
        c.circle.id,
    };

    for (final entry in _pending.entries.toList()) {
      final circleId = entry.key;
      if (!sharing.contains(circleId)) {
        _pending.remove(circleId); // paused or left meanwhile
        continue;
      }
      var sealed = keys.encryptLocation(circleId, entry.value);
      if (sealed == null) {
        await keys.syncCircle(circleId);
        sealed = keys.encryptLocation(circleId, entry.value);
      }
      if (sealed == null) continue;
      try {
        await repo.upload(
          circleId: circleId,
          deviceId: identity.deviceId,
          keyVersion: sealed.keyVersion,
          ciphertext: sealed.ciphertext,
        );
        _pending.remove(circleId);
        _lastUploaded = entry.value;
        state = state.copyWith(lastUploadAt: DateTime.now().toUtc());
      } on Object catch (e) {
        _log.warning('Upload failed; will retry', e);
      }
    }
    state = state.copyWith(pendingUploads: _pending.length);
    _retry?.cancel();
    if (_pending.isNotEmpty) {
      _retry = Timer(const Duration(seconds: 20), () => unawaited(_flush()));
    }
  }
}
