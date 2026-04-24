import 'package:arraf_shop/src/features/employees/domain/entities/month_calendar.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_attendance_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/widgets/attendance_day_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Calendar grid for one employee's month-to-date attendance.
///
/// * Header shows ◀ Month YYYY ▶ + summary chips (present / absent / late).
/// * Grid is 7 cols starting on Monday; each cell colored by status.
class EmployeeAttendanceTab extends StatefulWidget {
  const EmployeeAttendanceTab({super.key});

  @override
  State<EmployeeAttendanceTab> createState() => _EmployeeAttendanceTabState();
}

class _EmployeeAttendanceTabState extends State<EmployeeAttendanceTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<EmployeeAttendanceProvider>();
      if (provider.status == AppStatus.initial) provider.load();
    });
  }

  void _openDay(CalendarDay day) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EmployeeAttendanceDaySheet(day: day),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EmployeeAttendanceProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppSpacing.md),
        children: [
          _MonthSwitcher(provider: provider),
          SizedBox(height: AppSpacing.md),
          _BodyContent(provider: provider, onDayTap: _openDay),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({required this.provider});

  final EmployeeAttendanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    final label = DateFormat.yMMMM(
      context.locale.languageCode,
    ).format(provider.focusedMonth);
    final loading = provider.status == AppStatus.loading;

    return Row(
      children: [
        IconButton(
          tooltip: 'employees.attendance.previous_month'.tr(),
          icon: const Icon(Icons.chevron_left),
          onPressed: loading ? null : provider.previousMonth,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: 'employees.attendance.next_month'.tr(),
          icon: const Icon(Icons.chevron_right),
          onPressed: loading ? null : provider.nextMonth,
        ),
      ],
    );
  }
}

class _BodyContent extends StatelessWidget {
  const _BodyContent({required this.provider, required this.onDayTap});

  final EmployeeAttendanceProvider provider;
  final ValueChanged<CalendarDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        if (provider.calendar == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _Calendar(calendar: provider.calendar!, onDayTap: onDayTap);
      case AppStatus.failure:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: AppErrorWidget(
            title: 'employees.attendance.load_failed'.tr(),
            message: provider.errorMessage,
            onRetry: provider.refresh,
          ),
        );
      case AppStatus.success:
        return _Calendar(calendar: provider.calendar!, onDayTap: onDayTap);
    }
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.calendar, required this.onDayTap});

  final MonthCalendar calendar;
  final ValueChanged<CalendarDay> onDayTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    // Build the leading blank cells so the first row aligns with day-of-week.
    // ISO weekday: Monday=1 ... Sunday=7. We render Monday-first.
    final firstWeekday = calendar.firstDay.weekday; // 1..7
    final leadingBlanks = (firstWeekday - 1).clamp(0, 6);

    final weekdayLabels = _weekdayLabels(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryChips(calendar: calendar),
        SizedBox(height: AppSpacing.md),
        Row(
          children:
              weekdayLabels
                  .map(
                    (label) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        SizedBox(height: 4.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: calendar.days.length + leadingBlanks,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = calendar.days[index - leadingBlanks];
            return _DayCell(day: day, onTap: () => onDayTap(day));
          },
        ),
      ],
    );
  }

  List<String> _weekdayLabels(BuildContext context) {
    // Monday-first labels using the active locale.
    final base = DateTime(2024, 1, 1); // 2024-01-01 was a Monday.
    final fmt = DateFormat.E(context.locale.languageCode);
    return List.generate(7, (i) => fmt.format(base.add(Duration(days: i))));
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.calendar});

  final MonthCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final hours = (calendar.totalWorkedMinutes / 60).toStringAsFixed(1);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(
          label:
              '${calendar.presentDays} ${'employees.attendance.present'.tr()}',
          color: Colors.green.shade600,
        ),
        _Chip(
          label: '${calendar.absentDays} ${'employees.attendance.absent'.tr()}',
          color: cs.error,
        ),
        _Chip(
          label: '$hours ${'employees.attendance.hours_worked'.tr()}',
          color: cs.primary,
        ),
        if (calendar.totalLateMinutes > 0)
          _Chip(
            label:
                '${calendar.totalLateMinutes} ${'employees.attendance.late_minutes'.tr()}',
            color: Colors.orange.shade700,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.onTap});

  final CalendarDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final entry = day.attendance;

    final (bg, fg) = _colorsFor(entry?.status, cs);

    final isToday = _isSameDay(day.date, DateTime.now());

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: cs.primary, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.date.day}',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 13.sp,
            ),
          ),
        ),
      ),
    );
  }

  (Color, Color) _colorsFor(String? status, ColorScheme cs) {
    switch (status) {
      case 'present':
        return (Colors.green.withValues(alpha: 0.20), Colors.green.shade800);
      case 'late':
        return (Colors.orange.withValues(alpha: 0.22), Colors.orange.shade900);
      case 'checked_out':
        return (cs.primaryContainer, cs.onPrimaryContainer);
      case 'absent':
        return (cs.error.withValues(alpha: 0.10), cs.error);
      default:
        return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
