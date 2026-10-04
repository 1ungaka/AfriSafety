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

  static String alertDetail(String id) => '$alert/$id';
}
