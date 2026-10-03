import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/gym.dart';

/// SharedPreferences instance provider
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Local persistence service provider
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

/// Service for caching authentication state, user profile, gym data,
/// and synchronization timestamps for offline-first readiness.
class LocalStorageService {
  static const String _keyCachedProfile = 'cached_user_profile';
  static const String _keyCachedGym = 'cached_gym_data';
  static const String _keyLastSyncAt = 'cached_last_sync_timestamp';

  /// Save cached user profile
  Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedProfile, jsonEncode(profile.toJson()));
  }

  /// Retrieve cached user profile
  Future<UserProfile?> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCachedProfile);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Save cached gym details
  Future<void> saveGym(Gym gym) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCachedGym, jsonEncode(gym.toJson()));
  }

  /// Retrieve cached gym details
  Future<Gym?> getGym() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyCachedGym);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return Gym.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear all cached authentication & gym data on logout
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCachedProfile);
    await prefs.remove(_keyCachedGym);
    await prefs.remove(_keyLastSyncAt);
  }
}
