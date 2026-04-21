import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/utils.dart';

/// A service to securely store sensitive data like JWT tokens or API keys.
///
/// Uses [FlutterSecureStorage] which utilizes Keychain (iOS) and Keystore (Android).
class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  /// Secure-storage key for the owner (User Sanctum) bearer token.
  static const String ownerTokenKey = 'auth.owner_token';

  /// Secure-storage key for the ShopEmployee bearer token.
  static const String employeeTokenKey = 'auth.employee_token';

  /// Which token the Dio interceptor should inject: `owner` | `employee`.
  static const String authModeKey = 'auth.mode';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions.defaultOptions,
  );

  /// Write a sensitive value to secure storage.
  FutureEither<void> write(String key, String value) async {
    return runTask(() => _storage.write(key: key, value: value));
  }

  /// Read a sensitive value from secure storage.
  FutureEither<String?> read(String key) async {
    return runTask(() => _storage.read(key: key));
  }

  /// Delete a specific key from secure storage.
  FutureEither<void> delete(String key) async {
    return runTask(() => _storage.delete(key: key));
  }

  /// Wipe all data from secure storage.
  FutureEither<void> deleteAll() async {
    return runTask(() => _storage.deleteAll());
  }

  /// Check if a key exists in secure storage.
  FutureEither<bool> containsKey(String key) async {
    return runTask(() => _storage.containsKey(key: key));
  }

  /// Read the token the Dio interceptor should currently inject.
  ///
  /// Resolves the active `authMode` and returns the matching token (owner or
  /// employee). Returns `null` when no active token is stored.
  Future<String?> readActiveToken() async {
    final mode = await _storage.read(key: authModeKey);
    final key = mode == 'employee' ? employeeTokenKey : ownerTokenKey;
    return _storage.read(key: key);
  }

  /// Persist an owner token and mark it as the active auth mode.
  Future<void> writeOwnerToken(String token) async {
    await _storage.write(key: ownerTokenKey, value: token);
    await _storage.write(key: authModeKey, value: 'owner');
  }

  /// Persist an employee token and mark it as the active auth mode.
  Future<void> writeEmployeeToken(String token) async {
    await _storage.write(key: employeeTokenKey, value: token);
    await _storage.write(key: authModeKey, value: 'employee');
  }

  /// Clear the currently active token + auth mode.
  ///
  /// The other token (if any) remains so the user can switch back without
  /// re-authenticating.
  Future<void> clearActiveToken() async {
    final mode = await _storage.read(key: authModeKey);
    final key = mode == 'employee' ? employeeTokenKey : ownerTokenKey;
    await _storage.delete(key: key);
    await _storage.delete(key: authModeKey);
  }

  /// Clear both owner and employee tokens + auth mode.
  Future<void> clearAllAuth() async {
    await _storage.delete(key: ownerTokenKey);
    await _storage.delete(key: employeeTokenKey);
    await _storage.delete(key: authModeKey);
  }
}
