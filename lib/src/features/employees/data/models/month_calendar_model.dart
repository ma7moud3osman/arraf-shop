import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/month_calendar.dart';

class AttendanceEntryModel extends AttendanceEntry {
  const AttendanceEntryModel({
    required super.id,
    required super.date,
    required super.status,
    super.checkInAt,
    super.checkOutAt,
    super.workedMinutes,
    super.workedHours,
    super.lateMinutes,
    super.earlyLeaveMinutes,
    super.isManualOverride,
    super.notes,
  });

  factory AttendanceEntryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceEntryModel(
      id: parseInt(json['id']),
      date: parseDateTime(json['date']) ?? DateTime.now(),
      status: (json['status'] as String?) ?? 'present',
      checkInAt: parseDateTime(json['check_in_at']),
      checkOutAt: parseDateTime(json['check_out_at']),
      workedMinutes: parseIntOrNull(json['worked_minutes']),
      workedHours: parseDoubleOrNull(json['worked_hours']),
      lateMinutes: parseIntOrNull(json['late_minutes']) ?? 0,
      earlyLeaveMinutes: parseIntOrNull(json['early_leave_minutes']) ?? 0,
      isManualOverride: (json['is_manual_override'] as bool?) ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class CalendarDayModel extends CalendarDay {
  const CalendarDayModel({
    required super.date,
    required super.dayOfWeek,
    required super.hasAttendance,
    super.attendance,
  });

  factory CalendarDayModel.fromJson(Map<String, dynamic> json) {
    final att = json['attendance'];
    return CalendarDayModel(
      date: parseDateTime(json['date']) ?? DateTime.now(),
      dayOfWeek: parseInt(json['day_of_week']),
      hasAttendance: (json['has_attendance'] as bool?) ?? false,
      attendance:
          att is Map
              ? AttendanceEntryModel.fromJson(Map<String, dynamic>.from(att))
              : null,
    );
  }
}

class MonthCalendarModel extends MonthCalendar {
  const MonthCalendarModel({
    required super.year,
    required super.month,
    required super.daysInMonth,
    required super.presentDays,
    required super.absentDays,
    required super.totalWorkedMinutes,
    required super.totalLateMinutes,
    required super.days,
  });

  factory MonthCalendarModel.fromJson(Map<String, dynamic> json) {
    final raw = json['days'];
    final days =
        raw is List
            ? raw
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (m) =>
                      CalendarDayModel.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList(growable: false)
            : const <CalendarDay>[];

    return MonthCalendarModel(
      year: parseInt(json['year']),
      month: parseInt(json['month']),
      daysInMonth: parseInt(json['days_in_month']),
      presentDays: parseInt(json['present_days']),
      absentDays: parseInt(json['absent_days']),
      totalWorkedMinutes: parseInt(json['total_worked_minutes']),
      totalLateMinutes: parseInt(json['total_late_minutes']),
      days: days,
    );
  }
}
