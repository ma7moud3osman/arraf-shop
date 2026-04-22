import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';

/// Bottom-sheet detail view for a single calendar day. Shows check-in /
/// check-out times, worked minutes, and any late / early-leave deltas.
///
/// Push via `showModalBottomSheet(..., builder: (_) => AttendanceDaySheet(...))`.
class AttendanceDaySheet extends StatelessWidget {
  const AttendanceDaySheet({
    super.key,
    required this.day,
    required this.record,
  });

  final DateTime day;
  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              DateFormat.yMMMMEEEEd(context.locale.languageCode).format(day),
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            _StatusBadge(record: record),
            const SizedBox(height: 20),
            if (record == null)
              _EmptyDay(cs: cs, tt: tt)
            else ...[
              _TimelineRow(
                icon: Icons.login_rounded,
                color: cs.primary,
                title: 'attendance.sheet.checked_in'.tr(),
                time: record!.checkInAt,
                extraLabel:
                    record!.lateMinutes > 0
                        ? 'attendance.sheet.late_by'.tr(
                          namedArgs: {'mins': '${record!.lateMinutes}'},
                        )
                        : null,
                extraColor: cs.error,
              ),
              if (record!.checkOutAt != null)
                _TimelineRow(
                  icon: Icons.logout_rounded,
                  color: cs.tertiary,
                  title: 'attendance.sheet.checked_out'.tr(),
                  time: record!.checkOutAt,
                  extraLabel:
                      record!.earlyLeaveMinutes > 0
                          ? 'attendance.sheet.early_by'.tr(
                            namedArgs: {'mins': '${record!.earlyLeaveMinutes}'},
                          )
                          : null,
                  extraColor: cs.error,
                ),
              if (record!.workedMinutes != null)
                _FooterStat(
                  label: 'attendance.sheet.worked'.tr(),
                  value: _formatDuration(record!.workedMinutes!),
                  cs: cs,
                  tt: tt,
                ),
              if ((record!.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    record!.notes!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.record});
  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final (labelKey, color) = _styleFor(record, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelKey.tr(),
        style: tt.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  static (String, Color) _styleFor(AttendanceRecord? r, ColorScheme cs) {
    if (r == null) return ('attendance.status.absent', cs.error);
    return switch (r.status) {
      AttendanceStatus.present => (
        'attendance.status.present',
        Colors.green.shade600,
      ),
      AttendanceStatus.late => (
        'attendance.status.late',
        Colors.orange.shade700,
      ),
      AttendanceStatus.absent => ('attendance.status.absent', cs.error),
      AttendanceStatus.checkedOut => (
        'attendance.status.checked_out',
        cs.primary,
      ),
    };
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.time,
    this.extraLabel,
    this.extraColor,
  });

  final IconData icon;
  final Color color;
  final String title;
  final DateTime? time;
  final String? extraLabel;
  final Color? extraColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  time != null
                      ? DateFormat.Hms(
                        context.locale.languageCode,
                      ).format(time!.toLocal())
                      : '—',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (extraLabel != null)
            Text(
              extraLabel!,
              style: tt.labelSmall?.copyWith(
                color: extraColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.label,
    required this.value,
    required this.cs,
    required this.tt,
  });

  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'attendance.sheet.no_record'.tr(),
        textAlign: TextAlign.center,
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
