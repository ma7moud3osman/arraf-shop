import 'package:equatable/equatable.dart';

/// Lightweight attendance entry for the calendar grid. Mirrors the `attendance`
/// payload returned inside each day of the calendar response.
///
/// Distinct from the employee-self `AttendanceRecord` in `features/attendance`
/// because this admin-facing shape is trimmed (no shop_id / lat / lng).
class AttendanceEntry extends Equatable {
  final int id;
  final DateTime date;
  final String status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? workedMinutes;
  final double? workedHours;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final bool isManualOverride;
  final String? notes;

  const AttendanceEntry({
    required this.id,
    required this.date,
    required this.status,
    this.checkInAt,
    this.checkOutAt,
    this.workedMinutes,
    this.workedHours,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.isManualOverride = false,
    this.notes,
  });

  bool get isPresent => status == 'present';
  bool get isLate => status == 'late';
  bool get isAbsent => status == 'absent';
  bool get isCheckedOut => status == 'checked_out';

  @override
  List<Object?> get props => [id, date, status, checkInAt, checkOutAt];
}

class CalendarDay extends Equatable {
  final DateTime date;
  final int dayOfWeek;
  final bool hasAttendance;
  final AttendanceEntry? attendance;

  const CalendarDay({
    required this.date,
    required this.dayOfWeek,
    required this.hasAttendance,
    this.attendance,
  });

  @override
  List<Object?> get props => [date, dayOfWeek, hasAttendance, attendance];
}

class MonthCalendar extends Equatable {
  final int year;
  final int month;
  final int daysInMonth;
  final int presentDays;
  final int absentDays;
  final int totalWorkedMinutes;
  final int totalLateMinutes;
  final List<CalendarDay> days;

  const MonthCalendar({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.presentDays,
    required this.absentDays,
    required this.totalWorkedMinutes,
    required this.totalLateMinutes,
    required this.days,
  });

  DateTime get firstDay => DateTime(year, month, 1);

  /// Convenience constructor for tests / fakes.
  factory MonthCalendar.fake({int year = 2026, int month = 4}) {
    final start = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final days = List<CalendarDay>.generate(daysInMonth, (i) {
      final date = start.add(Duration(days: i));
      return CalendarDay(
        date: date,
        dayOfWeek: date.weekday,
        hasAttendance: false,
      );
    });
    return MonthCalendar(
      year: year,
      month: month,
      daysInMonth: daysInMonth,
      presentDays: 0,
      absentDays: daysInMonth,
      totalWorkedMinutes: 0,
      totalLateMinutes: 0,
      days: days,
    );
  }

  @override
  List<Object?> get props => [
    year,
    month,
    daysInMonth,
    presentDays,
    absentDays,
    totalWorkedMinutes,
    totalLateMinutes,
    days,
  ];
}
