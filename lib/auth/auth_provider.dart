import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_profile.dart';
import '../data/models/gym.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// Main Auth State Notifier Provider
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Current User Profile Provider (convenience selector)
final currentProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authNotifierProvider).profile;
});

/// Current Gym Provider (convenience selector)
final currentGymProvider = Provider<Gym?>((ref) {
  return ref.watch(authNotifierProvider).gym;
});

/// Auth State Notifier managing authentication cycle & gym resolution
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    initializeAuth();
  }

  /// Initialize session on app startup from Supabase persistent session
  Future<void> initializeAuth() async {
    state = AuthState.loading();
    try {
      final user = _repository.currentUser;
      if (user == null) {
        state = AuthState.unauthenticated();
        return;
      }

      await refreshUserSession();
    } catch (e) {
      state = AuthState.unauthenticated(_cleanError(e));
    }
  }

  /// Refresh user profile and associated gym from database/cache
  Future<void> refreshUserSession() async {
    try {
      final profile = await _repository.fetchUserProfile();
      if (profile == null) {
        // Fallback placeholder profile from auth user metadata if not yet created in table
        final user = _repository.currentUser;
        if (user != null) {
          final metadataName = user.userMetadata?['full_name'] as String? ?? '';
          state = AuthState.authenticatedNoGym(
            UserProfile(id: user.id, fullName: metadataName),
          );
          return;
        }
        state = AuthState.unauthenticated();
        return;
      }

      // Check if user is associated with a gym
      if (profile.gymId == null || profile.gymId!.isEmpty) {
        state = AuthState.authenticatedNoGym(profile);
        return;
      }

      final gym = await _repository.fetchGym(profile.gymId!);
      if (gym == null) {
        // User has gym_id but gym details failed to load; keep authenticatedNoGym
        state = AuthState.authenticatedNoGym(profile);
        return;
      }

      // Fully authenticated with both profile and gym association
      state = AuthState.authenticatedWithGym(
        profile: profile,
        gym: gym,
      );
    } catch (e) {
      state = AuthState.error(_cleanError(e));
    }
  }

  /// Real Sign In with Email & Password
  Future<bool> signIn(String email, String password) async {
    state = AuthState.loading();
    try {
      await _repository.signIn(email: email, password: password);
      await refreshUserSession();
      return true;
    } catch (e) {
      state = AuthState.unauthenticated(_cleanError(e));
      return false;
    }
  }

  /// Real Sign Up with Email, Password & Full Name
  ///
  /// After successful signup, user is routed to Join Gym flow.
  Future<bool> signUp(String email, String password, String fullName) async {
    state = AuthState.loading();
    try {
      await _repository.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      await refreshUserSession();
      return true;
    } catch (e) {
      state = AuthState.unauthenticated(_cleanError(e));
      return false;
    }
  }

  /// Join Gym with Full Name and Invite Code using the Edge Function
  Future<bool> joinGym({
    required String fullName,
    required String inviteCode,
  }) async {
    final previousProfile = state.profile;
    state = AuthState.loading();
    try {
      await _repository.joinGym(
        fullName: fullName,
        inviteCode: inviteCode,
      );
      await refreshUserSession();
      return true;
    } catch (e) {
      final errorMsg = _cleanError(e);
      state = AuthState.error(errorMsg);
      // Revert to authenticatedNoGym to keep user on Join Gym screen
      if (previousProfile != null) {
        state = AuthState.authenticatedNoGym(previousProfile);
      }
      rethrow;
    }
  }

  /// Real Sign Out
  Future<void> signOut() async {
    state = AuthState.loading();
    await _repository.signOut();
    state = AuthState.unauthenticated();
  }

  String _cleanError(dynamic e) {
    return e.toString().replaceAll('Exception: ', '').trim();
  }
}
