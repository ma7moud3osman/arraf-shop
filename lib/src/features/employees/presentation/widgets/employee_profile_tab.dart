import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/employee_profile.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_detail_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class EmployeeProfileTab extends StatelessWidget {
  const EmployeeProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeDetailProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: switch (provider.status) {
        AppStatus.initial || AppStatus.loading => const _LoadingList(),
        AppStatus.failure => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppErrorWidget(
              title: 'employees.detail.load_failed'.tr(),
              message: provider.errorMessage,
              onRetry: provider.refresh,
            ),
          ],
        ),
        AppStatus.success => _ProfileBody(profile: provider.profile!),
      },
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final emp = profile.employee;
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _Header(employee: emp),
        SizedBox(height: AppSpacing.md),
        _SummarySection(profile: profile),
        SizedBox(height: AppSpacing.md),
        Text(
          'employees.profile.contact'.tr(),
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        _InfoRow(
          icon: HugeIcons.strokeRoundedCall02,
          label: 'employees.profile.phone'.tr(),
          value: emp.phone ?? '—',
        ),
        _InfoRow(
          icon: HugeIcons.strokeRoundedIdentification,
          label: 'employees.profile.code'.tr(),
          value: emp.code ?? '—',
        ),
        _InfoRow(
          icon: HugeIcons.strokeRoundedLocation01,
          label: 'employees.profile.address'.tr(),
          value: emp.address ?? '—',
        ),
        _InfoRow(
          icon: HugeIcons.strokeRoundedUserSquare,
          label: 'employees.profile.national_id'.tr(),
          value: emp.nationalId ?? '—',
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    final size = 80.w;

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
            image:
                employee.avatarUrl != null
                    ? DecorationImage(
                      image: CachedNetworkImageProvider(employee.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                    : null,
          ),
          alignment: Alignment.center,
          child:
              employee.avatarUrl != null
                  ? null
                  : Text(
                    employee.initials,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 28.sp,
                    ),
                  ),
        ),
        SizedBox(height: AppSpacing.sm),
        Text(
          employee.name,
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        if (employee.role != null && employee.role!.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            employee.role!,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.profile});

  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final emp = profile.employee;
    final cs = context.theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            color: cs.primaryContainer,
            valueColor: cs.onPrimaryContainer,
            label: 'employees.profile.base_salary'.tr(),
            value: emp.baseSalary.toStringAsFixed(2),
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            color: cs.secondaryContainer,
            valueColor: cs.onSecondaryContainer,
            label: 'employees.profile.recent_attendance'.tr(),
            value: '${profile.recentAttendance.length}',
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            color: cs.tertiaryContainer,
            valueColor: cs.onTertiaryContainer,
            label: 'employees.profile.recent_payslips'.tr(),
            value: '${profile.recentPayroll.length}',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.color,
    required this.valueColor,
    required this.label,
    required this.value,
  });

  final Color color;
  final Color valueColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: valueColor.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final List<List<dynamic>> icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: cs.onSurfaceVariant, size: 18.sp),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(value, style: tt.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
