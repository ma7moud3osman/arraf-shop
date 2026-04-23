import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Admin-only Employees tab. Backend endpoints aren't wired up yet, so this
/// renders a polished "coming soon" state that previews the intended layout:
/// search bar + add action + list surface.
class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(
        title: 'employees.title'.tr(),
        actions: [
          IconButton(
            tooltip: 'employees.add'.tr(),
            onPressed: null, // enabled once the feature is wired up
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedUserAdd02,
              color: cs.onSurface.withValues(alpha: 0.4),
              size: 22.sp,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _EmployeesSearchField(),
              SizedBox(height: AppSpacing.md),
              const Expanded(child: _EmployeesComingSoon()),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeesSearchField extends StatelessWidget {
  const _EmployeesSearchField();

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.ms,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: cs.onSurfaceVariant,
            size: 18.sp,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'employees.search_hint'.tr(),
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeesComingSoon extends StatelessWidget {
  const _EmployeesComingSoon();

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88.w,
              height: 88.w,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUserGroup,
                color: cs.onPrimaryContainer,
                size: 40.sp,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              'employees.coming_soon_title'.tr(),
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'employees.coming_soon_subtitle'.tr(),
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
