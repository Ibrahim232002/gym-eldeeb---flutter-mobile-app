import '../data/models/user_profile.dart';
import '../data/models/gym.dart';

/// Status of the current user session
enum AuthStatus {
  initial,
  loading,
  unauthenticated,
  authenticatedNoGym,
  authenticatedWithGym,
  error,
}

/// Authentication state model
class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final Gym? gym;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.profile,
    this.gym,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.initial);

  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);

  factory AuthState.unauthenticated([String? error]) => AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error,
      );

  factory AuthState.authenticatedNoGym(UserProfile profile) => AuthState(
        status: AuthStatus.authenticatedNoGym,
        profile: profile,
      );

  factory AuthState.authenticatedWithGym({
    required UserProfile profile,
    required Gym gym,
  }) =>
      AuthState(
        status: AuthStatus.authenticatedWithGym,
        profile: profile,
        gym: gym,
      );

  factory AuthState.error(String message) => AuthState(
        status: AuthStatus.error,
        errorMessage: message,
      );

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated =>
      status == AuthStatus.authenticatedWithGym ||
      status == AuthStatus.authenticatedNoGym;
  bool get hasGym => status == AuthStatus.authenticatedWithGym && gym != null;
}
