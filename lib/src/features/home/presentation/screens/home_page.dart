import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    final session = context.watch<AuthProvider>();
    final user = session.user;
    final employee = session.employee;

    final displayName = user?.name ?? employee?.name;
    final subtitle = user?.email ?? employee?.code;
    final isEmployee = employee != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(
        title: 'home.home_title'.tr(),
        actions: const [_HomeAppBarSpacer()],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _GreetingHeader(
              displayName: displayName,
              subtitle: subtitle,
              isEmployee: isEmployee,
            ),
            SizedBox(height: AppSpacing.xl),
            _SectionLabel(label: 'home.quick_actions'.tr()),
            SizedBox(height: AppSpacing.ms),
            if (isEmployee) ...[
              _FeatureCard(
                icon: HugeIcons.strokeRoundedFingerPrintCheck,
                titleKey: 'attendance.title',
                subtitleKey: 'home.attendance_subtitle',
                onTap: () => context.go(AppRoutes.attendance),
              ),
              const _FeatureCardGap(),
              _FeatureCard(
                icon: HugeIcons.strokeRoundedInvoice03,
                titleKey: 'payroll.title',
                subtitleKey: 'home.payslips_subtitle',
                onTap: () => context.push(AppRoutes.payslips),
              ),
              const _FeatureCardGap(),
              _FeatureCard(
                icon: HugeIcons.strokeRoundedClipboard,
                titleKey: 'audits.list.title',
                subtitleKey: 'home.audits_subtitle',
                onTap: () => context.go(AppRoutes.audits),
              ),
            ] else ...[
              _FeatureCard(
                icon: HugeIcons.strokeRoundedClipboard,
                titleKey: 'audits.list.title',
                subtitleKey: 'home.audits_subtitle',
                onTap: () => context.go(AppRoutes.audits),
              ),
              const _FeatureCardGap(),
              _FeatureCard(
                icon: HugeIcons.strokeRoundedUserGroup,
                titleKey: 'employees.title',
                subtitleKey: 'home.employees_subtitle',
                onTap: () => context.go(AppRoutes.employees),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeAppBarSpacer extends StatelessWidget {
  const _HomeAppBarSpacer();

  // Reserves leading-end padding so the title stays visually centered; keeps
  // the top bar ready for future actions without shifting the title later.
  @override
  Widget build(BuildContext context) => SizedBox(width: AppSpacing.md);
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.displayName,
    required this.subtitle,
    required this.isEmployee,
  });

  final String? displayName;
  final String? subtitle;
  final bool isEmployee;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.primary.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _greetingKey().tr(),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                  ),
                ),
              ),
              _RoleBadge(isEmployee: isEmployee),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            displayName != null
                ? 'home.welcome_named'.tr(namedArgs: {'name': displayName!})
                : 'home.welcome_home'.tr(),
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onPrimary,
              fontSize: 24.sp,
              height: 1.2,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.85),
                fontSize: 12.sp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _greetingKey() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'home.greeting_morning';
    if (hour < 17) return 'home.greeting_afternoon';
    return 'home.greeting_evening';
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isEmployee});
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
        color: cs.onPrimary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        (isEmployee ? 'home.role_employee' : 'home.role_owner').tr(),
        style: tt.labelSmall?.copyWith(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontSize: 10.sp,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        fontSize: 11.sp,
      ),
    );
  }
}

class _FeatureCardGap extends StatelessWidget {
  const _FeatureCardGap();

  @override
  Widget build(BuildContext context) => SizedBox(height: AppSpacing.sm);
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String titleKey;
  final String subtitleKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: icon,
                    color: cs.onPrimaryContainer,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleKey.tr(),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          fontSize: 15.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitleKey.tr(),
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.sp,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Transform.flip(
                  flipX: context.locale.languageCode == 'ar',
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    color: cs.onSurfaceVariant,
                    size: 18.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
