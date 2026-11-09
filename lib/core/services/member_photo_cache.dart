import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_constants.dart';

class _SignedPhotoUrl {
  final Future<String> future;
  final DateTime expiresAt;

  const _SignedPhotoUrl(this.future, this.expiresAt);
}

/// Shared URL and disk-cache coordinator for private member photos.
///
/// Signed URLs are reused across avatar widgets for 50 minutes. Image bytes
/// use a stable gym/path key, so a refreshed signed URL does not download the
/// same photo again on Android/iOS.
class MemberPhotoCache {
  MemberPhotoCache._();

  static const signedUrlLifetime = Duration(minutes: 50);
  static final CacheManager cacheManager = CacheManager(
    Config(
      'gym-eldeeb-member-photos-v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );

  static final Map<String, _SignedPhotoUrl> _signedUrls = {};

  static String cacheKey(String gymId, String photoPath) =>
      'gym-eldeeb-member-photo:$gymId:$photoPath';

  static Future<String> signedUrl({
    required SupabaseClient client,
    required String gymId,
    required String photoPath,
  }) {
    final key = cacheKey(gymId, photoPath);
    final now = DateTime.now();
    final cached = _signedUrls[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.future;
    }

    final request = client.storage
        .from(SupabaseConstants.bucketMemberPhotos)
        .createSignedUrl(photoPath, const Duration(hours: 1).inSeconds);
    final entry = _SignedPhotoUrl(request, now.add(signedUrlLifetime));
    _signedUrls[key] = entry;

    // Remove failed requests so a transient network error can be retried.
    request.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_signedUrls[key], entry)) {
          _signedUrls.remove(key);
        }
      },
    );
    return request;
  }

  static Future<void> evict(String gymId, String photoPath) async {
    final key = cacheKey(gymId, photoPath);
    final cached = _signedUrls.remove(key);
    if (cached != null) {
      try {
        final url = await cached.future;
        await CachedNetworkImage.evictFromCache(
          url,
          cacheKey: key,
          cacheManager: cacheManager,
        );
      } catch (_) {
        // The disk entry is still removed below, even when URL refresh failed.
      }
    }
    await cacheManager.removeFile(key);
  }

  static Future<void> clearAll() async {
    _signedUrls.clear();
    await cacheManager.emptyCache();
  }
}
