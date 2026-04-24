import 'package:table_calendar/table_calendar.dart';

import '../../../../imports/imports.dart';
import '../../domain/entities/attendance_history.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';
import '../providers/attendance_history_provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_day_sheet.dart';

/// Employee attendance home: today's status + large check-in/out button,
/// then a calendar with colored dots for each day's record. Tap a day to
/// open the detail bottom sheet.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final today = context.read<AttendanceProvider>();
      if (today.status == AppStatus.initial) today.load();
      final history = context.read<AttendanceHistoryProvider>();
      if (history.status == AppStatus.initial) history.load();
    });
  }

  Future<void> _onCheckIn() async {
    final provider = context.read<AttendanceProvider>();
    final ok = await provider.checkIn();
    if (!mounted) return;
    if (ok) {
      showToast(
        context,
        message: 'attendance.toast.checked_in'.tr(),
        status: 'success',
      );
      context.read<AttendanceHistoryProvider>().load();
    } else {
      await _handleLocationFailure(
        provider,
        fallbackKey: 'attendance.toast.check_in_failed',
      );
    }
  }

  Future<void> _onCheckOut() async {
    final provider = context.read<AttendanceProvider>();
    final ok = await provider.checkOut();
    if (!mounted) return;
    if (ok) {
      showToast(
        context,
        message: 'attendance.toast.checked_out'.tr(),
        status: 'success',
      );
      context.read<AttendanceHistoryProvider>().load();
    } else {
      await _handleLocationFailure(
        provider,
        fallbackKey: 'attendance.toast.check_out_failed',
      );
    }
  }

  Future<void> _handleLocationFailure(
    AttendanceProvider provider, {
    required String fallbackKey,
  }) async {
    final message = provider.errorMessage ?? fallbackKey.tr();
    final kind = provider.locationError;

    // Services off → offer to open system Location Settings.
    // Permanently denied → offer to open App Settings (where the user can
    // re-grant the permission). Other cases are handled by a plain toast.
    if (kind == LocationErrorKind.servicesOff ||
        kind == LocationErrorKind.permissionPermanent) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text('attendance.errors.settings_dialog_title'.tr()),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('common.cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('attendance.errors.open_settings'.tr()),
                ),
              ],
            ),
      );
      if (openSettings ?? false) {
        if (kind == LocationErrorKind.servicesOff) {
          await provider.openLocationSettings();
        } else {
          await provider.openAppSettings();
        }
      }
      return;
    }

    showToast(context, message: message, status: 'error');
  }

  void _openDaySheet(DateTime day, AttendanceRecord? record) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      isScrollControlled: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AttendanceDaySheet(day: day, record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final history = context.watch<AttendanceHistoryProvider>();

    return Scaffold(
      appBar: AppTopBar(title: 'attendance.title'.tr()),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([provider.load(), history.load()]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _TodayCard(
              today: provider.today,
              status: provider.status,
              actionStatus: provider.actionStatus,
              canCheckIn: provider.canCheckIn,
              canCheckOut: provider.canCheckOut,
              onCheckIn: _onCheckIn,
              onCheckOut: _onCheckOut,
              onRetry: provider.load,
              errorMessage: provider.errorMessage,
            ),
            const SizedBox(height: 8),
            _CalendarCard(
              focusedMonth: history.focusedMonth,
              selectedDay: _selectedDay,
              calendarFormat: _calendarFormat,
              status: history.status,
              errorMessage: history.errorMessage,
              isCurrentMonth: history.isFocusedMonthCurrent,
              summary: history.history,
              recordForDay: history.recordForDay,
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                });
                _openDaySheet(selected, history.recordForDay(selected));
              },
              onPageChanged: (focused) {
                final firstOfFocused =
                    DateTime(focused.year, focused.month, 1);
                final firstOfCurrent = DateTime(
                  history.focusedMonth.year,
                  history.focusedMonth.month,
                  1,
                );
                final now = DateTime.now();
                final firstOfNow = DateTime(now.year, now.month, 1);
                // Block forward navigation past the present month (the
                // backend would just return an empty future-month payload).
                if (firstOfFocused.isAfter(firstOfCurrent) &&
                    firstOfFocused.isAfter(firstOfNow)) {
                  return;
                }
                history.changeMonth(focused);
              },
              onFormatChanged: (fmt) => setState(() => _calendarFormat = fmt),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.status,
    required this.actionStatus,
    required this.canCheckIn,
    required this.canCheckOut,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onRetry,
    required this.errorMessage,
  });

  final AttendanceRecord? today;
  final AppStatus status;
  final AppStatus actionStatus;
  final bool canCheckIn;
  final bool canCheckOut;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onRetry;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: switch (status) {
        AppStatus.initial ||
        AppStatus.loading => const SizedBox(height: 180, child: AppLoading()),
        AppStatus.failure => SizedBox(
          height: 200,
          child: AppErrorWidget(
            title: 'attendance.today.load_failed'.tr(),
            message: errorMessage,
            onRetry: onRetry,
          ),
        ),
        AppStatus.success => Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'attendance.today.title'.tr(),
              style: tt.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            _TodayTimeline(record: today, cs: cs, tt: tt),
            const SizedBox(height: 20),
            if (canCheckIn)
              AppButton(
                label: 'attendance.button.check_in'.tr(),
                onPressed: onCheckIn,
                isLoading: actionStatus == AppStatus.loading,
                variant: ButtonVariant.success,
                width: ButtonSize.large,
              )
            else if (canCheckOut)
              AppButton(
                label: 'attendance.button.check_out'.tr(),
                onPressed: onCheckOut,
                isLoading: actionStatus == AppStatus.loading,
                variant: ButtonVariant.primary,
                width: ButtonSize.large,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'attendance.today.done'.tr(),
                  style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      },
    );
  }
}

