import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/storage/local_vault.dart';
import '../../session/domain/session_controller.dart';
import 'shake_detector.dart';

const _log = SafeLogger('shake');

/// Whether shake-to-SOS is on. Off by default: it's opt-in.
final shakeSosEnabledProvider = AsyncNotifierProvider<ShakeSosSetting, bool>(
  ShakeSosSetting.new,
);

class ShakeSosSetting extends AsyncNotifier<bool> {
  static const _file = 'shake_sos';

  @override
  Future<bool> build() async {
    final raw = await ref.read(localVaultProvider).readJson(_file);
    return raw is Map<String, dynamic> && raw['on'] == true;
  }

  Future<void> set(bool on) async {
    await ref.read(localVaultProvider).writeJson(_file, {'on': on});
    state = AsyncData(on);
  }
}

/// Accelerometer readings (gravity removed). Overridable in tests.
typedef AccelerationStream = Stream<(double, double, double)> Function();

final accelerationStreamProvider = Provider<AccelerationStream>(
  (ref) =>
      () => userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).map((e) => (e.x, e.y, e.z)),
);

/// Emits each time the shake pattern is detected, while the feature is on
/// and the user is signed in. Android only delivers sensor readings while
/// AfriSafety is open or its sharing service is running, so this is not a
/// hidden background listener.
final shakeTriggersProvider = StreamProvider<DateTime>((ref) {
  final on = ref.watch(shakeSosEnabledProvider).value ?? false;
  final ready = ref.watch(identityProvider) != null;
  if (!on || !ready) return const Stream.empty();
  final detector = ShakeDetector();
  final controller = StreamController<DateTime>();
  final sub = ref.read(accelerationStreamProvider)().listen((r) {
    final now = DateTime.now();
    if (detector.add(r.$1, r.$2, r.$3, now)) controller.add(now);
  }, onError: (Object e) => _log.warning('Accelerometer unavailable', e));
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});
