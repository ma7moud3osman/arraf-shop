import 'package:equatable/equatable.dart';

import 'attendance_record.dart';

/// Bundles the self-attendance month payload: the records list plus the
/// summary fields the backend computes (working days, holidays, etc.).
class AttendanceHistory extends Equatable {
  final int year;
  final int month;
  final int daysInMonth;
  final bool isCurrentMonth;
  final bool isFutureMonth;
  final int workingDays;
  final int workingDaysSoFar;
  final int holidayDays;
  final int presentDays;
  final int absentDays;
  final int totalWorkedMinutes;
  final int totalLateMinutes;
  final List<AttendanceRecord> records;

  const AttendanceHistory({
    required this.year,
    required this.month,
    this.daysInMonth = 0,
    this.isCurrentMonth = false,
    this.isFutureMonth = false,
    this.workingDays = 0,
    this.workingDaysSoFar = 0,
    this.holidayDays = 0,
    this.presentDays = 0,
    this.absentDays = 0,
    this.totalWorkedMinutes = 0,
    this.totalLateMinutes = 0,
    this.records = const [],
  });

  AttendanceHistory copyWith({List<AttendanceRecord>? records}) {
    return AttendanceHistory(
      year: year,
      month: month,
      daysInMonth: daysInMonth,
      isCurrentMonth: isCurrentMonth,
      isFutureMonth: isFutureMonth,
      workingDays: workingDays,
      workingDaysSoFar: workingDaysSoFar,
      holidayDays: holidayDays,
      presentDays: presentDays,
      absentDays: absentDays,
      totalWorkedMinutes: totalWorkedMinutes,
      totalLateMinutes: totalLateMinutes,
      records: records ?? this.records,
    );
  }

  @override
  List<Object?> get props => [
    year,
    month,
    daysInMonth,
    isCurrentMonth,
    isFutureMonth,
    workingDays,
    workingDaysSoFar,
    holidayDays,
    presentDays,
    absentDays,
    totalWorkedMinutes,
    totalLateMinutes,
    records,
  ];
}
