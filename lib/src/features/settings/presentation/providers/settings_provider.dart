import 'package:flutter/material.dart';

import '../../../../services/storage_service.dart';

/// Owns app-wide preferences the user can change at runtime: theme mode and
/// locale. Persisted via [StorageService] (SharedPreferences) so choices
/// survive restart.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    _loadFromStorage();
  }

  static const String _themeModeKey = 'settings.theme_mode';
  static const String _localeKey = 'settings.locale';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// The user's preferred locale, or `null` if they've never set one
  /// (in which case the app falls back to the device locale).
  Locale? _locale;
  Locale? get locale => _locale;

  void _loadFromStorage() {
    final raw = StorageService.instance.getString(_themeModeKey);
    if (raw != null) {
      _themeMode = _parseThemeMode(raw);
    }
    final langCode = StorageService.instance.getString(_localeKey);
    if (langCode != null && langCode.isNotEmpty) {
      _locale = Locale(langCode);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await StorageService.instance.setString(_themeModeKey, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale?.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    await StorageService.instance.setString(_localeKey, locale.languageCode);
  }

  ThemeMode _parseThemeMode(String raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}
