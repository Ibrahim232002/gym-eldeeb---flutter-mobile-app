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
      if (msg.contains('socket') || msg.contains('network') || msg.contains('clientexception')) {
        throw Exception('تعذر الاتصال بالخادم، يرجى التحقق من اتصالك بالإنترنت');
      }
      throw Exception('فشل تسجيل الدخول، يرجى المحاولة لاحقاً');
    }
  }

  /// Real Sign Up with Email, Password, and Full Name
  ///
  /// SECURITY:
  /// - Client NEVER selects or modifies `role` or `gym_id`.
  /// - Only `full_name` is passed in user_metadata and optional profile placeholder.
  /// - User remains unassociated with any gym until redeeming an invite code via the Edge Function.
  Future<void> signUp({
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
      if (user != null) {
        // Ensure initial profile record contains full_name without modifying role or gym_id
        final existing = await _fetchRemoteProfile(user.id);
        if (existing == null) {
          try {
            await _supabase.from(SupabaseConstants.tableProfiles).upsert({
              'id': user.id,
              'full_name': cleanName,
            });
          } catch (_) {
            // Profile may be created by database trigger, continue safely
          }
        }
      }
    } on AuthException catch (e) {
      throw Exception(_mapAuthExceptionToArabic(e));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') || msg.contains('network')) {
        throw Exception('تعذر الاتصال بالخادم، يرجى التحقق من اتصالك بالإنترنت');
      }
      throw Exception('فشل إنشاء الحساب، يرجى المحاولة مرة أخرى');
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

    // Fallback to locally cached profile
    return await _localStorage.getProfile();
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

    return await _localStorage.getGym();
  }

  /// Join a gym using invite code via the secure 'join-gym' Edge Function
  ///
  /// CRITICAL SECURITY REQUIREMENT:
  /// - URL: https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym
  /// - Authorization: Bearer <accessToken>
  /// - Body: {"full_name": "...", "invite_code": "..."}
  /// - Role assignment (coach/owner) and gym_id linkage are strictly performed server-side.
  Future<void> joinGym({
    required String fullName,
    required String inviteCode,
  }) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) {
      throw Exception('لا يمكن الانضمام للجيم أثناء عدم الاتصال بالإنترنت');
    }

    final code = inviteCode.trim();
    final name = fullName.trim();

    if (name.isEmpty) {
      throw Exception('يرجى إدخال الاسم بالكامل');
    }
    if (code.isEmpty) {
      throw Exception('يرجى إدخال رمز دعوة صحيح');
    }

    final session = currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('جلسة المستخدم غير صالحة، يرجى تسجيل الدخول مجدداً');
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
      String errorMessage = 'تعذر الانضمام للجيم، يرجى التحقق من صحة رمز الدعوة';
      if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data['error'] != null) {
          final raw = data['error'].toString();
          final lower = raw.toLowerCase();
          if (lower.contains('invalid') || lower.contains('not found')) {
            errorMessage = 'رمز الدعوة غير صحيح أو غير موجود';
          } else if (lower.contains('expire')) {
            errorMessage = 'رمز الدعوة منتهي الصلاحية';
          } else if (lower.contains('max') || lower.contains('limit') || lower.contains('used')) {
            errorMessage = 'تم استنفاد الحد الأقصى لاستخدام رمز الدعوة هذا';
          } else if (lower.contains('already')) {
            errorMessage = 'هذا الحساب مرتبط بالفعل بصالة جيم';
          } else {
            errorMessage = raw;
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'].toString();
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
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني لتتمكن من تسجيل الدخول';
    }
    if (message.contains('user already registered') ||
        message.contains('already exists')) {
      return 'هذا البريد الإلكتروني مسجل بالفعل، يرجى تسجيل الدخول';
    }
    if (message.contains('password') && message.contains('least')) {
      return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
    }
    if (message.contains('rate limit') || message.contains('too many requests')) {
      return 'تم تجاوز الحد المسموح من المحاولات، يرجى الانتظار قليلاً';
    }
    if (message.contains('network') || message.contains('connection')) {
      return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصالك بالإنترنت';
    }
    return e.message.isNotEmpty ? e.message : 'حدث خطأ أثناء المصادقة، يرجى المحاولة لاحقاً';
  }
}
