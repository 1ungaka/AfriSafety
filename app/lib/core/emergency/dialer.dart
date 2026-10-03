import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialler with a number filled in.
///
/// The user still presses call. We never place calls directly, which would
/// need the CALL_PHONE permission and risks accidental emergency calls.
abstract interface class Dialer {
  Future<bool> dial(String number);
}

class UrlLauncherDialer implements Dialer {
  const UrlLauncherDialer();

  @override
  Future<bool> dial(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } on Exception {
      return false;
    }
  }
}

final dialerProvider = Provider<Dialer>((ref) => const UrlLauncherDialer());
