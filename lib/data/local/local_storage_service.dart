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

  /// Clear account-scoped snapshots on logout while preserving pending writes.
  /// Pending queues are intentionally retained for later recovery by their owner;
  /// they must never be replayed under a different authenticated account.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final cacheKeys = keys.where((key) =>
        key == _keyCachedProfile ||
        key == _keyCachedGym ||
        key == _keyLastSyncAt ||
        key == 'cached_user_gym' ||
        key.startsWith('cache_members_') ||
        key.startsWith('cache_plans_') ||
        key.startsWith('cache_memberships_') ||
        key.startsWith('cache_payments_'));
    for (final key in cacheKeys) {
      await prefs.remove(key);
    }
    // Do not remove pending_queue_*: queued business operations may represent
    // unsynced work and require explicit same-account recovery.
  }
}
