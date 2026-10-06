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

  /// Journey placeholder.
  ///
  /// In en, this message translates to:
  /// **'Walk me home: share your trip until you arrive. Coming in the next update.'**
  String get journeyComingSoon;

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
