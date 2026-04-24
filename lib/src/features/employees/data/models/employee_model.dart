import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/employee.dart';

class EmployeeLatestPayrollModel extends EmployeeLatestPayroll {
  const EmployeeLatestPayrollModel({
    required super.id,
    required super.year,
    required super.month,
    required super.netSalary,
    required super.isPaid,
  });

  factory EmployeeLatestPayrollModel.fromJson(Map<String, dynamic> json) {
    return EmployeeLatestPayrollModel(
      id: parseInt(json['id']),
      year: parseInt(json['year']),
      month: parseInt(json['month']),
      netSalary: parseDouble(json['net_salary']),
      isPaid: (json['is_paid'] as bool?) ?? false,
    );
  }
}

class EmployeeModel extends Employee {
  const EmployeeModel({
    required super.id,
    required super.shopId,
    required super.name,
    required super.baseSalary,
    required super.isActive,
    required super.canLogin,
    super.code,
    super.phone,
    super.address,
    super.nationalId,
    super.role,
    super.avatarUrl,
    super.lastAttendanceDate,
    super.latestPayroll,
    super.createdAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar'];
    final rawDate = json['last_attendance_date'];
    final rawPayroll = json['latest_payroll'];

    return EmployeeModel(
      id: parseInt(json['id']),
      shopId: parseInt(json['shop_id']),
      name: (json['name'] as String?) ?? '',
      code: json['code']?.toString(),
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      nationalId: json['national_id'] as String?,
      role: json['role'] as String?,
      baseSalary: parseDouble(json['base_salary']),
      isActive: (json['is_active'] as bool?) ?? true,
      canLogin: (json['can_login'] as bool?) ?? false,
      avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
      lastAttendanceDate:
          rawDate is String && rawDate.isNotEmpty
              ? parseDateTime(rawDate)
              : null,
      latestPayroll:
          rawPayroll is Map
              ? EmployeeLatestPayrollModel.fromJson(
                Map<String, dynamic>.from(rawPayroll),
              )
              : null,
      createdAt: parseDateTime(json['created_at']),
    );
  }
}
