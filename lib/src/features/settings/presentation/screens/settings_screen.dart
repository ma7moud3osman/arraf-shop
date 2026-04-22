import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// User preferences: app language and theme mode. All changes are applied
/// immediately and persisted.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SectionHeader(labelKey: 'settings.language'),
          _LanguageSection(),
          SizedBox(height: 16),
          _SectionHeader(labelKey: 'settings.theme'),
          _ThemeSection(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.labelKey});
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        labelKey.tr().toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentCode =
        settings.locale?.languageCode ?? context.locale.languageCode;

    return RadioGroup<String>(
      groupValue: currentCode,
      onChanged: (code) async {
        if (code == null) return;
        await settings.setLocale(Locale(code));
        if (!context.mounted) return;
        await context.setLocale(Locale(code));
      },
      child: Column(
        children: [
          for (final locale in context.supportedLocales)
            RadioListTile<String>(
              value: locale.languageCode,
              activeColor: cs.primary,
              title: Text(
                _nameFor(locale.languageCode),
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                locale.languageCode.toUpperCase(),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  String _nameFor(String code) {
    return switch (code) {
      'en' => 'English',
      'ar' => 'العربية',
      _ => code,
    };
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RadioGroup<ThemeMode>(
      groupValue: settings.themeMode,
      onChanged: (value) {
        if (value == null) return;
        settings.setThemeMode(value);
      },
      child: Column(
        children: [
          for (final (mode, labelKey, icon) in const [
            (ThemeMode.system, 'settings.theme_system', Icons.brightness_auto),
            (ThemeMode.light, 'settings.theme_light', Icons.light_mode_outlined),
            (ThemeMode.dark, 'settings.theme_dark', Icons.dark_mode_outlined),
          ])
            RadioListTile<ThemeMode>(
              value: mode,
              activeColor: cs.primary,
              title: Text(
                labelKey.tr(),
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              secondary: Icon(icon, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
