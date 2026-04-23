import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/utils.dart';

/// A wrapper around [SharedPreferences] for simple key-value persistence.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  /// SharedPreferences key for the cached owner user JSON. Used to skip the
  /// `/profile` round-trip on cold start.
  static const String cachedOwnerUserKey = 'auth.cached_owner_user';

  /// SharedPreferences key for the cached shop-employee JSON. Used to skip
  /// the `/shop-employees/me` round-trip on cold start.
  static const String cachedEmployeeKey = 'auth.cached_employee';

  late final SharedPreferences _prefs;

  /// Initialize SharedPreferences instance.
  FutureEither<void> init() async {
    return runTask(() async {
      _prefs = await SharedPreferences.getInstance();
      AppLogger.info('StorageService (SharedPreferences) initialized');
    });
  }

  // --- SETTERS ---

  FutureEither<bool> setString(String key, String value) async =>
      runTask(() => _prefs.setString(key, value));

  FutureEither<bool> setBool(String key, bool value) async =>
      runTask(() => _prefs.setBool(key, value));

  FutureEither<bool> setInt(String key, int value) async =>
      runTask(() => _prefs.setInt(key, value));

  FutureEither<bool> setDouble(String key, double value) async =>
      runTask(() => _prefs.setDouble(key, value));

  FutureEither<bool> setStringList(String key, List<String> value) async =>
      runTask(() => _prefs.setStringList(key, value));

  // --- GETTERS ---

  String? getString(String key) => _prefs.getString(key);
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);
  double? getDouble(String key) => _prefs.getDouble(key);
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  // --- COMMON ---

  bool containsKey(String key) => _prefs.containsKey(key);

  FutureEither<bool> remove(String key) async =>
      runTask(() => _prefs.remove(key));

  FutureEither<bool> clear() async => runTask(() => _prefs.clear());

  // --- JSON-SHAPED HELPERS ---

  /// Decode a stored JSON object under [key]. Returns null if missing or
  /// malformed — callers should treat both the same way (no cached user).
  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Encode and persist an arbitrary JSON-compatible map under [key].
  Future<bool> setJson(String key, Map<String, dynamic> value) {
    return _prefs.setString(key, jsonEncode(value));
  }
}
