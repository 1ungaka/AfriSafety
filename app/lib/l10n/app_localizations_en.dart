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
  String get configErrorTitle => 'AfriSafety isn\'t set up correctly';

  @override
  String get configErrorBody =>
      'This build is missing configuration. Rebuild with --dart-define-from-file=.env (see app/.env.example).';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionShare => 'Share';

  @override
  String get actionDone => 'Done';

  @override
  String get errorGeneric =>
      'Something went wrong. Check your connection and try again.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please wait a while and try again.';

  @override
  String get errorNetwork =>
      'Can\'t reach AfriSafety. Check your internet connection and try again.';

  @override
  String get errorEmailNotSent =>
      'We couldn\'t send the code email. Please try again in a few minutes.';

  @override
  String get errorServerUnavailable =>
      'AfriSafety\'s server isn\'t responding properly. Please try again later.';

  @override
  String get copied => 'Copied';

  @override
  String get loading => 'Loading…';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInIntro =>
      'We\'ll email you a 6-digit code. No password needed.';

  @override
  String get signInEmailLabel => 'Email address';

  @override
  String get signInEmailInvalid => 'Enter a valid email address.';

  @override
  String get signInSendCode => 'Send code';

  @override
  String get signInCodeLabel => '6-digit code';

  @override
  String signInCodeSent(String email) {
    return 'We sent a code to $email. It expires in 10 minutes.';
  }

  @override
  String get signInVerify => 'Sign in';

  @override
  String get signInWrongCode =>
      'That code didn\'t work. Check it, or ask for a new one.';

  @override
  String get signInUseDifferentEmail => 'Use a different email';

  @override
  String get signInResend => 'Send a new code';

  @override
  String get onboardingConsentTitle => 'Before you start';

  @override
  String get onboardingWhoTitle => 'Only people you choose';

  @override
  String get onboardingWhoBody =>
      'Your location is shared only with people in Circles you join. Nobody can add you without your OK.';

  @override
  String get onboardingWhatTitle => 'Never secretly';

  @override
  String get onboardingWhatBody =>
      'While AfriSafety shares your location, a notification is always visible. There is no hidden mode.';

  @override
  String get onboardingControlTitle => 'You\'re in control';

  @override
  String get onboardingControlBody =>
      'Pause sharing or leave a Circle at any time with one tap. Nobody can stop you.';

  @override
  String get onboardingEncryptedTitle => 'End-to-end encrypted';

  @override
  String get onboardingEncryptedBody =>
      'Your location is encrypted on your phone. Our servers can\'t read it.';

  @override
  String get onboardingAge => 'I am 18 or older';

  @override
  String get onboardingLocationConsent =>
      'I agree to share my location with Circles I join, as described above';

  @override
  String get onboardingPrivacyConsent =>
      'I have read the privacy summary and accept it';

  @override
  String get onboardingReadPrivacy => 'Read the privacy summary';

  @override
  String get onboardingNameTitle => 'What should your Circle call you?';

  @override
  String get onboardingNameHint =>
      'This is the only detail about you that members see.';

  @override
  String get onboardingNameLabel => 'Your name';

  @override
  String get onboardingNameInvalid => 'Enter a name (up to 40 characters).';

  @override
  String get onboardingLocationTitle => 'Location access';

  @override
  String get onboardingLocationBody =>
      'AfriSafety uses your location to show it to people in your Circles and to include it in SOS alerts. It is collected only while sharing is on, and a notification is always shown.';

  @override
  String get onboardingLocationAllow => 'Allow location';

  @override
  String get onboardingBackgroundTitle => 'Keep sharing when the screen is off';

  @override
  String get onboardingBackgroundBody =>
      'To keep your Circle updated while your phone is in your pocket, choose \"Allow all the time\" on the next screen. You can change this later in Settings.';

  @override
  String get onboardingBackgroundAllow => 'Choose \"Allow all the time\"';

  @override
  String get onboardingNotificationsTitle => 'Alerts from your Circle';

  @override
  String get onboardingNotificationsBody =>
      'Allow notifications so you hear about SOS alerts, and so the sharing indicator can be shown.';

  @override
  String get onboardingNotificationsAllow => 'Allow notifications';

  @override
  String get privacyTitle => 'Privacy summary';

  @override
  String get privacyBody =>
      '• We collect your email, the name you choose and, only while sharing is on, your location.\n• Your location, alerts and places are end-to-end encrypted. Only the members you share with can read them, not AfriSafety.\n• We never sell or share your data with advertisers or data brokers.\n• You can pause, leave a Circle, or sign out at any time. Signing out removes this phone\'s keys.\n• Data is stored with our hosting provider (Supabase), which may be outside South Africa. See the full policy for details.\n• Questions or requests under POPIA: contact the AfriSafety Information Officer listed in the full policy.';

  @override
  String get navMap => 'Map';

  @override
  String get navJourney => 'Journey';

  @override
  String get navSos => 'SOS';

  @override
  String get navSosSemantic => 'Send an SOS alert';

  @override
  String get navCircle => 'Circle';

  @override
  String get navSafety => 'Safety';

  @override
  String mapSharingWith(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sharing your location with $count people',
      one: 'Sharing your location with 1 person',
      zero: 'Sharing your location with nobody yet',
    );
    return '$_temp0';
  }

  @override
  String get mapSharingPaused => 'Location sharing is paused';

  @override
  String get mapNeedsPermission => 'Location access is off';

  @override
  String get mapPause => 'Pause';

  @override
  String get mapResume => 'Resume';

  @override
  String get mapAllow => 'Allow';

  @override
  String get mapYourCircle => 'Your circle';

  @override
  String get mapListView => 'Show as list (saves data)';

  @override
  String get mapMapView => 'Show map';

  @override
  String get mapYou => 'You';

  @override
  String get mapNoCircleTitle => 'Create or join a Circle';

  @override
  String get mapNoCircleBody =>
      'A Circle is a small group, like your family, who can see each other and get your SOS alerts.';

  @override
  String get circleCreate => 'Create a Circle';

  @override
  String get circleJoin => 'Join with a code';

  @override
  String statusLive(String time) {
    return 'Updated $time';
  }

  @override
  String get statusPaused => 'Paused sharing';

  @override
  String get statusSosOnly => 'Shares SOS alerts only with you';

  @override
  String get statusWaitingKeys => 'Waiting for keys from their phone';

  @override
  String get statusNoLocation => 'No location shared yet';

  @override
  String get statusUnverifiable => 'Location couldn\'t be verified';

  @override
  String get statusMeSharing => 'Sharing now';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get mapAttribution => '© OpenStreetMap contributors';

  @override
  String get circleWhoCanSeeMe => 'Who can see me';

  @override
  String get circleE2eeBanner =>
      'Your location is end-to-end encrypted. Only the people below can see it. Not even AfriSafety can.';

  @override
  String get circleLevelLive => 'Live location';

  @override
  String get circleLevelSosOnly => 'SOS alerts only';

  @override
  String get circleOwnerTag => 'Owner';

  @override
  String circleToggleSemantic(String name) {
    return 'Share live location with $name';
  }

  @override
  String get circleInvite => 'Invite someone';

  @override
  String get circlePauseAll => 'Pause all sharing';

  @override
  String get circleResumeAll => 'Resume sharing';

  @override
  String circleLeave(String name) {
    return 'Leave $name';
  }

  @override
  String circleLeaveConfirmTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get circleLeaveConfirmBody =>
      'Your location and alerts will be removed from this Circle straight away. You can rejoin with a new invite.';

  @override
  String get circleLeaveConfirm => 'Leave';

  @override
  String get circleNoOthers =>
      'Nobody else is here yet. Invite someone you trust.';

  @override
  String get circleSwitch => 'Switch Circle';

  @override
  String get createTitle => 'Create a Circle';

  @override
  String get createNameLabel => 'Circle name';

  @override
  String get createNameHint =>
      'For example: Family. Members of the Circle will see this name.';

  @override
  String inviteTitle(String name) {
    return 'Invite to $name';
  }

  @override
  String get inviteBody =>
      'Share this code with someone you trust. It works for 48 hours and up to 5 people.';

  @override
  String inviteShareText(String name, String code) {
    return 'Join my AfriSafety Circle \"$name\". Open AfriSafety, tap \"Join with a code\" and enter: $code (valid for 48 hours).';
  }

  @override
  String get joinTitle => 'Join a Circle';

  @override
  String get joinCodeLabel => 'Invite code';

  @override
  String get joinCodeHint => '10 characters, like K7Q2M-9XW4P';

  @override
  String get joinCheck => 'Check code';

  @override
  String get joinInvalid =>
      'That code isn\'t valid or has expired. Ask for a new one.';

  @override
  String joinPreviewTitle(String name) {
    return 'Join $name?';
  }

  @override
  String joinPreviewBody(String inviter, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are',
      one: '1 person is',
    );
    return '$inviter invited you. $_temp0 in this Circle. They will see your live location and get your SOS alerts. You can pause or leave at any time.';
  }

  @override
  String get joinAccept => 'Join';

  @override
  String get joinDecline => 'No thanks';

  @override
  String get safetyTitle => 'Safety';

  @override
  String get safetyEmergencyHeading => 'Emergency numbers';

  @override
  String get safetyAccountHeading => 'Account';

  @override
  String safetySignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get safetySignOut => 'Sign out';

  @override
  String get safetySignOutConfirmTitle => 'Sign out?';

  @override
  String get safetySignOutConfirmBody =>
      'This phone\'s encryption keys will be erased and it will stop receiving locations and alerts. You can sign in again later.';

  @override
  String get safetyPrivacy => 'Privacy summary';

  @override
  String get journeyComingSoon =>
      'Walk me home: share your trip until you arrive. Coming in the next update.';

  @override
  String get sosCountdownTitle => 'Sending SOS';

  @override
  String get sosCountdownBody =>
      'Your Circle will get your location. Tap Cancel if this was a mistake.';

  @override
  String sosCountdownSemantic(int seconds) {
    return 'Sending SOS in $seconds seconds';
  }

  @override
  String get sosSendNow => 'Send now';

  @override
  String get sosAlertSent => 'Alert sent';

  @override
  String get sosSending => 'Sending alert…';

  @override
  String get sosActiveBody =>
      'Your live location is being shared with your Circles until you mark yourself safe.';

  @override
  String get sosNoCircleBody =>
      'You\'re not in a Circle yet, so nobody in AfriSafety can be alerted. Send an SMS or call for help.';

  @override
  String get sosDelivery => 'Delivery';

  @override
  String get sosStatusSending => 'Sending';

  @override
  String get sosStatusSent => 'Sent';

  @override
  String get sosStatusDelivered => 'Delivered';

  @override
  String get sosStatusSeen => 'Seen';

  @override
  String sosLocation(String lat, String lon, String accuracy) {
    return '$lat, $lon (±$accuracy m)';
  }

  @override
  String get sosNoLocation => 'Location not available yet';

  @override
  String get sosSms => 'Send SMS with my location';

  @override
  String get sosSmsHint =>
      'No data? This opens your SMS app with your location filled in.';

  @override
  String sosSmsBody(String lat, String lon, String accuracy, String link) {
    return 'AfriSafety SOS: I need help. My location: $lat, $lon (±$accuracy m) $link';
  }

  @override
  String get sosSmsBodyNoLocation =>
      'AfriSafety SOS: I need help. My location isn\'t available. Please call me.';

  @override
  String get sosCallSaps => 'Call SAPS 10111';

  @override
  String get sosCall112 => 'Call 112';

  @override
  String get sosImSafe => 'I am safe, end alert';

  @override
  String get sosDisclaimer => 'AfriSafety does not replace emergency services.';

  @override
  String alertNeedsHelp(String name) {
    return '$name needs help';
  }

  @override
  String get alertSomeoneNeedsHelp => 'Someone in your Circle needs help';

  @override
  String alertSentAt(String circle, String time) {
    return '$circle · $time';
  }

  @override
  String get alertNoDetails =>
      'Details are still arriving. Keep this screen open or call them.';

  @override
  String get alertOpenMaps => 'Open in maps';

  @override
  String get alertSeen => 'I\'ve seen this';

  @override
  String alertResolved(String name) {
    return '$name marked themselves safe';
  }

  @override
  String get notificationSharingTitle => 'AfriSafety is sharing your location';

  @override
  String get notificationSharingBody =>
      'Open the app to pause, or to see who can see you.';
}
