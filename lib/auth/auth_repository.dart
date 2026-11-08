import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../core/network/network_info.dart';
import '../data/local/local_storage_service.dart';
import '../data/models/user_profile.dart';
import '../data/models/gym.dart';
import 'auth_state.dart' as app_auth;

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = Supabase.instance.client;
  final localStorage = ref.watch(localStorageServiceProvider);
  final networkInfo = NetworkInfo();
  return AuthRepository(supabase, localStorage, networkInfo);
});

/// Real Supabase Authentication and Profile Repository for Gym ElDeeb
///
/// Handles real Supabase email/password auth, session persistence, profile sync,
/// strict RLS compliance, and secure server-side invocation of the 'join-gym' Edge Function.
class AuthRepository {
  final SupabaseClient _supabase;
  final LocalStorageService _localStorage;
  final NetworkInfo _networkInfo;

  AuthRepository(
    this._supabase,
    this._localStorage,
    this._networkInfo,
  );

  /// Current authenticated Supabase user
  User? get currentUser => _supabase.auth.currentUser;

  /// Current Supabase session (contains access token)
  Session? get currentSession => _supabase.auth.currentSession;

  /// Stream of Supabase Auth state changes
  Stream<app_auth.AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange.map((data) => data.session != null
          ? const app_auth.AuthState(status: app_auth.AuthStatus.loading)
          : app_auth.AuthState.unauthenticated());

  /// Real Sign In with Email and Password
  ///
  /// Maps Supabase Auth errors to user-friendly Arabic error messages.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password;

