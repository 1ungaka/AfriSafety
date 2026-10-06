import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/circles/presentation/create_circle_screen.dart';
import '../../features/circles/presentation/join_circle_screen.dart';
import '../../features/contacts/presentation/contacts_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/journey/presentation/pick_destination_screen.dart';
import '../../features/onboarding/data/profile_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/panic/presentation/incoming_alert_screen.dart';
import '../../features/panic/presentation/sos_screen.dart';
import '../../features/places/presentation/add_place_screen.dart';
import '../../features/places/presentation/places_screen.dart';
import '../../features/session/domain/session_controller.dart';
import '../../features/session/presentation/loading_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import 'app_routes.dart';

export 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // GoRouter re-runs redirect whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);

  const publicRoutes = {AppRoutes.privacy};

  final router = GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (publicRoutes.contains(location)) return null;
      final session = ref.read(sessionProvider);
      final target = switch (session) {
        AsyncData(value: SignedOut()) => AppRoutes.signIn,
        AsyncData(value: NeedsOnboarding()) => AppRoutes.onboarding,
        AsyncData(value: Ready()) => null,
        // Loading, or an error (offline at start-up): the loading screen
        // offers a retry and the emergency numbers.
        _ => AppRoutes.loading,
      };
      if (target != null) return location == target ? null : target;
      // Ready: leave the auth/onboarding screens.
      const gates = {AppRoutes.loading, AppRoutes.signIn, AppRoutes.onboarding};
      return gates.contains(location) ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) {
          final session = ref.read(sessionProvider).value;
          return OnboardingScreen(
            status: session is NeedsOnboarding
                ? session.status
                : const OnboardingStatusEmpty(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacySummaryScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: AppRoutes.createCircle,
        builder: (context, state) => const CreateCircleScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinCircle,
        builder: (context, state) => const JoinCircleScreen(),
      ),
      GoRoute(
        path: AppRoutes.sos,
        builder: (context, state) => const SosScreen(),
      ),
      GoRoute(
        path: AppRoutes.contacts,
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.pickDestination,
        builder: (context, state) => const PickDestinationScreen(),
      ),
      GoRoute(
        path: AppRoutes.places,
        builder: (context, state) => const PlacesScreen(),
      ),
      GoRoute(
        path: AppRoutes.addPlace,
        builder: (context, state) => const AddPlaceScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.alert}/:id',
        builder: (context, state) =>
            IncomingAlertScreen(alertId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
