import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../auth/auth_state.dart';

/// Splash Screen initializing session and redirecting user
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigate(ref.read(authNotifierProvider));
    });
  }

  void _navigate(AuthState state) {
    if (!mounted) return;

    switch (state.status) {
      case AuthStatus.authenticatedWithGym:
        context.go('/dashboard');
        break;
      case AuthStatus.authenticatedNoGym:
        context.go('/join-gym');
        break;
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        context.go('/login');
        break;
      case AuthStatus.initial:
      case AuthStatus.loading:
        // Wait for state resolution in listener
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status != AuthStatus.loading && next.status != AuthStatus.initial) {
        _navigate(next);
      }
    });

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
