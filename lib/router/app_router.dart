import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_state.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/gym/join_gym_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

/// Navigation Key
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// App Router Provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final location = state.uri.path;

      // Allow splash to perform initialization
      if (location == '/') return null;

      final isLoggingIn = location == '/login' || location == '/register';

      switch (authState.status) {
        case AuthStatus.initial:
        case AuthStatus.loading:
          // Remain on splash or wait for resolution
          return null;

        case AuthStatus.unauthenticated:
        case AuthStatus.error:
          // Must be redirected to login if attempting protected pages
          return isLoggingIn ? null : '/login';

        case AuthStatus.authenticatedNoGym:
          // User is authenticated but hasn't joined a gym yet
          if (location == '/join-gym') return null;
          return '/join-gym';

        case AuthStatus.authenticatedWithGym:
          // Fully authenticated with gym association
          if (isLoggingIn || location == '/join-gym') {
            return '/dashboard';
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/join-gym',
        builder: (context, state) => const JoinGymScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});

/// Listenable adapter converting Riverpod auth state changes into GoRouter refresh notifications
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      notifyListeners();
    });
  }
}
