import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps the platform-native secure store (Keychain on iOS, Keystore on
/// Android) for the server URL + auth token. Phase 3 is the first consumer.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});
