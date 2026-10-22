import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Real Supabase Register Screen for Gym ElDeeb
///
/// Features full name, email, password, confirm password,
/// validation of all fields, and routes newly authenticated users directly to Join Gym.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _localErrorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    setState(() => _localErrorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      // Newly registered users have no gym and proceed directly to Join Gym
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إنشاء الحساب بنجاح! أدخل رمز الدعوة للانضمام لصالة الجيم.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/join-gym');
    } else {
      final error = ref.read(authNotifierProvider).errorMessage ??
          'فشل إنشاء الحساب، يرجى المحاولة لاحقاً';
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
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
      ),
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
                  const BrandLogo(size: 64, showSubtitle: false),
                  const SizedBox(height: 24),
                  Text(
                    'انضم إلى كادر إدارة جيم الديب',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'قم بإنشاء حسابك ثم اربطه بالجيم بواسطة رمز الدعوة الآمن',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Error notification if registration failed
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

                  // Full Name Field
                  CustomTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'كابتن أحمد الديب',
                    prefixIcon: Icons.person_outline_rounded,
                    readOnly: isLoading,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال الاسم بالكامل';
                      }
                      if (val.trim().length < 3) {
                        return 'الاسم يجب ألا يقل عن 3 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
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
                  const SizedBox(height: 16),

                  // Password Field
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
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'تأكيد كلمة المرور',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_clock_outlined,
                    obscureText: _obscureConfirmPassword,
                    readOnly: isLoading,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appPalette.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'يرجى تأكيد كلمة المرور';
                      }
                      if (val != _passwordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  PrimaryButton(
                    text: 'إنشاء الحساب والمتابعة',
                    icon: Icons.person_add_alt_1_rounded,
                    isLoading: isLoading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 16),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'لديك حساب بالفعل؟',
                        style:
                            TextStyle(color: context.appPalette.textSecondary),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : () => context.pop(),
                        child: Text(
                          'تسجيل الدخول',
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
