import '../../../../utils/typedefs.dart';
import '../../../payroll/domain/entities/payslip.dart';
import '../entities/employee.dart';
import '../entities/employee_profile.dart';
import '../entities/month_calendar.dart';
import '../entities/paginated.dart';

/// Owner-facing employee admin API.
///
/// All endpoints live under `/api/shops/my/...` and require an authenticated
/// owner session. Failures (401/403/404/422) are surfaced via the standard
/// [Failure] hierarchy from `data/employees_failures.dart`.
abstract class EmployeesRepository {
  /// `GET /api/shops/my/employees` — paginated.
  FutureEither<Paginated<Employee>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  });

  /// `GET /api/shops/my/employees/{id}`.
  FutureEither<EmployeeProfile> show(int employeeId);

  /// `GET /api/shops/my/employees/{id}/attendance` — month calendar.
  /// Backend defaults to current year/month if both are omitted.
  FutureEither<MonthCalendar> attendance(
    int employeeId, {
    int? year,
    int? month,
  });

  /// `GET /api/shops/my/employees/{id}/payroll` — paginated payslips.
  FutureEither<Paginated<Payslip>> payroll(
    int employeeId, {
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  });

  /// `GET /api/shops/my/payroll` — shop-wide paginated payslips.
  /// Carried here for completeness; UI consumption is optional.
  FutureEither<Paginated<Payslip>> shopPayroll({
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  });
}
