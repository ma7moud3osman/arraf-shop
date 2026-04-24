import 'package:arraf_shop/src/features/employees/domain/entities/month_calendar.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Bottom sheet detailing one day's attendance entry. Used from the
/// employee-attendance calendar grid.
class EmployeeAttendanceDaySheet extends StatelessWidget {
  const EmployeeAttendanceDaySheet({super.key, required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    final entry = day.attendance;
    final dateLabel = DateFormat.yMMMMEEEEd(
      context.locale.languageCode,
    ).format(day.date);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            dateLabel,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: AppSpacing.md),
          if (day.isHoliday) ...[
            Text(
              'attendance.weekly_holiday'.tr(),
              style: tt.titleSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (entry == null) ...[
            Text(
              'employees.attendance.no_record'.tr(),
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else ...[
            _StatusRow(status: entry.status),
            SizedBox(height: AppSpacing.md),
            _TimeRow(
              icon: HugeIcons.strokeRoundedLogin01,
              label: 'employees.attendance.check_in'.tr(),
              value: _formatTime(context, entry.checkInAt),
            ),
            _TimeRow(
              icon: HugeIcons.strokeRoundedLogout01,
              label: 'employees.attendance.check_out'.tr(),
              value: _formatTime(context, entry.checkOutAt),
            ),
            if (entry.workedMinutes != null)
              _TimeRow(
                icon: HugeIcons.strokeRoundedClock01,
                label: 'employees.attendance.worked'.tr(),
                value: _formatDuration(entry.workedMinutes!),
              ),
            if (entry.lateMinutes > 0)
              _TimeRow(
                icon: HugeIcons.strokeRoundedAlert02,
                label: 'employees.attendance.late_by'.tr(),
                value: _formatDuration(entry.lateMinutes),
              ),
            if (entry.earlyLeaveMinutes > 0)
              _TimeRow(
                icon: HugeIcons.strokeRoundedAlert02,
                label: 'employees.attendance.early_leave_by'.tr(),
                value: _formatDuration(entry.earlyLeaveMinutes),
              ),
            if (entry.isManualOverride) ...[
              SizedBox(height: AppSpacing.sm),
              Text(
                'employees.attendance.manual_override'.tr(),
                style: tt.labelSmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.md),
              Text(
                'employees.attendance.notes'.tr(),
                style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: 4.h),
              Text(entry.notes!, style: tt.bodyMedium),
            ],
          ],
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat.jm(context.locale.languageCode).format(dt);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'present' => Colors.green.shade700,
      'late' => Colors.orange.shade700,
      'checked_out' => context.theme.colorScheme.primary,
      'absent' => context.theme.colorScheme.error,
      _ => context.theme.colorScheme.onSurfaceVariant,
    };
    final labelKey = 'employees.attendance.status.$status';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelKey.tr(),
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
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
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
