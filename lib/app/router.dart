import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/board/presentation/board_screen.dart';
import '../features/board/presentation/sticky_detail_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Named route paths used across the app.
class StikoRoutes {
  const StikoRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String settings = '/settings';
  static const String sticky = '/sticky/:id';

  /// Builds the concrete detail path for a given sticky id.
  static String stickyPath(String id) => '/sticky/$id';
}

/// Router that gates the app behind authentication: signed-out users are sent
/// to the login screen, signed-in users away from the auth screens.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final GoRouterRefreshStream refresh =
      GoRouterRefreshStream(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: StikoRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final bool loggedIn = auth.currentUser != null;
      final String loc = state.matchedLocation;
      final bool onAuthPage =
          loc == StikoRoutes.login || loc == StikoRoutes.signup;
      if (!loggedIn && !onAuthPage) return StikoRoutes.login;
      if (loggedIn && onAuthPage) return StikoRoutes.home;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: StikoRoutes.home,
        builder: (context, state) => const BoardScreen(),
      ),
      GoRoute(
        path: StikoRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: StikoRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: StikoRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: StikoRoutes.sticky,
        builder: (context, state) =>
            StickyDetailScreen(stickyId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Bridges a [Stream] to [Listenable] so GoRouter re-evaluates redirects
/// whenever the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
