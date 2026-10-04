import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/safe_logger.dart';
import '../panic/domain/incoming_alerts_controller.dart';
import '../session/domain/session_controller.dart';

const _log = SafeLogger('push');

/// Whether Firebase was initialised at start-up (set in bootstrap).
final pushAvailableProvider = Provider<bool>((ref) => false);

/// Initialises Firebase from dart-defines, if configured. Returns whether
/// push is available. Never throws: the app must start without push.
Future<bool> initPush(FirebaseConfig? config) async {
  if (config == null) return false;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
      ),
    );
    return true;
  } on Object catch (e) {
    _log.error('Firebase init failed; continuing without push', e);
    return false;
  }
}

/// Emits when the user taps an alert notification (app opened from it).
final alertTapsProvider = StreamProvider<void>((ref) async* {
  if (!ref.watch(pushAvailableProvider)) return;
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) yield null;
  yield* FirebaseMessaging.onMessageOpenedApp.map((_) {});
});

/// Registers this device's push token and keeps it current.
///
/// The push itself carries no personal data, only an opaque alert id and
/// a generic "open AfriSafety" message. Details are fetched and decrypted
/// in the app, so Google never learns who needs help or where.
final pushRegistrationProvider = Provider<void>((ref) {
  if (!ref.watch(pushAvailableProvider)) return;
  final identity = ref.watch(identityProvider);
  if (identity == null) return;
  final devices = ref.read(deviceRepositoryProvider);
  final messaging = FirebaseMessaging.instance;

  Future<void> save(String? token) async {
    if (token == null) return;
    try {
      await devices.savePushToken(identity.deviceId, token);
    } on Object catch (e) {
      _log.warning('Saving push token failed', e);
    }
  }

  unawaited(messaging.getToken().then(save));
  final refresh = messaging.onTokenRefresh.listen(save);
  // Foreground pushes: refresh immediately (Realtime usually beats it).
  final foreground = FirebaseMessaging.onMessage.listen(
    (_) => unawaited(ref.read(incomingAlertsProvider.notifier).refresh()),
  );
  ref.onDispose(() {
    refresh.cancel();
    foreground.cancel();
  });
});
