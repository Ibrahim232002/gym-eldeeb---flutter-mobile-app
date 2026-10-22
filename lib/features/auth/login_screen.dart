import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Real Supabase Login Screen for Gym ElDeeb
///
/// Features clean RTL layout, real Supabase credentials verification,
/// loading states, and clear Arabic error messages.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _localErrorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() => _localErrorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    if (success) {
      final state = ref.read(authNotifierProvider);
      if (state.hasGym) {
        context.go('/dashboard');
      } else {
        context.go('/join-gym');
      }
    } else {
      final error = ref.read(authNotifierProvider).errorMessage ??
          'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      setState(() => _localErrorMessage = error);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(size: 72),
                  const SizedBox(height: 32),
                  Text(
                    'تسجيل الدخول للمدربين والمالكين',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.appPalette.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجل دخولك لمتابعة صالة الألعاب الرياضية والاشتراكات',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Prominent Arabic Error Message Box if failure occurred
                  if (_localErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appPalette.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: context.appPalette.error
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: context.appPalette.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _localErrorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFCA5A5),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Email Input
                  CustomTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني',
                    hint: 'coach@gymeldeeb.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    readOnly: isLoading,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'صيغة البريد الإلكتروني غير صحيحة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Input
                  CustomTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    readOnly: isLoading,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appPalette.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (val.length < 6) {
                        return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  PrimaryButton(
                    text: 'تسجيل الدخول',
                    icon: Icons.login_rounded,
                    isLoading: isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 20),

                  // Go to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ليس لديك حساب بعد؟',
                        style:
                            TextStyle(color: context.appPalette.textSecondary),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                setState(() => _localErrorMessage = null);
                                context.push('/register');
                              },
                        child: Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            color: context.appPalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
