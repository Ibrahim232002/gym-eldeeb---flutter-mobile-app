import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Real Supabase Join Gym Screen for Gym ElDeeb
///
/// Collects user's full name and invite code, securely invoking the 'join-gym' Edge Function
/// with the user's Supabase session Bearer token in the Authorization header.
class JoinGymScreen extends ConsumerStatefulWidget {
  const JoinGymScreen({super.key});

  @override
  ConsumerState<JoinGymScreen> createState() => _JoinGymScreenState();
}

class _JoinGymScreenState extends ConsumerState<JoinGymScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _localErrorMessage;
  bool _initializedName = false;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _prefillNameIfAvailable() {
    if (_initializedName) return;
    final profile = ref.read(currentProfileProvider);
    if (profile != null && profile.fullName.isNotEmpty) {
      _nameController.text = profile.fullName;
      _initializedName = true;
    }
  }

  void _handleJoin() async {
    setState(() => _localErrorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await ref.read(authNotifierProvider.notifier).joinGym(
            fullName: _nameController.text.trim(),
            inviteCode: _codeController.text.trim(),
          );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم الانضمام للجيم بنجاح! مرحباً بك في جيم الديب.',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();
      setState(() => _localErrorMessage = errorMsg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _prefillNameIfAvailable();
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الانضمام لصالة الجيم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(size: 72, showSubtitle: false),
                  const SizedBox(height: 20),
                  Text(
                    'أهلاً بك يا ${profile?.fullName.isNotEmpty == true ? profile!.fullName : "كابتن"}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'حسابك غير مرتبط بصالة جيم حالياً. يرجى إدخال اسمك ورمز الدعوة للانضمام كمدرب أو شريك في إدارة جيم الديب.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Information Card about Secure Edge Function Join
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.vpn_key_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'تحقق أمني مشفر (Edge Function)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'يتم إرسال رمز الدخول وتوكن الجلسة إلى دالة join-gym السحابية لمنح الصلاحيات وربط الجيم بأعلى معايير الأمان (RLS).',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error notification if join failed
                  if (_localErrorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 20),
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

                  // Full Name Input
                  CustomTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'الاسم المسجل في كادر الجيم',
                    prefixIcon: Icons.person_outline_rounded,
                    readOnly: _isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال الاسم بالكامل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Invite Code Input
                  CustomTextField(
                    controller: _codeController,
                    label: 'رمز الدعوة (Invite Code)',
                    hint: 'أدخل كود الدعوة الخاص بالجيم',
                    prefixIcon: Icons.qr_code_rounded,
                    readOnly: _isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال رمز الدعوة';
                      }
                      if (val.trim().length < 4) {
                        return 'رمز الدعوة يجب ألا يقل عن 4 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  PrimaryButton(
                    text: 'تأكيد الرمز والانضمام للجيم',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _handleJoin,
                  ),
                  const SizedBox(height: 20),

                  // Logout option
                  TextButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            await ref.read(authNotifierProvider.notifier).signOut();
                            if (context.mounted) context.go('/login');
                          },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('تسجيل الدخول بحساب آخر'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
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
