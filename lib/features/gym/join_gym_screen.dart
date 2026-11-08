import 'package:flutter/material.dart';
import '../../core/utils/top_snackbar.dart';
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
        showTopSnackBar(context, 
          SnackBar(
            content: const Text(
              'تمام، انضمامك للجيم تم بنجاح!',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: context.appPalette.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();
      setState(() => _localErrorMessage = errorMsg);

      showTopSnackBar(context, 
        SnackBar(
          content: Text(
            errorMsg,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: context.appPalette.error,
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
        title: const Text('الانضمام للجيم'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: context.appPalette.error),
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
                          color: context.appPalette.primary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'حسابك لسه مش مربوط بجيم. اكتب اسمك وكود الدعوة اللي وصلك من إدارة الجيم عشان تكمل.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Error notification if join failed
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

                  // Full Name Input
                  CustomTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    hint: 'اكتب اسمك بالكامل',
                    prefixIcon: Icons.person_outline_rounded,
                    readOnly: _isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'اكتب اسمك بالكامل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Invite Code Input
                  CustomTextField(
                    controller: _codeController,
                    label: 'كود الدعوة',
                    hint: 'اكتب الكود اللي وصلك من الجيم',
                    prefixIcon: Icons.qr_code_rounded,
                    readOnly: _isSubmitting,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'اكتب كود الدعوة';
                      }
                      if (val.trim().length < 4) {
                        return 'الكود لازم يكون 4 حروف أو أرقام على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  PrimaryButton(
                    text: 'انضم للجيم',
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
                            await ref
                                .read(authNotifierProvider.notifier)
                                .signOut();
                            if (context.mounted) context.go('/login');
                          },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('تسجيل الدخول بحساب تاني'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appPalette.textSecondary,
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