class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline({
    required this.record,
    required this.cs,
    required this.tt,
  });

  final AttendanceRecord? record;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final inTime = record?.checkInAt;
    final outTime = record?.checkOutAt;

    return Row(
      children: [
        Expanded(
          child: _Slot(
            label: 'attendance.today.in'.tr(),
            time: inTime,
            color: cs.primary,
            tt: tt,
            cs: cs,
            icon: Icons.login_rounded,
          ),
        ),
        Container(width: 1, height: 48, color: cs.outlineVariant),
        Expanded(
          child: _Slot(
            label: 'attendance.today.out'.tr(),
            time: outTime,
            color: cs.tertiary,
            tt: tt,
            cs: cs,
            icon: Icons.logout_rounded,
          ),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.time,
    required this.color,
    required this.tt,
    required this.cs,
    required this.icon,
  });

  final String label;
  final DateTime? time;
  final Color color;
  final TextTheme tt;
  final ColorScheme cs;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(
          time != null
              ? DateFormat.Hm(
                context.locale.languageCode,
              ).format(time!.toLocal())
              : '—',
          style: tt.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedMonth,
    required this.selectedDay,
    required this.calendarFormat,
    required this.status,
    required this.errorMessage,
    required this.isCurrentMonth,
    required this.summary,
    required this.recordForDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onFormatChanged,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final AppStatus status;
  final String? errorMessage;
  final bool isCurrentMonth;
  final AttendanceHistory? summary;
  final AttendanceRecord? Function(DateTime day) recordForDay;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<CalendarFormat> onFormatChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'attendance.history.title'.tr(),
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (summary != null) ...[
            _SummaryChips(summary: summary!),
            const SizedBox(height: 8),
          ],
          TableCalendar<AttendanceRecord>(
            firstDay: DateTime(DateTime.now().year - 2),
            // Clamp at the present month — the backend won't return useful
            // data for future months and the calendar shouldn't tease them.
            lastDay: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
            focusedDay: focusedMonth,
            selectedDayPredicate: (day) => isSameDay(day, selectedDay),
            calendarFormat: calendarFormat,
            availableCalendarFormats: {
              CalendarFormat.month: 'attendance.calendar.month'.tr(),
              CalendarFormat.twoWeeks: 'attendance.calendar.two_weeks'.tr(),
              CalendarFormat.week: 'attendance.calendar.week'.tr(),
            },
            eventLoader: (day) {
              final r = recordForDay(day);
              return r == null ? const [] : [r];
            },
            startingDayOfWeek: StartingDayOfWeek.saturday,
            locale: context.locale.languageCode,
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            onFormatChanged: onFormatChanged,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerDecoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              weekendTextStyle: TextStyle(color: cs.onSurface),
              outsideTextStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            calendarBuilders: CalendarBuilders<AttendanceRecord>(
              markerBuilder: (context, day, records) {
                if (records.isEmpty) return null;
                final r = records.first;
                final color = _dotColor(r.status, cs);
                return Positioned(
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 8),
          _Legend(cs: cs, tt: tt),
          if (status == AppStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          if (status == AppStatus.failure && errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                errorMessage!,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ),
        ],
      ),
    );
  }

  static Color _dotColor(AttendanceStatus s, ColorScheme cs) {
    return switch (s) {
      AttendanceStatus.present => Colors.green.shade600,
      AttendanceStatus.late => Colors.orange.shade700,
      AttendanceStatus.absent => cs.error,
      AttendanceStatus.checkedOut => cs.primary,
    };
  }
}

class _SummaryChips extends StatelessWidget {
  const _SummaryChips({required this.summary});

  final AttendanceHistory summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final workingTotal =
        summary.workingDaysSoFar > 0 ? summary.workingDaysSoFar : summary.workingDays;

    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          'attendance.summary.present_of_working'.tr(
            namedArgs: {
              'present': '${summary.presentDays}',
              'total': '$workingTotal',
            },
          ),
          Colors.green.shade600,
        ),
        if (summary.holidayDays > 0)
          chip(
            'attendance.summary.holidays'.tr(
              namedArgs: {'count': '${summary.holidayDays}'},
            ),
            cs.onSurfaceVariant,
          ),
        chip(
          'attendance.summary.absent'.tr(
            namedArgs: {'count': '${summary.absentDays}'},
          ),
          cs.error,
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(key.tr(), style: tt.labelSmall),
      ],
    );

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        dot(Colors.green.shade600, 'attendance.status.present'),
        dot(Colors.orange.shade700, 'attendance.status.late'),
        dot(cs.primary, 'attendance.status.checked_out'),
        dot(cs.error, 'attendance.status.absent'),
      ],
    );
  }
}
