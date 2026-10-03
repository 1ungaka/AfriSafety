import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// App name. Do not translate.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety'**
  String get appTitle;

  /// Shown on every emergency-related screen.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety does not replace emergency services. In danger, call 10111 (SAPS) or 112.'**
  String get emergencyNotice;

  /// Button label to phone the South African Police Service.
  ///
  /// In en, this message translates to:
  /// **'SAPS 10111'**
  String get callSaps;

  /// Screen reader label for the SAPS call button.
  ///
  /// In en, this message translates to:
  /// **'Call the South African Police Service on 10111'**
  String get callSapsSemantic;

  /// Button label to phone the 112 emergency number.
  ///
  /// In en, this message translates to:
  /// **'Emergency 112'**
  String get callEmergency;

  /// Screen reader label for the 112 call button.
  ///
  /// In en, this message translates to:
  /// **'Call the emergency number 112'**
  String get callEmergencySemantic;

  /// Shown when the dialler can't be opened.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the phone dialler. Please dial {number} yourself.'**
  String callFailed(String number);

  /// Home screen heading.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AfriSafety'**
  String get homeWelcomeTitle;

  /// Home screen introduction.
  ///
  /// In en, this message translates to:
  /// **'Safety for you and the people you trust. Your location is end-to-end encrypted, and you can pause sharing or leave a Circle at any time.'**
  String get homeWelcomeBody;

  /// Temporary note while features are being built.
  ///
  /// In en, this message translates to:
  /// **'Circles, the live map and the panic button are coming in the next update.'**
  String get homeComingSoon;

  /// Developer-facing screen when build configuration is missing.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety isn\'t set up correctly'**
  String get configErrorTitle;

  /// Explains how to fix a misconfigured build.
  ///
  /// In en, this message translates to:
  /// **'This build is missing configuration. Rebuild with --dart-define-from-file=.env (see app/.env.example).'**
  String get configErrorBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
