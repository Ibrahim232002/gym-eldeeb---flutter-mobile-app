import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand_logo.dart';

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
    _checkInitialState();
  }

  void _checkInitialState() async {
    // Artificial small delay for smooth branding experience
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);
    _navigate(authState);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandLogo(size: 96),
            const SizedBox(height: 48),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جارٍ التحميل ومزامنة البيانات...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
