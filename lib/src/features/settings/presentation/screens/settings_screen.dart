import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

import '../providers/settings_provider.dart';
import '../widgets/working_week_section.dart';

/// User preferences grouped as cards: account summary, language, theme,
/// and a destructive sign-out tile. All changes persist immediately.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(title: 'settings.title'.tr()),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            const _AccountCard(),
            const _SectionGap(),
            const _SectionLabel(labelKey: 'settings.preferences'),
            const _SectionTitleGap(),
            const _SettingsGroup(
              children: [_LanguageTile(), _GroupDivider(), _ThemeTile()],
            ),
            if (isAdmin) ...[
              const _SectionGap(),
              const _SectionLabel(labelKey: 'settings.working_week.title'),
              const _SectionTitleGap(),
              const WorkingWeekSection(),
            ],
            const _SectionGap(),
            const _SignOutTile(),
          ],
        ),
      ),
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();
  @override
  Widget build(BuildContext context) => SizedBox(height: AppSpacing.lg);
}

class _SectionTitleGap extends StatelessWidget {
  const _SectionTitleGap();
  @override
  Widget build(BuildContext context) => SizedBox(height: AppSpacing.sm);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.labelKey});
  final String labelKey;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.xs),
      child: Text(
        labelKey.tr().toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 11.sp,
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final session = context.watch<AuthProvider>();
    final user = session.user;
    final employee = session.employee;
    final isEmployee = employee != null;

    final name = user?.name ?? employee?.name ?? '—';
    final subtitle = user?.email ?? employee?.code ?? '';
    final initials = _initialsFor(name);

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: tt.titleMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    fontSize: 15.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.sp,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          _RolePill(isEmployee: isEmployee),
        ],
      ),
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.firstOrNull ?? '';
    final second =
        parts.length > 1
            ? (parts.elementAt(1).characters.firstOrNull ?? '')
            : '';
    return '$first$second'.toUpperCase();
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.isEmployee});
  final bool isEmployee;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        (isEmployee ? 'home.role_employee' : 'home.role_owner').tr(),
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10.sp,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: context.theme.colorScheme.outlineVariant,
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final currentCode =
        settings.locale?.languageCode ?? context.locale.languageCode;
    final cs = context.theme.colorScheme;

    return _SettingRow(
      leading: HugeIcon(
        icon: HugeIcons.strokeRoundedGlobe02,
        color: cs.primary,
        size: 20.sp,
      ),
      titleKey: 'settings.language',
      onTap: () => _showLanguageSheet(context, currentCode),
      trailing: Text(
        _nameFor(currentCode),
        style: context.theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showLanguageSheet(BuildContext context, String current) async {
    final cs = context.theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (sheetContext) => _LanguageSheet(currentCode: current),
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

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.currentCode});
  final String currentCode;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2.r),
              ),
              margin: EdgeInsets.only(bottom: AppSpacing.md),
            ),
            Center(
              child: Text(
                'settings.language'.tr(),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            for (final locale in context.supportedLocales)
              _LanguageOption(
                code: locale.languageCode,
                isSelected: locale.languageCode == currentCode,
                onTap: () async {
                  await settings.setLocale(locale);
                  if (!context.mounted) return;
                  await context.setLocale(locale);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? cs.primary.withValues(alpha: 0.1)
                    : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameFor(code),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      code.toUpperCase(),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: cs.primary,
                  size: 22.sp,
                ),
            ],
          ),
        ),
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

class _ThemeTile extends StatelessWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = context.theme.colorScheme;
    final currentMode = settings.themeMode;

    return _SettingRow(
      leading: HugeIcon(
        icon: _iconFor(currentMode),
        color: cs.primary,
        size: 20.sp,
      ),
      titleKey: 'settings.theme',
      onTap: () => _showThemeSheet(context, currentMode),
      trailing: Text(
        _labelFor(currentMode).tr(),
        style: context.theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  List<List<dynamic>> _iconFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => HugeIcons.strokeRoundedSun03,
      ThemeMode.dark => HugeIcons.strokeRoundedMoon02,
      ThemeMode.system => HugeIcons.strokeRoundedSmartPhone01,
    };
  }

  String _labelFor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'settings.theme_light',
      ThemeMode.dark => 'settings.theme_dark',
      ThemeMode.system => 'settings.theme_system',
    };
  }

  Future<void> _showThemeSheet(BuildContext context, ThemeMode current) async {
    final cs = context.theme.colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => _ThemeSheet(current: current),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});
  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2.r),
              ),
              margin: EdgeInsets.only(bottom: AppSpacing.md),
            ),
            Center(
              child: Text(
                'settings.theme'.tr(),
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            for (final entry in const [
              (
                ThemeMode.system,
                'settings.theme_system',
                HugeIcons.strokeRoundedSmartPhone01,
              ),
              (
                ThemeMode.light,
                'settings.theme_light',
                HugeIcons.strokeRoundedSun03,
              ),
              (
                ThemeMode.dark,
                'settings.theme_dark',
                HugeIcons.strokeRoundedMoon02,
              ),
            ])
              _ThemeOption(
                mode: entry.$1,
                labelKey: entry.$2,
                icon: entry.$3,
                isSelected: entry.$1 == current,
                onTap: () {
                  context.read<SettingsProvider>().setThemeMode(entry.$1);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.labelKey,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode mode;
  final String labelKey;
  final List<List<dynamic>> icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? cs.primary.withValues(alpha: 0.1)
                    : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                size: 22.sp,
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  labelKey.tr(),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: cs.primary,
                  size: 22.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.leading,
    required this.titleKey,
    this.trailing,
    required this.onTap,
  });

  final Widget leading;
  final String titleKey;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.ms,
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              alignment: Alignment.center,
              child: leading,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                titleKey.tr(),
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              SizedBox(width: AppSpacing.sm),
            ],
            Transform.flip(
              flipX: context.locale.languageCode == 'ar',
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: cs.onSurfaceVariant,
                size: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignOutTile extends StatelessWidget {
  const _SignOutTile();

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final session = context.watch<AuthProvider>();
    final isEmployee = session.employee != null;
    final isLoggingOut = session.isLoggingOut;

    return Material(
      color: cs.errorContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap:
            isLoggingOut
                ? null
                : () => _confirmAndLogout(context, isEmployee: isEmployee),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: cs.error.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLogout01,
                    color: cs.error,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'settings.sign_out'.tr(),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.error,
                    ),
                  ),
                ),
                if (isLoggingOut)
                  SizedBox(
                    width: 18.sp,
                    height: 18.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(cs.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(
    BuildContext context, {
    required bool isEmployee,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = ctx.theme.colorScheme;
        final tt = ctx.theme.textTheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text(
            'settings.sign_out_confirm_title'.tr(),
            style: tt.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'settings.sign_out_confirm_body'.tr(),
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'common.cancel'.tr(),
                style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('settings.sign_out_confirm_action'.tr()),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true) return;

    context.read<AuthProvider>().logout(context: context);
  }
}
