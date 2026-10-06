import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint (or face) unlock, as a convenience on top of the PIN.
abstract interface class BiometricAuth {
  /// The phone has biometrics enrolled.
  Future<bool> available();

  /// Shows Android's biometric prompt. False if cancelled or failed.
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometrics implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      // Biometrics only: falling back to the phone's own screen lock would
      // let anyone who knows the phone's PIN past AfriSafety's lock.
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => LocalAuthBiometrics(),
);
