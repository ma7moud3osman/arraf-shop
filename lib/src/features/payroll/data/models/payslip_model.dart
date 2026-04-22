import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/payslip.dart';

class PayslipModel extends Payslip {
  const PayslipModel({
    required super.id,
    required super.year,
    required super.month,
    required super.baseSalary,
    required super.totalIncentives,
    required super.totalDeductions,
    required super.netSalary,
    required super.workingDays,
    required super.absentDays,
    required super.totalLateMinutes,
    required super.totalEarlyLeaveMinutes,
    required super.isLocked,
    required super.isPaid,
    super.generatedAt,
    super.lockedAt,
    super.paidAt,
    super.pdfUrl,
    super.adjustments,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final rawAdj = json['adjustments'];
    final adjustments = rawAdj is List
        ? rawAdj.whereType<Map<dynamic, dynamic>>().map((m) {
            final a = Map<String, dynamic>.from(m);
            return PayslipAdjustment(
              id: parseInt(a['id']),
              type: (a['type'] as String?) ?? 'deduction',
              reason: (a['reason'] as String?) ?? '',
              amount: parseDouble(a['amount']),
            );
          }).toList()
        : const <PayslipAdjustment>[];

    return PayslipModel(
      id: parseInt(json['id']),
      year: parseInt(json['year']),
      month: parseInt(json['month']),
      baseSalary: parseDouble(json['base_salary']),
      totalIncentives: parseDouble(json['total_incentives']),
      totalDeductions: parseDouble(json['total_deductions']),
      netSalary: parseDouble(json['net_salary']),
      workingDays: parseInt(json['working_days']),
      absentDays: parseInt(json['absent_days']),
      totalLateMinutes: parseInt(json['total_late_minutes']),
      totalEarlyLeaveMinutes: parseInt(json['total_early_leave_minutes']),
      isLocked: (json['is_locked'] as bool?) ?? false,
      isPaid: (json['is_paid'] as bool?) ?? false,
      generatedAt: parseDateTime(json['generated_at']),
      lockedAt: parseDateTime(json['locked_at']),
      paidAt: parseDateTime(json['paid_at']),
      pdfUrl: json['pdf_url'] as String?,
      adjustments: adjustments,
    );
  }
}
