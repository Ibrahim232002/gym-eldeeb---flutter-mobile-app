import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Network status enumeration for offline-first architecture
enum NetworkStatus { online, offline }

/// Riverpod provider tracking network connectivity
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((results) {
    final isConnected = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    return isConnected ? NetworkStatus.online : NetworkStatus.offline;
  });
});

/// Network info helper
class NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfo([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  /// Check whether the device currently has network connectivity
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }
}
