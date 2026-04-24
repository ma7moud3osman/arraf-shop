import 'package:equatable/equatable.dart';

/// Compact summary of a payslip rendered next to an employee's row.
class EmployeeLatestPayroll extends Equatable {
  final int id;
  final int year;
  final int month;
  final double netSalary;
  final bool isPaid;

  const EmployeeLatestPayroll({
    required this.id,
    required this.year,
    required this.month,
    required this.netSalary,
    required this.isPaid,
  });

  DateTime get periodStart => DateTime(year, month, 1);

  @override
  List<Object?> get props => [id, year, month, netSalary, isPaid];
}

/// Shop employee as rendered on the admin Employees list.
///
/// Mirrors `ShopEmployeeAdminResource` from the backend; intentionally
/// omits long fields (e.g. `address`) that the list itself never shows.
class Employee extends Equatable {
  final int id;
  final int shopId;
  final String name;
  final String? code;
  final String? phone;
  final String? address;
  final String? nationalId;
  final String? role;
  final double baseSalary;
  final bool isActive;
  final bool canLogin;
  final String? avatarUrl;
  final DateTime? lastAttendanceDate;
  final EmployeeLatestPayroll? latestPayroll;
  final DateTime? createdAt;

  const Employee({
    required this.id,
    required this.shopId,
    required this.name,
    required this.baseSalary,
    required this.isActive,
    required this.canLogin,
    this.code,
    this.phone,
    this.address,
    this.nationalId,
    this.role,
    this.avatarUrl,
    this.lastAttendanceDate,
    this.latestPayroll,
    this.createdAt,
  });

  /// Two-letter initials used as the avatar fallback.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    String firstChar(String s) => s.isEmpty ? '' : s.substring(0, 1);
    if (parts.length == 1) return firstChar(parts.first).toUpperCase();
    return (firstChar(parts.first) + firstChar(parts.last)).toUpperCase();
  }

  /// Convenience constructor for tests / fakes.
  factory Employee.fake({
    int id = 1,
    String name = 'Sara Mostafa',
    String? role = 'Cashier',
    double baseSalary = 8000,
    bool isActive = true,
    DateTime? lastAttendanceDate,
    EmployeeLatestPayroll? latestPayroll,
  }) {
    return Employee(
      id: id,
      shopId: 1,
      name: name,
      code: 'EMP-$id',
      phone: '+201000000${id.toString().padLeft(3, '0')}',
      role: role,
      baseSalary: baseSalary,
      isActive: isActive,
      canLogin: true,
      lastAttendanceDate: lastAttendanceDate,
      latestPayroll: latestPayroll,
    );
  }

  @override
  List<Object?> get props => [
    id,
    shopId,
    name,
    code,
    phone,
    role,
    baseSalary,
    isActive,
    canLogin,
    avatarUrl,
    lastAttendanceDate,
    latestPayroll,
  ];
}