    try {
      await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthExceptionToArabic(e));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('network') ||
          msg.contains('clientexception')) {
        throw Exception(
            'مش قادرين نتصل دلوقتي. اتأكد من الإنترنت وجرب تاني.');
      }
      throw Exception('حصلت مشكلة وإحنا بنحاول نسجّل دخولك. جرّب تاني بعد شوية.');
    }
  }

  /// Real Sign Up with Email, Password, and Full Name
  ///
  /// SECURITY:
  /// - Client NEVER selects or modifies `role` or `gym_id`.
  /// - Only `full_name` is passed in user_metadata; no database profile is created here.
  /// - User remains unassociated with any gym until redeeming an invite code via the Edge Function.
  /// Reports whether signup created a new account, needs email confirmation, or found an existing account.
  Future<app_auth.SignUpOutcome> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password;
    final cleanName = fullName.trim();

    try {
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
        data: {'full_name': cleanName},
      );

      final user = response.user;
      if (user == null) {
        throw Exception('حصلت مشكلة وإحنا بنعمل الحساب. جرّب تاني بعد شوية.');
      }

      // Supabase hides whether a confirmed account exists when email
      // confirmation is enabled. An empty identities list identifies that
      // obfuscated "already registered" response; no new account was created.
      if (user.identities?.isEmpty == true) {
        return app_auth.SignUpOutcome.alreadyRegistered;
      }

      // Do not create a placeholder row in public.profiles here.
      // The secure join-gym flow calls claim_gym_invite, which creates the
      // profile and assigns gym_id/role atomically after validating the invite.
      // Keeping profiles absent until invite redemption also prevents
      // claim_gym_invite from rejecting this newly registered user.
      // With Confirm Email enabled, a new user is returned without a session.
      return response.session != null
          ? app_auth.SignUpOutcome.signedIn
          : app_auth.SignUpOutcome.emailConfirmationRequired;
    } on AuthException catch (e) {
      throw Exception(_mapAuthExceptionToArabic(e));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('network')) {
        throw Exception(
            'مش قادرين نتصل دلوقتي. اتأكد من الإنترنت وجرب تاني.');
      }
      throw Exception('حصلت مشكلة وإحنا بنعمل الحساب. جرّب تاني بعد شوية.');
    }
  }

  /// Sign out current session and wipe local persistence
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // Continue cleanup even if network call fails
    }
    await _localStorage.clearAll();
  }

  /// Fetch user profile from database with offline cache fallback
  Future<UserProfile?> fetchUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      final remoteProfile = await _fetchRemoteProfile(user.id);
      if (remoteProfile != null) {
        await _localStorage.saveProfile(remoteProfile);
        return remoteProfile;
      }
    }

    // Never reuse a cached profile belonging to a different signed-in account.
    final cachedProfile = await _localStorage.getProfile();
    return cachedProfile?.id == user.id ? cachedProfile : null;
  }

  /// Internal helper to fetch profile from Supabase
  Future<UserProfile?> _fetchRemoteProfile(String userId) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Fetch gym details with offline cache fallback
  Future<Gym?> fetchGym(String gymId) async {
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      try {
        final response = await _supabase
            .from(SupabaseConstants.tableGyms)
            .select()
            .eq('id', gymId)
            .maybeSingle();

        if (response != null) {
          final gym = Gym.fromJson(response);
          await _localStorage.saveGym(gym);
          return gym;
        }
      } catch (_) {
        // Fall back to local cache
      }
    }

    final cachedGym = await _localStorage.getGym();
    return cachedGym?.id == gymId ? cachedGym : null;
  }

  /// Join a gym using invite code via the secure 'join-gym' Edge Function
  ///
  /// CRITICAL SECURITY REQUIREMENT:
  /// - URL: https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym
  /// - Authorization: Bearer `<accessToken>`
  /// - Body: {"full_name": "...", "invite_code": "..."}
  /// - Role assignment (coach/owner) and gym_id linkage are strictly performed server-side.
  Future<void> joinGym({
    required String fullName,
    required String inviteCode,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      throw Exception('لازم تكون متصل بالإنترنت عشان تنضم للجيم. جرّب تاني لما الاتصال يرجع.');
    }

    final code = inviteCode.trim();
    final name = fullName.trim();

    if (name.isEmpty) {
      throw Exception('اكتب اسمك بالكامل.');
    }
    if (code.isEmpty) {
      throw Exception('اكتب كود الدعوة اللي وصلك من الجيم.');
    }

    final session = currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('سجّل دخولك تاني وجرب.');
    }

    // Call the existing Edge Function with Authorization header and payload
    final response = await _supabase.functions.invoke(
      'join-gym',
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
      body: {
        'full_name': name,
        'invite_code': code,
      },
    );

    if (response.status != 200) {
      String errorMessage =
          'حصلت مشكلة وإحنا بنحاول نضمّك للجيم. راجع كود الدعوة وجرب تاني.';
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['error'] != null) {
          final raw = data['error'].toString();
          final lower = raw.toLowerCase();
          if (lower.contains('invalid') || lower.contains('not found')) {
            errorMessage = 'كود الدعوة مش صحيح. اتأكد إنك كتبته زي ما وصلك.';
          } else if (lower.contains('expire')) {
            errorMessage = 'كود الدعوة انتهت صلاحيته. اطلب كود جديد من إدارة الجيم.';
          } else if (lower.contains('max') ||
              lower.contains('limit') ||
              lower.contains('used')) {
            errorMessage = 'كود الدعوة وصل للعدد المسموح. اطلب كود جديد من إدارة الجيم.';
          } else if (lower.contains('already')) {
            errorMessage = 'الحساب ده مربوط بجيم بالفعل. لو محتاج مساعدة، كلم إدارة الجيم.';
          } else {
            errorMessage = 'حصلت مشكلة وإحنا بنحاول نضمّك للجيم. جرّب تاني بعد شوية.';
          }
        } else if (data['message'] != null) {
          errorMessage = 'حصلت مشكلة وإحنا بنحاول نضمّك للجيم. جرّب تاني بعد شوية.';
        }
      }
      throw Exception(errorMessage);
    }
  }

  /// Translates standard Supabase Auth exceptions to clean Arabic messages
  String _mapAuthExceptionToArabic(AuthException e) {
    final message = e.message.toLowerCase();
    final code = (e.statusCode ?? '').toLowerCase();

    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials') ||
        message.contains('invalid-credential') ||
        code == '400' && message.contains('credential')) {
      return 'الإيميل أو كلمة المرور مش صح. راجعهم وجرب تاني.';
    }
    if (message.contains('email not confirmed')) {
      return 'لسه محتاج تأكد بريدك الإلكتروني. افتح رسالة التأكيد وجرب تسجّل دخول تاني.';
    }
    if (message.contains('user already registered') ||
        message.contains('already exists') ||
        message.contains('email_exists') ||
        message.contains('email already registered')) {
      return 'الإيميل ده متسجل عندنا بالفعل. سجّل دخولك بنفس الإيميل بدل ما تعمل حساب جديد.';
    }
    if (message.contains('password') && message.contains('least')) {
      return 'كلمة المرور لازم تكون 6 حروف على الأقل.';
    }
    if (message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('for security purposes') ||
        message.contains('only request this after')) {
      return 'حاولت كذا مرة ورا بعض. استنى شوية وجرب تاني.';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'مش قادرين نتصل دلوقتي. اتأكد من الإنترنت وجرب تاني.';
    }
    return 'حصلت مشكلة وإحنا بنحاول ندخلّك. راجع بياناتك وجرب تاني.';
  }
}
