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
  /// **'Safety for you and the people you trust. You can pause sharing or leave a Circle at any time, and nobody can stop you.'**
  String get homeWelcomeBody;

  /// Dark banner explaining end-to-end encryption, wording from the design's 'Who can see me' screen.
  ///
  /// In en, this message translates to:
  /// **'Your location is end-to-end encrypted. Only the people in your Circle can see it. Not even AfriSafety can.'**
  String get homePrivacyBanner;

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

  /// Generic continue button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// Generic cancel button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Generic retry button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// Skip an optional step.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// Copy to clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// Open the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// Finish a flow.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Generic error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Check your connection and try again.'**
  String get errorGeneric;

  /// Shown when the server rate limit is hit.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a while and try again.'**
  String get errorRateLimited;

  /// Shown when the phone can't reach the server.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach AfriSafety. Check your internet connection and try again.'**
  String get errorNetwork;

  /// Shown when the server fails to send the sign-in email.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t send the code email. Please try again in a few minutes.'**
  String get errorEmailNotSent;

  /// Shown for server errors and app configuration problems.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety\'s server isn\'t responding properly. Please try again later.'**
  String get errorServerUnavailable;

  /// Snackbar after copying.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// Loading indicator label.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// Sign-in screen title.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// Sign-in explanation.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a 6-digit code. No password needed.'**
  String get signInIntro;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get signInEmailLabel;

  /// Email validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get signInEmailInvalid;

  /// Button to request an email code.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get signInSendCode;

  /// Code field label.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get signInCodeLabel;

  /// Shown after sending the code.
  ///
  /// In en, this message translates to:
  /// **'We sent a code to {email}. It expires in 10 minutes.'**
  String signInCodeSent(String email);

  /// Button to verify the code.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInVerify;

  /// Invalid or expired code.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it, or ask for a new one.'**
  String get signInWrongCode;

  /// Go back to the email step.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get signInUseDifferentEmail;

  /// Resend the code.
  ///
  /// In en, this message translates to:
  /// **'Send a new code'**
  String get signInResend;

  /// Consent step title.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get onboardingConsentTitle;

  /// Consent card heading.
  ///
  /// In en, this message translates to:
  /// **'Only people you choose'**
  String get onboardingWhoTitle;

  /// Consent card body.
  ///
  /// In en, this message translates to:
  /// **'Your location is shared only with people in Circles you join. Nobody can add you without your OK.'**
  String get onboardingWhoBody;

  /// Consent card heading.
  ///
  /// In en, this message translates to:
  /// **'Never secretly'**
  String get onboardingWhatTitle;

  /// Consent card body.
  ///
  /// In en, this message translates to:
  /// **'While AfriSafety shares your location, a notification is always visible. There is no hidden mode.'**
  String get onboardingWhatBody;

  /// Consent card heading.
  ///
  /// In en, this message translates to:
  /// **'You\'re in control'**
  String get onboardingControlTitle;

  /// Consent card body.
  ///
  /// In en, this message translates to:
  /// **'Pause sharing or leave a Circle at any time with one tap. Nobody can stop you.'**
  String get onboardingControlBody;

  /// Consent card heading.
  ///
  /// In en, this message translates to:
  /// **'End-to-end encrypted'**
  String get onboardingEncryptedTitle;

  /// Consent card body.
  ///
  /// In en, this message translates to:
  /// **'Your location is encrypted on your phone. Our servers can\'t read it.'**
  String get onboardingEncryptedBody;

  /// Age confirmation checkbox (POPIA: minors need guardian consent).
  ///
  /// In en, this message translates to:
  /// **'I am 18 or older'**
  String get onboardingAge;

  /// Location-sharing consent checkbox.
  ///
  /// In en, this message translates to:
  /// **'I agree to share my location with Circles I join, as described above'**
  String get onboardingLocationConsent;

  /// Privacy policy checkbox.
  ///
  /// In en, this message translates to:
  /// **'I have read the privacy summary and accept it'**
  String get onboardingPrivacyConsent;

  /// Link to the privacy summary.
  ///
  /// In en, this message translates to:
  /// **'Read the privacy summary'**
  String get onboardingReadPrivacy;

  /// Display-name step title.
  ///
  /// In en, this message translates to:
  /// **'What should your Circle call you?'**
  String get onboardingNameTitle;

  /// Display-name explanation.
  ///
  /// In en, this message translates to:
  /// **'This is the only detail about you that members see.'**
  String get onboardingNameHint;

  /// Display-name field label.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onboardingNameLabel;

  /// Display-name validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (up to 40 characters).'**
  String get onboardingNameInvalid;

  /// Permission step title.
  ///
  /// In en, this message translates to:
  /// **'Location access'**
  String get onboardingLocationTitle;

  /// Prominent disclosure for location (Play policy).
  ///
  /// In en, this message translates to:
  /// **'AfriSafety uses your location to show it to people in your Circles and to include it in SOS alerts. It is collected only while sharing is on, and a notification is always shown.'**
  String get onboardingLocationBody;

  /// Button to request location permission.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get onboardingLocationAllow;

  /// Background location step title.
  ///
  /// In en, this message translates to:
  /// **'Keep sharing when the screen is off'**
  String get onboardingBackgroundTitle;

  /// Prominent disclosure for background location (Play policy).
  ///
  /// In en, this message translates to:
  /// **'To keep your Circle updated while your phone is in your pocket, choose \"Allow all the time\" on the next screen. You can change this later in Settings.'**
  String get onboardingBackgroundBody;

  /// Button to request background location.
  ///
  /// In en, this message translates to:
  /// **'Choose \"Allow all the time\"'**
  String get onboardingBackgroundAllow;

  /// Notification permission step title.
  ///
  /// In en, this message translates to:
  /// **'Alerts from your Circle'**
  String get onboardingNotificationsTitle;

  /// Notification permission explanation.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications so you hear about SOS alerts, and so the sharing indicator can be shown.'**
  String get onboardingNotificationsBody;

  /// Button to request notification permission.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get onboardingNotificationsAllow;

  /// Privacy summary screen title.
  ///
  /// In en, this message translates to:
  /// **'Privacy summary'**
  String get privacyTitle;

  /// Plain-language privacy summary.
  ///
  /// In en, this message translates to:
  /// **'• We collect your email, the name you choose and, only while sharing is on, your location.\n• Your location, alerts and places are end-to-end encrypted. Only the members you share with can read them, not AfriSafety.\n• We never sell or share your data with advertisers or data brokers.\n• You can pause, leave a Circle, or sign out at any time. Signing out removes this phone\'s keys.\n• Data is stored with our hosting provider (Supabase), which may be outside South Africa. See the full policy for details.\n• Questions or requests under POPIA: contact the AfriSafety Information Officer listed in the full policy.'**
  String get privacyBody;

  /// Bottom nav label.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// Bottom nav label.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get navJourney;

  /// Bottom nav SOS label.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get navSos;

  /// Screen reader label for the SOS button.
  ///
  /// In en, this message translates to:
  /// **'Send an SOS alert'**
  String get navSosSemantic;

  /// Bottom nav label.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get navCircle;

  /// Bottom nav label.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get navSafety;

  /// Status pill while sharing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Sharing your location with nobody yet} =1{Sharing your location with 1 person} other{Sharing your location with {count} people}}'**
  String mapSharingWith(int count);

  /// Status pill while paused.
  ///
  /// In en, this message translates to:
  /// **'Location sharing is paused'**
  String get mapSharingPaused;

  /// Status pill when permission is missing.
  ///
  /// In en, this message translates to:
  /// **'Location access is off'**
  String get mapNeedsPermission;

  /// Pause sharing button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get mapPause;

  /// Resume sharing button.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get mapResume;

  /// Grant permission button.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get mapAllow;

  /// Bottom sheet heading.
  ///
  /// In en, this message translates to:
  /// **'Your circle'**
  String get mapYourCircle;

  /// Toggle to list view.
  ///
  /// In en, this message translates to:
  /// **'Show as list (saves data)'**
  String get mapListView;

  /// Toggle back to map.
  ///
  /// In en, this message translates to:
  /// **'Show map'**
  String get mapMapView;

  /// Label for the user's own marker.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get mapYou;

  /// Empty state heading.
  ///
  /// In en, this message translates to:
  /// **'Create or join a Circle'**
  String get mapNoCircleTitle;

  /// Empty state body.
  ///
  /// In en, this message translates to:
  /// **'A Circle is a small group, like your family, who can see each other and get your SOS alerts.'**
  String get mapNoCircleBody;

  /// Create button.
  ///
  /// In en, this message translates to:
  /// **'Create a Circle'**
  String get circleCreate;

  /// Join button.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get circleJoin;

  /// Member status: live location.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String statusLive(String time);

  /// Member status: paused.
  ///
  /// In en, this message translates to:
  /// **'Paused sharing'**
  String get statusPaused;

  /// Member status: limited you.
  ///
  /// In en, this message translates to:
  /// **'Shares SOS alerts only with you'**
  String get statusSosOnly;

  /// Member status: key not yet received.
  ///
  /// In en, this message translates to:
  /// **'Waiting for keys from their phone'**
  String get statusWaitingKeys;

  /// Member status: nothing uploaded.
  ///
  /// In en, this message translates to:
  /// **'No location shared yet'**
  String get statusNoLocation;

  /// Member status: failed authentication.
  ///
  /// In en, this message translates to:
  /// **'Location couldn\'t be verified'**
  String get statusUnverifiable;

  /// Own status while sharing.
  ///
  /// In en, this message translates to:
  /// **'Sharing now'**
  String get statusMeSharing;

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min ago} other{{minutes} min ago}}'**
  String timeMinutesAgo(int minutes);

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour ago} other{{hours} hours ago}}'**
  String timeHoursAgo(int hours);

  /// Relative time.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day ago} other{{days} days ago}}'**
  String timeDaysAgo(int days);

  /// Map data attribution (required by ODbL).
  ///
  /// In en, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get mapAttribution;

  /// Circle tab title.
  ///
  /// In en, this message translates to:
  /// **'Who can see me'**
  String get circleWhoCanSeeMe;

  /// E2EE banner.
  ///
  /// In en, this message translates to:
  /// **'Your location is end-to-end encrypted. Only the people below can see it. Not even AfriSafety can.'**
  String get circleE2eeBanner;

  /// Share level label.
  ///
  /// In en, this message translates to:
  /// **'Live location'**
  String get circleLevelLive;

  /// Share level label.
  ///
  /// In en, this message translates to:
  /// **'SOS alerts only'**
  String get circleLevelSosOnly;

  /// Owner tag.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get circleOwnerTag;

  /// Screen reader label for share toggle.
  ///
  /// In en, this message translates to:
  /// **'Share live location with {name}'**
  String circleToggleSemantic(String name);

  /// Invite button.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get circleInvite;

  /// Pause all button.
  ///
  /// In en, this message translates to:
  /// **'Pause all sharing'**
  String get circlePauseAll;

  /// Resume button.
  ///
  /// In en, this message translates to:
  /// **'Resume sharing'**
  String get circleResumeAll;

  /// Leave button.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}'**
  String circleLeave(String name);

  /// Leave confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Leave {name}?'**
  String circleLeaveConfirmTitle(String name);

  /// Leave confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Your location and alerts will be removed from this Circle straight away. You can rejoin with a new invite.'**
  String get circleLeaveConfirmBody;

  /// Confirm leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get circleLeaveConfirm;

  /// Circle with only the user.
  ///
  /// In en, this message translates to:
  /// **'Nobody else is here yet. Invite someone you trust.'**
  String get circleNoOthers;

  /// Circle switcher tooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch Circle'**
  String get circleSwitch;

  /// Create screen title.
  ///
  /// In en, this message translates to:
  /// **'Create a Circle'**
  String get createTitle;

  /// Circle name field.
  ///
  /// In en, this message translates to:
  /// **'Circle name'**
  String get createNameLabel;

  /// Circle name hint.
  ///
  /// In en, this message translates to:
  /// **'For example: Family. Members of the Circle will see this name.'**
  String get createNameHint;

  /// Invite sheet title.
  ///
  /// In en, this message translates to:
  /// **'Invite to {name}'**
  String inviteTitle(String name);

  /// Invite explanation.
  ///
  /// In en, this message translates to:
  /// **'Share this code with someone you trust. It works for 48 hours and up to 5 people.'**
  String get inviteBody;

  /// Text shared with the invite.
  ///
  /// In en, this message translates to:
  /// **'Join my AfriSafety Circle \"{name}\". Open AfriSafety, tap \"Join with a code\" and enter: {code} (valid for 48 hours).'**
  String inviteShareText(String name, String code);

  /// Join screen title.
  ///
  /// In en, this message translates to:
  /// **'Join a Circle'**
  String get joinTitle;

  /// Code field label.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get joinCodeLabel;

  /// Code field hint.
  ///
  /// In en, this message translates to:
  /// **'10 characters, like K7Q2M-9XW4P'**
  String get joinCodeHint;

  /// Button to preview an invite.
  ///
  /// In en, this message translates to:
  /// **'Check code'**
  String get joinCheck;

  /// Invalid code error.
  ///
  /// In en, this message translates to:
  /// **'That code isn\'t valid or has expired. Ask for a new one.'**
  String get joinInvalid;

  /// Preview title.
  ///
  /// In en, this message translates to:
  /// **'Join {name}?'**
  String joinPreviewTitle(String name);

  /// Preview body.
  ///
  /// In en, this message translates to:
  /// **'{inviter} invited you. {count, plural, =1{1 person is} other{{count} people are}} in this Circle. They will see your live location and get your SOS alerts. You can pause or leave at any time.'**
  String joinPreviewBody(String inviter, int count);

  /// Accept invite.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get joinAccept;

  /// Decline invite.
  ///
  /// In en, this message translates to:
  /// **'No thanks'**
  String get joinDecline;

  /// Safety tab title.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get safetyTitle;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Emergency numbers'**
  String get safetyEmergencyHeading;

  /// Section heading.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get safetyAccountHeading;

  /// Account row.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String safetySignedInAs(String name);

  /// Sign-out button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get safetySignOut;

  /// Sign-out confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get safetySignOutConfirmTitle;

  /// Sign-out confirmation body.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s encryption keys will be erased and it will stop receiving locations and alerts. You can sign in again later.'**
  String get safetySignOutConfirmBody;

  /// Link to privacy summary.
  ///
  /// In en, this message translates to:
  /// **'Privacy summary'**
  String get safetyPrivacy;

  /// Countdown heading.
  ///
  /// In en, this message translates to:
  /// **'Sending SOS'**
  String get sosCountdownTitle;

  /// Countdown explanation.
  ///
  /// In en, this message translates to:
  /// **'Your Circle will get your location. Tap Cancel if this was a mistake.'**
  String get sosCountdownBody;

  /// Screen reader countdown.
  ///
  /// In en, this message translates to:
  /// **'Sending SOS in {seconds} seconds'**
  String sosCountdownSemantic(int seconds);

  /// Skip countdown.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sosSendNow;

  /// Active heading when stored.
  ///
  /// In en, this message translates to:
  /// **'Alert sent'**
  String get sosAlertSent;

  /// Active heading while sending.
  ///
  /// In en, this message translates to:
  /// **'Sending alert…'**
  String get sosSending;

  /// Active explanation.
  ///
  /// In en, this message translates to:
  /// **'Your live location is being shared with your Circles until you mark yourself safe.'**
  String get sosActiveBody;

  /// No-circle explanation.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in a Circle yet, so nobody in AfriSafety can be alerted. Send an SMS or call for help.'**
  String get sosNoCircleBody;

  /// Delivery card heading.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get sosDelivery;

  /// Delivery status.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sosStatusSending;

  /// Delivery status.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sosStatusSent;

  /// Delivery status.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get sosStatusDelivered;

  /// Delivery status.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get sosStatusSeen;

  /// Location line.
  ///
  /// In en, this message translates to:
  /// **'{lat}, {lon} (±{accuracy} m)'**
  String sosLocation(String lat, String lon, String accuracy);

  /// No fix.
  ///
  /// In en, this message translates to:
  /// **'Location not available yet'**
  String get sosNoLocation;

  /// SMS fallback button.
  ///
  /// In en, this message translates to:
  /// **'Send SMS with my location'**
  String get sosSms;

  /// SMS fallback explanation.
  ///
  /// In en, this message translates to:
  /// **'No data? This opens your SMS app with your location filled in.'**
  String get sosSmsHint;

  /// SMS text.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety SOS: I need help. My location: {lat}, {lon} (±{accuracy} m) {link}'**
  String sosSmsBody(String lat, String lon, String accuracy, String link);

  /// SMS text without location.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety SOS: I need help. My location isn\'t available. Please call me.'**
  String get sosSmsBodyNoLocation;

  /// Dial SAPS.
  ///
  /// In en, this message translates to:
  /// **'Call SAPS 10111'**
  String get sosCallSaps;

  /// Dial 112.
  ///
  /// In en, this message translates to:
  /// **'Call 112'**
  String get sosCall112;

  /// Resolve alert.
  ///
  /// In en, this message translates to:
  /// **'I am safe, end alert'**
  String get sosImSafe;

  /// Disclaimer.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety does not replace emergency services.'**
  String get sosDisclaimer;

  /// Incoming alert heading.
  ///
  /// In en, this message translates to:
  /// **'{name} needs help'**
  String alertNeedsHelp(String name);

  /// Fallback heading.
  ///
  /// In en, this message translates to:
  /// **'Someone in your Circle needs help'**
  String get alertSomeoneNeedsHelp;

  /// Alert subtitle.
  ///
  /// In en, this message translates to:
  /// **'{circle} · {time}'**
  String alertSentAt(String circle, String time);

  /// Undecryptable alert.
  ///
  /// In en, this message translates to:
  /// **'Details are still arriving. Keep this screen open or call them.'**
  String get alertNoDetails;

  /// Open external maps app.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get alertOpenMaps;

  /// Acknowledge and close.
  ///
  /// In en, this message translates to:
  /// **'I\'ve seen this'**
  String get alertSeen;

  /// Shown when resolved.
  ///
  /// In en, this message translates to:
  /// **'{name} marked themselves safe'**
  String alertResolved(String name);

  /// Foreground service notification title.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety is sharing your location'**
  String get notificationSharingTitle;

  /// Foreground service notification body.
  ///
  /// In en, this message translates to:
  /// **'Open the app to pause, or to see who can see you.'**
  String get notificationSharingBody;

  /// Places screen title.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get placesTitle;

  /// Places intro.
  ///
  /// In en, this message translates to:
  /// **'Your Circle gets a message when you arrive at or leave these places.'**
  String get placesIntro;

  /// Places privacy note.
  ///
  /// In en, this message translates to:
  /// **'Places are stored only on this phone, encrypted. Messages are only sent while you share your location, and only to people who can see it.'**
  String get placesSharingNote;

  /// Empty places list.
  ///
  /// In en, this message translates to:
  /// **'No places yet. Add home, work or campus.'**
  String get placesEmpty;

  /// Add place button and screen title.
  ///
  /// In en, this message translates to:
  /// **'Add a place'**
  String get placesAdd;

  /// Delete place button label.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String placesDelete(String name);

  /// Places limit reached.
  ///
  /// In en, this message translates to:
  /// **'You can save up to 20 places.'**
  String get placesLimit;

  /// Place name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get placeNameLabel;

  /// Place name hint.
  ///
  /// In en, this message translates to:
  /// **'For example Home or Campus'**
  String get placeNameHint;

  /// Place radius label.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get placeRadiusLabel;

  /// Place radius in metres.
  ///
  /// In en, this message translates to:
  /// **'{meters} m'**
  String placeRadiusValue(int meters);

  /// Map picker hint.
  ///
  /// In en, this message translates to:
  /// **'Move the map so the pin is on the spot.'**
  String get placeMoveMapHint;

  /// Save place button.
  ///
  /// In en, this message translates to:
  /// **'Save place'**
  String get placeSave;

  /// Activity feed heading.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get activityTitle;

  /// Empty activity feed.
  ///
  /// In en, this message translates to:
  /// **'Nothing in the last day.'**
  String get activityEmpty;

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} arrived at {place}'**
  String eventPlaceArrived(String name, String place);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} left {place}'**
  String eventPlaceLeft(String name, String place);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} is on the way to {place}, expected by {time}'**
  String eventJourneyStarted(String name, String place, String time);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} arrived safely at {place}'**
  String eventJourneyArrived(String name, String place);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} ended their journey'**
  String eventJourneyEnded(String name);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} started a check-in timer until {time}'**
  String eventCheckInStarted(String name, String time);

  /// Event text.
  ///
  /// In en, this message translates to:
  /// **'{name} checked in safely'**
  String eventCheckInOk(String name);

  /// Safety tab section.
  ///
  /// In en, this message translates to:
  /// **'Safety tools'**
  String get safetyToolsHeading;

  /// Places entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Let your Circle know when you arrive or leave'**
  String get safetyPlacesSubtitle;

  /// Journey tab title.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get journeyTitle;

  /// Journey mode.
  ///
  /// In en, this message translates to:
  /// **'Walk me home'**
  String get journeyModeWalk;

  /// Timer mode.
  ///
  /// In en, this message translates to:
  /// **'Check-in timer'**
  String get journeyModeTimer;

  /// Walk intro.
  ///
  /// In en, this message translates to:
  /// **'Choose where you\'re going. People who can see your location will see you\'re on the way. If you don\'t arrive in time, all your Circles get an alert, even if your phone is off.'**
  String get journeyWalkIntro;

  /// Destination heading.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get journeyPickPlace;

  /// Pick destination on map.
  ///
  /// In en, this message translates to:
  /// **'Choose on the map'**
  String get journeyChooseOnMap;

  /// Hint when no places.
  ///
  /// In en, this message translates to:
  /// **'Tip: save places like Home under Safety → Places to pick them here.'**
  String get journeyNoPlacesHint;

  /// Walking estimate.
  ///
  /// In en, this message translates to:
  /// **'About {minutes} min on foot'**
  String journeyEta(int minutes);

  /// Increase ETA.
  ///
  /// In en, this message translates to:
  /// **'Add 5 minutes'**
  String get journeyEtaLonger;

  /// Decrease ETA.
  ///
  /// In en, this message translates to:
  /// **'Remove 5 minutes'**
  String get journeyEtaShorter;

  /// When the alert fires.
  ///
  /// In en, this message translates to:
  /// **'Your Circles are alerted if you haven\'t arrived by {time}.'**
  String journeyAlertAfter(String time);

  /// Start journey button.
  ///
  /// In en, this message translates to:
  /// **'Start journey'**
  String get journeyStart;

  /// Timer intro.
  ///
  /// In en, this message translates to:
  /// **'If you don\'t tap “I\'m OK” before the timer ends, all your Circles get an alert with your last known location, even if your phone is off.'**
  String get checkInIntro;

  /// Duration in minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String checkInMinutes(int minutes);

  /// Duration in hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String checkInHours(int hours);

  /// Start timer button.
  ///
  /// In en, this message translates to:
  /// **'Start timer'**
  String get checkInStart;

  /// Active journey title.
  ///
  /// In en, this message translates to:
  /// **'On the way to {place}'**
  String activeJourneyTitle(String place);

  /// Active timer title.
  ///
  /// In en, this message translates to:
  /// **'Check-in timer running'**
  String get activeTimerTitle;

  /// Deadline.
  ///
  /// In en, this message translates to:
  /// **'Check in by {time}'**
  String activeCheckInBy(String time);

  /// Journey ETA.
  ///
  /// In en, this message translates to:
  /// **'Expected by {time}'**
  String activeExpectedBy(String time);

  /// Countdown.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String activeMinutesLeft(int minutes);

  /// Deadline passed.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up. Your Circles are being alerted.'**
  String get activeOverdue;

  /// Check in button.
  ///
  /// In en, this message translates to:
  /// **'I\'m OK'**
  String get activeImOk;

  /// Arrived button.
  ///
  /// In en, this message translates to:
  /// **'I\'ve arrived'**
  String get activeArrived;

  /// Extend button.
  ///
  /// In en, this message translates to:
  /// **'+15 min'**
  String get activeExtend;

  /// Extend button label for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Add 15 minutes'**
  String get activeExtendSemantic;

  /// Cancel journey.
  ///
  /// In en, this message translates to:
  /// **'End journey'**
  String get activeEndJourney;

  /// Auto-arrival note.
  ///
  /// In en, this message translates to:
  /// **'This ends by itself when you get there.'**
  String get activeAutoArrive;

  /// Missed check-in title.
  ///
  /// In en, this message translates to:
  /// **'Your Circles have been alerted'**
  String get missedTitle;

  /// Missed check-in body.
  ///
  /// In en, this message translates to:
  /// **'You didn\'t check in in time. If you\'re safe, let them know.'**
  String get missedBody;

  /// Resolve missed check-in.
  ///
  /// In en, this message translates to:
  /// **'I\'m safe, tell my Circles'**
  String get missedImOk;

  /// Start failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start. Check your connection and try again.'**
  String get journeyErrorStart;

  /// Finish failed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach AfriSafety. Try again: until it gets through, your Circles will still be alerted at the deadline.'**
  String get journeyErrorFinish;

  /// No circles.
  ///
  /// In en, this message translates to:
  /// **'Create or join a Circle first: they\'re the people who get alerted.'**
  String get journeyErrorNoCircles;

  /// Pick destination screen title.
  ///
  /// In en, this message translates to:
  /// **'Choose destination'**
  String get pickDestinationTitle;

  /// Destination name field.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get pickDestinationName;

  /// Confirm destination.
  ///
  /// In en, this message translates to:
  /// **'Use this spot'**
  String get pickDestinationUse;

  /// Default destination name.
  ///
  /// In en, this message translates to:
  /// **'your destination'**
  String get destinationDefaultName;

  /// Foreground notification title during a check-in.
  ///
  /// In en, this message translates to:
  /// **'AfriSafety check-in running'**
  String get notificationJourneyTitle;

  /// Foreground notification body during a check-in.
  ///
  /// In en, this message translates to:
  /// **'Check in by {time}. Open the app when you\'re safe.'**
  String notificationJourneyBody(String time);

  /// Incoming alert title.
  ///
  /// In en, this message translates to:
  /// **'{name} missed a check-in'**
  String alertMissedCheckIn(String name);

  /// Incoming missed check-in explanation.
  ///
  /// In en, this message translates to:
  /// **'They set a timer and didn\'t check in before it ran out. Try calling them. Their last known location is below.'**
  String get alertMissedCheckInBody;

  /// Contacts screen title.
  ///
  /// In en, this message translates to:
  /// **'SMS emergency contacts'**
  String get contactsTitle;

  /// Contacts entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'People without the app who get your SOS text'**
  String get safetyContactsSubtitle;

  /// Contacts intro.
  ///
  /// In en, this message translates to:
  /// **'When you press SOS and can\'t reach your Circle, AfriSafety opens your SMS app with these people already filled in. You press send.'**
  String get contactsIntro;

  /// Contacts privacy note.
  ///
  /// In en, this message translates to:
  /// **'Their numbers are stored only on this phone, encrypted. AfriSafety never texts anyone by itself.'**
  String get contactsPrivacy;

  /// Empty contacts list.
  ///
  /// In en, this message translates to:
  /// **'No SMS contacts yet.'**
  String get contactsEmpty;

  /// Add contact button and sheet title.
  ///
  /// In en, this message translates to:
  /// **'Add a contact'**
  String get contactsAdd;

  /// Delete contact button label.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}'**
  String contactsDelete(String name);

  /// Contacts limit.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 5 SMS contacts.'**
  String get contactsLimit;

  /// Contact name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get contactsName;

  /// Contact phone field.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get contactsPhone;

  /// Invalid phone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number, e.g. 082 123 4567'**
  String get contactsPhoneInvalid;

  /// Contact consent checkbox (POPIA).
  ///
  /// In en, this message translates to:
  /// **'This person agreed to get emergency texts from me.'**
  String get contactsConsent;

  /// Save contact button.
  ///
  /// In en, this message translates to:
  /// **'Save contact'**
  String get contactsSave;

  /// History screen title.
  ///
  /// In en, this message translates to:
  /// **'Location history'**
  String get historyTitle;

  /// History entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Your own timeline, kept only on this phone'**
  String get safetyHistorySubtitle;

  /// History switch.
  ///
  /// In en, this message translates to:
  /// **'Keep a history on this phone'**
  String get historyToggle;

  /// History switch subtitle.
  ///
  /// In en, this message translates to:
  /// **'Remembers where you\'ve been while you share your location. Turning this off deletes it.'**
  String get historyToggleSubtitle;

  /// History privacy note.
  ///
  /// In en, this message translates to:
  /// **'Only you can see your history. It\'s encrypted on this phone and never uploaded, so nobody in your Circles (and not AfriSafety) can see where you\'ve been.'**
  String get historyPrivacy;

  /// Retention heading.
  ///
  /// In en, this message translates to:
  /// **'Keep for'**
  String get historyKeepFor;

  /// Retention choice.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day} other{{days} days}}'**
  String historyDays(int days);

  /// Empty history.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet. Points are added while you share your location.'**
  String get historyEmpty;

  /// History day summary.
  ///
  /// In en, this message translates to:
  /// **'{count} points between {from} and {to}'**
  String historySummary(int count, String from, String to);

  /// Delete history button.
  ///
  /// In en, this message translates to:
  /// **'Delete history'**
  String get historyDelete;

  /// History map label.
  ///
  /// In en, this message translates to:
  /// **'Map of your route with {count} points'**
  String historyMapSemantic(int count);

  /// Battery tip title.
  ///
  /// In en, this message translates to:
  /// **'Keep AfriSafety working in the background'**
  String get batteryTipTitle;

  /// Battery tip body.
  ///
  /// In en, this message translates to:
  /// **'Some phones (Samsung, Xiaomi, Tecno and others) stop apps to save battery, which can stop sharing and journeys. In settings, choose Battery → Unrestricted for AfriSafety.'**
  String get batteryTipBody;

  /// Opens the app settings page.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get batteryTipAction;

  /// Devices screen title.
  ///
  /// In en, this message translates to:
  /// **'Devices and security'**
  String get devicesTitle;

  /// Devices entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Phones signed in to your account, and recent security activity'**
  String get safetyDevicesSubtitle;

  /// Devices intro.
  ///
  /// In en, this message translates to:
  /// **'These phones are signed in to your account. If you don\'t recognise one, sign it out: it loses access straight away, and your Circles\' keys change so it can\'t read anything new.'**
  String get devicesIntro;

  /// Current device.
  ///
  /// In en, this message translates to:
  /// **'This phone'**
  String get devicesThisPhone;

  /// Other device.
  ///
  /// In en, this message translates to:
  /// **'Another {platform} phone'**
  String devicesOtherPhone(String platform);

  /// Device last seen.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String devicesLastSeen(String time);

  /// Sign out others button.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other phones'**
  String get devicesSignOutOthers;

  /// Confirm title.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other phones?'**
  String get devicesSignOutOthersTitle;

  /// Confirm body.
  ///
  /// In en, this message translates to:
  /// **'They\'ll lose access to your account and Circles. To use AfriSafety on them again, you\'ll need to sign in there, and your Circle members will be told about the new device.'**
  String get devicesSignOutOthersBody;

  /// Confirmation.
  ///
  /// In en, this message translates to:
  /// **'Other phones signed out.'**
  String get devicesSignedOutOthers;

  /// Security log heading.
  ///
  /// In en, this message translates to:
  /// **'Security activity'**
  String get securityActivityTitle;

  /// Empty security log.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet.'**
  String get securityActivityEmpty;

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'A new phone signed in to your account'**
  String get securityNewDevice;

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'A phone was signed out of your account'**
  String get securityDeviceRevoked;

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'Someone joined {circle}'**
  String securityMemberJoined(String circle);

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'Someone left {circle}'**
  String securityMemberLeft(String circle);

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'You joined {circle}'**
  String securityJoinedCircle(String circle);

  /// Security event.
  ///
  /// In en, this message translates to:
  /// **'You left {circle}'**
  String securityLeftCircle(String circle);

  /// Shown on sign-in after a remote sign-out.
  ///
  /// In en, this message translates to:
  /// **'This phone was signed out from another device, and its data was erased. Sign in again to keep using AfriSafety here.'**
  String get signInRemoteSignOut;

  /// Safety number screen title.
  ///
  /// In en, this message translates to:
  /// **'Security code'**
  String get safetyNumberTitle;

  /// Safety number intro.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s phone and yours should show exactly the same 60 digits. If they do, nobody (not even AfriSafety\'s server) can read what you share with each other.'**
  String safetyNumberIntro(String name);

  /// Safety number how-to.
  ///
  /// In en, this message translates to:
  /// **'Compare in person, or read the numbers to each other on a phone call. Don\'t compare over a message in this app.'**
  String get safetyNumberHowTo;

  /// Safety number grid label.
  ///
  /// In en, this message translates to:
  /// **'Security code, 12 groups of 5 digits'**
  String get safetyNumberSemantic;

  /// Verify button.
  ///
  /// In en, this message translates to:
  /// **'They match: mark as verified'**
  String get safetyNumberMarkVerified;

  /// Verified state.
  ///
  /// In en, this message translates to:
  /// **'You\'ve verified {name}.'**
  String safetyNumberVerified(String name);

  /// Changed warning.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s security code changed. This normally means they signed in on a new phone. If they didn\'t, someone may be trying to listen in: compare the numbers again.'**
  String safetyNumberChanged(String name);

  /// Acknowledge change.
  ///
  /// In en, this message translates to:
  /// **'They got a new phone: dismiss'**
  String get safetyNumberAcknowledge;

  /// Member trust: verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get trustVerified;

  /// Member trust: unverified.
  ///
  /// In en, this message translates to:
  /// **'Check security code'**
  String get trustUnverified;

  /// Member trust: changed.
  ///
  /// In en, this message translates to:
  /// **'Security code changed'**
  String get trustChanged;

  /// Circle tab banner when a code changed.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s security code changed. Tap to check it.'**
  String trustChangedBanner(String name);

  /// Lock screen title.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockTitle;

  /// Wrong PIN.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrong;

  /// Lockout countdown.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Try again in {seconds} s'**
  String lockWait(int seconds);

  /// Forgot PIN link.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get lockForgot;

  /// Forgot title.
  ///
  /// In en, this message translates to:
  /// **'Forgot your PIN?'**
  String get lockForgotTitle;

  /// Forgot explanation.
  ///
  /// In en, this message translates to:
  /// **'Sign out to reset it. This erases AfriSafety\'s data on this phone (keys, places, contacts, history). You can sign in again straight away.'**
  String get lockForgotBody;

  /// SOS button on lock screen.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get lockSos;

  /// Lock screen alert notice.
  ///
  /// In en, this message translates to:
  /// **'Someone in your Circle needs help. Unlock to see.'**
  String get lockAlertWaiting;

  /// PIN dots label.
  ///
  /// In en, this message translates to:
  /// **'{count} of 6 digits entered'**
  String lockDigitsEntered(int count);

  /// Backspace label.
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get lockBackspace;

  /// Settings title.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get lockSettingsTitle;

  /// Safety tab entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask for a PIN when AfriSafety opens'**
  String get safetyLockSubtitle;

  /// Settings intro.
  ///
  /// In en, this message translates to:
  /// **'Keep people who pick up your phone out of AfriSafety. SOS and the emergency numbers still work while it is locked.'**
  String get lockSettingsIntro;

  /// Lock switch.
  ///
  /// In en, this message translates to:
  /// **'Lock with a 6-digit PIN'**
  String get lockSettingsToggle;

  /// Lock unavailable.
  ///
  /// In en, this message translates to:
  /// **'App lock is not available on this phone.'**
  String get lockUnavailable;

  /// Timeout heading.
  ///
  /// In en, this message translates to:
  /// **'Lock after'**
  String get lockTimeoutTitle;

  /// Timeout choice.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get lockTimeoutImmediately;

  /// Timeout choice.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min in the background'**
  String lockTimeoutMinutes(int minutes);

  /// Change PIN button.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get lockChangePin;

  /// Current PIN title.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get lockEnterCurrent;

  /// New PIN title.
  ///
  /// In en, this message translates to:
  /// **'Choose a 6-digit PIN'**
  String get lockChoosePin;

  /// Confirm PIN title.
  ///
  /// In en, this message translates to:
  /// **'Enter it again'**
  String get lockConfirmPin;

  /// Mismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs didn\'t match. Try again.'**
  String get lockPinsDontMatch;

  /// Settings note.
  ///
  /// In en, this message translates to:
  /// **'The lock doesn\'t hide that you\'re sharing your location: Android\'s notification stays visible. After 5 wrong PINs, AfriSafety makes you wait longer each time.'**
  String get lockSettingsNote;

  /// Foreground notification body with viewer count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nobody can see it yet.} =1{1 person can see it.} other{{count} people can see it.}} Open the app to pause.'**
  String notificationSharingBodyCount(int count);

  /// Weekly sharing review.
  ///
  /// In en, this message translates to:
  /// **'{people, plural, =1{1 person} other{{people} people}} in {circles, plural, =1{1 Circle} other{{circles} Circles}} can see your location. Still OK?'**
  String reviewBody(int people, int circles);

  /// Review confirm.
  ///
  /// In en, this message translates to:
  /// **'Looks right'**
  String get reviewOk;

  /// Review pause.
  ///
  /// In en, this message translates to:
  /// **'Pause sharing'**
  String get reviewPause;

  /// Mute member action.
  ///
  /// In en, this message translates to:
  /// **'Mute updates for 24 h'**
  String get muteMember;

  /// Unmute member action.
  ///
  /// In en, this message translates to:
  /// **'Unmute updates'**
  String get unmuteMember;

  /// Muted note.
  ///
  /// In en, this message translates to:
  /// **'Updates muted. SOS alerts still come through.'**
  String get mutedUntil;

  /// Safety guide title.
  ///
  /// In en, this message translates to:
  /// **'Think someone is tracking you?'**
  String get guideTitle;

  /// Safety tab entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Steps to check, and people who can help'**
  String get safetyGuideSubtitle;

  /// Guide intro.
  ///
  /// In en, this message translates to:
  /// **'Apps like this can be misused to watch someone. You are in control of AfriSafety on your phone: nobody can turn sharing on for you, and pausing or leaving always works.'**
  String get guideIntro;

  /// Guide step.
  ///
  /// In en, this message translates to:
  /// **'Check your Circles'**
  String get guideCirclesTitle;

  /// Guide step body.
  ///
  /// In en, this message translates to:
  /// **'Open the Circle tab. Make sure you know everyone listed, and switch anyone you\'re unsure about to SOS alerts only, or leave the Circle. Members are told when you leave.'**
  String get guideCirclesBody;

  /// Guide step.
  ///
  /// In en, this message translates to:
  /// **'Check which phones are signed in'**
  String get guideDevicesTitle;

  /// Guide step body.
  ///
  /// In en, this message translates to:
  /// **'If a phone you don\'t recognise is signed in to your account, sign it out.'**
  String get guideDevicesBody;

  /// Guide step.
  ///
  /// In en, this message translates to:
  /// **'Check other apps'**
  String get guideAppsTitle;

  /// Guide step body.
  ///
  /// In en, this message translates to:
  /// **'In Android Settings → Location → App location permissions, look for apps you didn\'t install or don\'t recognise. Someone with access to your phone may have installed one.'**
  String get guideAppsBody;

  /// Guide step.
  ///
  /// In en, this message translates to:
  /// **'Pause when you need to'**
  String get guidePauseTitle;

  /// Guide step body.
  ///
  /// In en, this message translates to:
  /// **'Pausing is one tap on the Map tab. People in your Circles will see that you paused. If that could put you at risk, think about timing, and keep SOS available.'**
  String get guidePauseBody;

  /// Guide step.
  ///
  /// In en, this message translates to:
  /// **'Lock the app'**
  String get guideLockTitle;

  /// Guide step body.
  ///
  /// In en, this message translates to:
  /// **'A PIN keeps people who pick up your phone out of AfriSafety. SOS still works.'**
  String get guideLockBody;

  /// Guide helplines heading.
  ///
  /// In en, this message translates to:
  /// **'Talk to someone'**
  String get guideHelpTitle;

  /// Helpline name.
  ///
  /// In en, this message translates to:
  /// **'GBV Command Centre'**
  String get guideGbvTitle;

  /// Helpline details.
  ///
  /// In en, this message translates to:
  /// **'0800 428 428, free, 24 hours. Or dial *120*7867# from any phone.'**
  String get guideGbvBody;

  /// Helpline name.
  ///
  /// In en, this message translates to:
  /// **'Lifeline South Africa'**
  String get guideLifelineTitle;

  /// Helpline details.
  ///
  /// In en, this message translates to:
  /// **'0861 322 322, 24 hours: counselling and support.'**
  String get guideLifelineBody;

  /// Shown when a member's phone reports a mock location provider.
  ///
  /// In en, this message translates to:
  /// **'Location may be simulated'**
  String get statusMaybeSimulated;

  /// Shake setting title.
  ///
  /// In en, this message translates to:
  /// **'Shake to start SOS'**
  String get shakeSosTitle;

  /// Shake setting subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shake your phone hard 4 times while AfriSafety is open or sharing. The 3-second countdown still lets you cancel.'**
  String get shakeSosSubtitle;

  /// Community screen title.
  ///
  /// In en, this message translates to:
  /// **'Community reports'**
  String get communityTitle;

  /// Safety tab entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous reports of incidents near you'**
  String get safetyCommunitySubtitle;

  /// Report button.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get communityReport;

  /// Consent heading.
  ///
  /// In en, this message translates to:
  /// **'Before you use community reports'**
  String get communityConsentTitle;

  /// Consent point.
  ///
  /// In en, this message translates to:
  /// **'Reports are anonymous. Nobody, including other users and moderators, can see who reported.'**
  String get communityConsentPoint1;

  /// Consent point.
  ///
  /// In en, this message translates to:
  /// **'Your phone rounds the place to a square of about 1 km before sending it. AfriSafety never receives your exact location for a report.'**
  String get communityConsentPoint2;

  /// Consent point.
  ///
  /// In en, this message translates to:
  /// **'A square only appears once at least 3 different people have reported there in the last 30 days.'**
  String get communityConsentPoint3;

  /// Consent point.
  ///
  /// In en, this message translates to:
  /// **'Only report things you saw or experienced. False reports can be flagged, hidden and lead to a ban. This is not a way to call for help: for emergencies use SOS or call 10111.'**
  String get communityConsentPoint4;

  /// Consent button.
  ///
  /// In en, this message translates to:
  /// **'I understand, turn on community reports'**
  String get communityConsentAgree;

  /// Community intro.
  ///
  /// In en, this message translates to:
  /// **'Squares where at least 3 people reported something in the last 30 days. Your square has a green border.'**
  String get communityIntro;

  /// Filter: all categories.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get communityAll;

  /// Near you heading.
  ///
  /// In en, this message translates to:
  /// **'Near you'**
  String get communityNearYou;

  /// Nothing near.
  ///
  /// In en, this message translates to:
  /// **'Nothing reported in or next to your square in the last 30 days.'**
  String get communityNothingNear;

  /// Near item.
  ///
  /// In en, this message translates to:
  /// **'{count} people reported this in your area'**
  String communityInYourArea(int count);

  /// Near item.
  ///
  /// In en, this message translates to:
  /// **'{count} people reported this next to your area'**
  String communityNextToYou(int count);

  /// Flag button.
  ///
  /// In en, this message translates to:
  /// **'Looks wrong'**
  String get communityFlag;

  /// Flag confirmation.
  ///
  /// In en, this message translates to:
  /// **'Thanks. If enough people agree, it will be hidden until a moderator checks it.'**
  String get communityFlagged;

  /// No location.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location. Turn on location and try again.'**
  String get communityNoLocation;

  /// Map label.
  ///
  /// In en, this message translates to:
  /// **'Map with {count} reported squares'**
  String communityMapSemantic(int count);

  /// Report sheet title.
  ///
  /// In en, this message translates to:
  /// **'Report something'**
  String get communityReportTitle;

  /// Report privacy note.
  ///
  /// In en, this message translates to:
  /// **'Anonymous, and only for your approximate area (about 1 km). It won\'t show on the map until 2 other people report the same.'**
  String get communityReportPrivacy;

  /// Category question.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get communityWhat;

  /// When question.
  ///
  /// In en, this message translates to:
  /// **'When?'**
  String get communityWhen;

  /// When choice.
  ///
  /// In en, this message translates to:
  /// **'In the last few hours'**
  String get communityWhenNow;

  /// When choice.
  ///
  /// In en, this message translates to:
  /// **'Earlier today'**
  String get communityWhenToday;

  /// When choice.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get communityWhenYesterday;

  /// Where note.
  ///
  /// In en, this message translates to:
  /// **'Where: the square you are in now.'**
  String get communityWhere;

  /// Submit button.
  ///
  /// In en, this message translates to:
  /// **'Send anonymous report'**
  String get communitySubmit;

  /// Report confirmation.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your report was sent anonymously.'**
  String get communityThanks;

  /// Banned message.
  ///
  /// In en, this message translates to:
  /// **'You can\'t send community reports any more.'**
  String get communityBanned;

  /// Withdraw consent.
  ///
  /// In en, this message translates to:
  /// **'Stop using community reports'**
  String get communityStop;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Suspicious activity'**
  String get categorySuspicious;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Theft'**
  String get categoryTheft;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Robbery'**
  String get categoryRobbery;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Assault'**
  String get categoryAssault;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get categoryHarassment;

  /// Category.
  ///
  /// In en, this message translates to:
  /// **'Vandalism'**
  String get categoryVandalism;

  /// Moderation title.
  ///
  /// In en, this message translates to:
  /// **'Moderation'**
  String get moderationTitle;

  /// Empty queue.
  ///
  /// In en, this message translates to:
  /// **'Nothing flagged.'**
  String get moderationEmpty;

  /// Queue counts.
  ///
  /// In en, this message translates to:
  /// **'{reporters} reporters · {flags} flags'**
  String moderationCounts(int reporters, int flags);

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get moderationHidden;

  /// Status.
  ///
  /// In en, this message translates to:
  /// **'Kept'**
  String get moderationKept;

  /// Hide action.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get moderationHide;

  /// Keep action.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get moderationKeep;

  /// Moderation entry subtitle.
  ///
  /// In en, this message translates to:
  /// **'Review flagged community reports'**
  String get safetyModerationSubtitle;

  /// Delete account entry and dialog title.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccountTitle;

  /// Delete account explanation.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and everything AfriSafety stores about you: your profile, devices, Circle memberships, locations, alerts, check-ins and reports. You\'ll leave every Circle (the next member becomes owner) and its members will be told. This phone is wiped too. It can\'t be undone.'**
  String get deleteAccountBody;

  /// Word the user types to confirm deletion.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountConfirmWord;

  /// Confirm field label.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String deleteAccountTypeToConfirm(String word);

  /// Delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteAccountAction;

  /// Fingerprint unlock button.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get lockUseFingerprint;

  /// Shown in the system biometric prompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock AfriSafety'**
  String get lockBiometricReason;

  /// Fingerprint setting.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint'**
  String get lockBiometricToggle;

  /// Sign-in intro for phone.
  ///
  /// In en, this message translates to:
  /// **'We\'ll text you a 6-digit code. No password needed.'**
  String get signInIntroPhone;

  /// Phone field label.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get signInPhoneLabel;

  /// Invalid phone.
  ///
  /// In en, this message translates to:
  /// **'Enter a South African mobile number, e.g. 082 123 4567.'**
  String get signInPhoneInvalid;

  /// Change phone.
  ///
  /// In en, this message translates to:
  /// **'Use a different number'**
  String get signInUseDifferentPhone;
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
