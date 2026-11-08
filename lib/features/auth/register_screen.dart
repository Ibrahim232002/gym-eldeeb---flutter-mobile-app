import 'package:flutter/material.dart';
import '../../core/utils/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../auth/auth_state.dart';
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
  bool _emailConfirmationPending = false;
  bool _accountAlreadyRegistered = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    setState(() {
      _localErrorMessage = null;
      _emailConfirmationPending = false;
      _accountAlreadyRegistered = false;
    });

    if (!_formKey.currentState!.validate()) return;

    final result = await ref.read(authNotifierProvider.notifier).signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

    if (!mounted) return;

    if (result == SignUpOutcome.signedIn) {
      // Newly registered users with an active session proceed directly to Join Gym.
      showTopSnackBar(
        context,
        SnackBar(
          content: const Text(
            'تم إنشاء الحساب بنجاح! أدخل رمز الدعوة للانضمام لصالة الجيم.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/join-gym');
      return;
    }

    if (result == SignUpOutcome.alreadyRegistered) {
      setState(() => _accountAlreadyRegistered = true);
      showTopSnackBar(
        context,
        SnackBar(
          content: const Text(
            'الإيميل ده متسجل عندنا بالفعل. سجّل دخولك بنفس الإيميل وكلمة المرور.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.primary,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6),
        ),
      );
      return;
    }

    if (result == SignUpOutcome.emailConfirmationRequired) {
      setState(() => _emailConfirmationPending = true);
      showTopSnackBar(
        context,
        SnackBar(
          content: const Text(
            'تم إنشاء الحساب وإرسال رسالة تأكيد إلى بريدك الإلكتروني. أكّد البريد أولاً، ثم سجّل الدخول لإدخال كود الجيم.',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 7),
        ),
      );
      return;
    }

    final error = ref.read(authNotifierProvider).errorMessage ??
        'حصلت مشكلة وإحنا بنعمل الحساب. جرّب تاني بعد شوية.';
    setState(() => _localErrorMessage = error);

    showTopSnackBar(
      context,
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
                    'اعمل حساب جديد عشان تنضم لفريق جيم الديب',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اعمل حسابك الأول، وبعدها اكتب كود الدعوة اللي وصلك من إدارة الجيم.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  if (_accountAlreadyRegistered) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appPalette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.appPalette.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'الإيميل ده متسجل عندنا بالفعل. بدل ما تعمل حساب جديد، سجّل دخولك بنفس الإيميل وكلمة المرور.',
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('روح لتسجيل الدخول'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Successful signup that is waiting for email verification.
                  if (_emailConfirmationPending) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appPalette.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.appPalette.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mark_email_read_outlined,
                            color: context.appPalette.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'الحساب اتعمل! افتح رسالة التأكيد اللي وصلتك على الإيميل واضغط على الرابط، وبعدها ارجع سجّل دخولك عشان تدخل كود الجيم.',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: context.appPalette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

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
                    readOnly: isLoading || _emailConfirmationPending || _accountAlreadyRegistered,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'اكتب اسمك بالكامل';
                      }
                      if (val.trim().length < 3) {
                        return 'الاسم لازم يكون 3 حروف على الأقل';
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
                    readOnly: isLoading || _emailConfirmationPending || _accountAlreadyRegistered,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'اكتب بريدك الإلكتروني';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'البريد الإلكتروني شكله مش صحيح';
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
                    readOnly: isLoading || _emailConfirmationPending || _accountAlreadyRegistered,
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
                        return 'اكتب كلمة المرور';
                      }
                      if (val.length < 6) {
                        return 'كلمة المرور لازم تكون 6 أحرف على الأقل';
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
                    readOnly: isLoading || _emailConfirmationPending || _accountAlreadyRegistered,
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
                        return 'أكد كلمة المرور';
                      }
                      if (val != _passwordController.text) {
                        return 'كلمتا المرور مش متطابقتين';
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
                    onPressed: (_emailConfirmationPending || _accountAlreadyRegistered) ? null : _handleRegister,
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
