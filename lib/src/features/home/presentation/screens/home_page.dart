import 'package:arraf_shop/src/features/auth/presentation/providers/employee_auth_provider.dart';
import 'package:arraf_shop/src/features/auth/presentation/providers/session_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final session = context.watch<SessionProvider>();
    final employeeAuth = context.watch<EmployeeAuthProvider>();
    final user = session.user;
    final employee = employeeAuth.employee;

    // Resolve display name + whether the logged-in actor is an employee.
    final displayName = user?.name ?? employee?.name;
    final subtitle = user?.email ?? employee?.code;
    final isEmployee = employee != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppTopBar(
        title: 'home.home_title'.tr(),
        actions: [
          IconButton(
            tooltip: 'settings.title'.tr(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings02,
              color: colorScheme.onSurface,
              size: 22.sp,
            ),
            onPressed: () => context.push(AppRoutes.settings),
          ),
          IconButton(
            tooltip: 'home.sign_out'.tr(),
            icon:
                (isEmployee ? employeeAuth.isLoggingOut : session.isLoggingOut)
                    ? SizedBox(
                      width: 22.sp,
                      height: 22.sp,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          colorScheme.onSurface,
                        ),
                      ),
                    )
                    : HugeIcon(
                      icon: HugeIcons.strokeRoundedLogout01,
                      color: colorScheme.onSurface,
                      size: 22.sp,
                    ),
            onPressed:
                (isEmployee ? employeeAuth.isLoggingOut : session.isLoggingOut)
                    ? null
                    : () {
                      if (isEmployee) {
                        employeeAuth.logout(context: context);
                      } else {
                        session.logout();
                      }
                    },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: AppSpacing.lg.h),
              Text(
                displayName != null
                    ? 'home.welcome_named'.tr(namedArgs: {'name': displayName})
                    : 'home.welcome_home'.tr(),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  fontSize: 26.sp,
                ),
              ),
              SizedBox(height: AppSpacing.xs.h),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13.sp,
                  ),
                ),
              SizedBox(height: AppSpacing.xxl.h),

              // Employee view: attendance + payslips. Owner view: audits.
              if (isEmployee) ...[
                _FeatureCard(
                  icon: HugeIcons.strokeRoundedFingerPrintCheck,
                  title: 'attendance.title'.tr(),
                  subtitle: 'home.attendance_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.attendance),
                ),
                SizedBox(height: AppSpacing.md.h),
                _FeatureCard(
                  icon: HugeIcons.strokeRoundedInvoice03,
                  title: 'payroll.title'.tr(),
                  subtitle: 'home.payslips_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.payslips),
                ),
                SizedBox(height: AppSpacing.md.h),
                _FeatureCard(
                  icon: HugeIcons.strokeRoundedClipboard,
                  title: 'audits.list.title'.tr(),
                  subtitle: 'home.audits_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.audits),
                ),
              ] else ...[
                _FeatureCard(
                  icon: HugeIcons.strokeRoundedClipboard,
                  title: 'audits.list.title'.tr(),
                  subtitle: 'home.audits_subtitle'.tr(),
                  onTap: () => context.push(AppRoutes.audits),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Material(
      color: cs.primaryContainer,
      borderRadius: BorderRadius.circular(20.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: HugeIcon(icon: icon, color: cs.onPrimary, size: 28.sp),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.flip(
                flipX: context.locale.languageCode == 'ar',
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  size: 20.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
