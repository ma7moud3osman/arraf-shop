import 'package:equatable/equatable.dart';

class PayslipAdjustment extends Equatable {
  final int id;
  final String type; // 'incentive' | 'deduction'
  final String reason;
  final double amount;

  const PayslipAdjustment({
    required this.id,
    required this.type,
    required this.reason,
    required this.amount,
  });

  bool get isIncentive => type == 'incentive';

  @override
  List<Object?> get props => [id];
}

class Payslip extends Equatable {
  final int id;
  final int year;
  final int month;
  final double baseSalary;
  final double totalIncentives;
  final double totalDeductions;
  final double netSalary;
  final int workingDays;
  final int absentDays;
  final int totalLateMinutes;
  final int totalEarlyLeaveMinutes;
  final bool isLocked;
  final bool isPaid;
  final DateTime? generatedAt;
  final DateTime? lockedAt;
  final DateTime? paidAt;
  final String? pdfUrl;
  final List<PayslipAdjustment> adjustments;

  const Payslip({
    required this.id,
    required this.year,
    required this.month,
    required this.baseSalary,
    required this.totalIncentives,
    required this.totalDeductions,
    required this.netSalary,
    required this.workingDays,
    required this.absentDays,
    required this.totalLateMinutes,
    required this.totalEarlyLeaveMinutes,
    required this.isLocked,
    required this.isPaid,
    this.generatedAt,
    this.lockedAt,
    this.paidAt,
    this.pdfUrl,
    this.adjustments = const [],
  });

  DateTime get periodStart => DateTime(year, month, 1);

  String get statusKey {
    if (isPaid) return 'payroll.status.paid';
    if (isLocked) return 'payroll.status.locked';
    return 'payroll.status.draft';
  }

  @override
  List<Object?> get props => [id, year, month, isPaid, isLocked, netSalary];
}
