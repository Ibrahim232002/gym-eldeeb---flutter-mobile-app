import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/auth_provider.dart';
import '../../auth/auth_state.dart';
import '../../core/theme/app_colors.dart';

/// Branded Gym ElDeeb splash shown while the saved session is checked.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    _navigate(ref.read(authNotifierProvider));
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
        // Wait until the auth notifier finishes checking the saved session.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.status != AuthStatus.loading &&
          next.status != AuthStatus.initial) {
        _navigate(next);
      }
    });

    return Scaffold(
      backgroundColor: context.appPalette.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(context.appPalette.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'بنجهّز بياناتك...',
              style: TextStyle(
                color: context.appPalette.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
