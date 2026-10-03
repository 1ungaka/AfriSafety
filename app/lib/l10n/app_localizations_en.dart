// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AfriSafety';

  @override
  String get emergencyNotice =>
      'AfriSafety does not replace emergency services. In danger, call 10111 (SAPS) or 112.';

  @override
  String get callSaps => 'SAPS 10111';

  @override
  String get callSapsSemantic =>
      'Call the South African Police Service on 10111';

  @override
  String get callEmergency => 'Emergency 112';

  @override
  String get callEmergencySemantic => 'Call the emergency number 112';

  @override
  String callFailed(String number) {
    return 'Couldn\'t open the phone dialler. Please dial $number yourself.';
  }

  @override
  String get homeWelcomeTitle => 'Welcome to AfriSafety';

  @override
  String get homeWelcomeBody =>
      'Safety for you and the people you trust. You can pause sharing or leave a Circle at any time, and nobody can stop you.';

  @override
  String get homePrivacyBanner =>
      'Your location is end-to-end encrypted. Only the people in your Circle can see it. Not even AfriSafety can.';

  @override
  String get homeComingSoon =>
      'Circles, the live map and the panic button are coming in the next update.';

  @override
  String get configErrorTitle => 'AfriSafety isn\'t set up correctly';

  @override
  String get configErrorBody =>
      'This build is missing configuration. Rebuild with --dart-define-from-file=.env (see app/.env.example).';
}
