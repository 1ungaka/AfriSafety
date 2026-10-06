abstract final class AppRoutes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const onboarding = '/onboarding';
  static const home = '/';
  static const createCircle = '/circle/new';
  static const joinCircle = '/circle/join';
  static const sos = '/sos';
  static const privacy = '/privacy';
  static const alert = '/alert';
  static const places = '/places';
  static const addPlace = '/places/new';
  static const pickDestination = '/journey/destination';
  static const contacts = '/contacts';
  static const history = '/history';
  static const devices = '/devices';
  static const appLock = '/app-lock';
  static const safetyNumberBase = '/security-code';

  static String safetyNumber(String userId, String name) => Uri(
    path: '$safetyNumberBase/$userId',
    queryParameters: {'name': name},
  ).toString();

  static String alertDetail(String id) => '$alert/$id';
}
