import 'package:equatable/equatable.dart';

import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../payroll/domain/entities/payslip.dart';
import 'employee.dart';

/// Detail bundle returned by `GET /api/shops/my/employees/{id}`.
class EmployeeProfile extends Equatable {
  final Employee employee;
  final List<AttendanceRecord> recentAttendance;
  final List<Payslip> recentPayroll;

  const EmployeeProfile({
    required this.employee,
    this.recentAttendance = const [],
    this.recentPayroll = const [],
  });

  @override
  List<Object?> get props => [employee, recentAttendance, recentPayroll];
}
