import 'package:arraf_shop/src/features/attendance/domain/entities/attendance_record.dart';
import 'package:arraf_shop/src/features/attendance/domain/entities/attendance_status.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/employee_profile.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/month_calendar.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/employees/domain/repositories/employees_repository.dart';
import 'package:arraf_shop/src/features/payroll/domain/entities/payslip.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

/// In-memory fake of [EmployeesRepository] usable across provider tests.
///
/// Each method returns the value of its `*Handler` callback when set;
/// otherwise it returns a sensible default. Counters expose how often
/// each method ran so tests can assert call discipline (e.g. "no double
/// fetch") without wrapping the fake in mocktail.
class FakeEmployeesRepository implements EmployeesRepository {
  // ── Configurable handlers ───────────────────────────────────────────
  FutureEither<Paginated<Employee>> Function(
    int page,
    int perPage,
    String? search,
  )?
  listHandler;

  FutureEither<EmployeeProfile> Function(int id)? showHandler;

  FutureEither<MonthCalendar> Function(int id, int? year, int? month)?
  attendanceHandler;

  FutureEither<Paginated<Payslip>> Function(
    int id,
    int page,
    int perPage,
    int? year,
    int? month,
  )?
  payrollHandler;

  FutureEither<Paginated<Payslip>> Function(
    int page,
    int perPage,
    int? year,
    int? month,
  )?
  shopPayrollHandler;

  // ── Call counters / inspection ──────────────────────────────────────
  int listCalls = 0;
  int showCalls = 0;
  int attendanceCalls = 0;
  int payrollCalls = 0;
  int shopPayrollCalls = 0;

  String? lastSearch;
  int? lastListPage;
  int? lastAttendanceYear;
  int? lastAttendanceMonth;

  @override
  FutureEither<Paginated<Employee>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  }) {
    listCalls += 1;
    lastListPage = page;
    lastSearch = search;
    final h = listHandler;
    if (h != null) return h(page, perPage, search);
    return Future.value(
      Right(
        Paginated<Employee>(
          items: [
            Employee.fake(id: 1, name: 'Sara'),
            Employee.fake(id: 2, name: 'Omar'),
          ],
          currentPage: page,
          perPage: perPage,
          total: 2,
          lastPage: page,
        ),
      ),
    );
  }

  @override
  FutureEither<EmployeeProfile> show(int employeeId) {
    showCalls += 1;
    final h = showHandler;
    if (h != null) return h(employeeId);
    return Future.value(
      Right(EmployeeProfile(employee: Employee.fake(id: employeeId))),
    );
  }

  @override
  FutureEither<MonthCalendar> attendance(
    int employeeId, {
    int? year,
    int? month,
  }) {
    attendanceCalls += 1;
    lastAttendanceYear = year;
    lastAttendanceMonth = month;
    final h = attendanceHandler;
    if (h != null) return h(employeeId, year, month);
    return Future.value(
      Right(MonthCalendar.fake(year: year ?? 2026, month: month ?? 4)),
    );
  }

  @override
  FutureEither<Paginated<Payslip>> payroll(
    int employeeId, {
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) {
    payrollCalls += 1;
    final h = payrollHandler;
    if (h != null) return h(employeeId, page, perPage, year, month);
    return Future.value(Right(Paginated.empty<Payslip>()));
  }

  @override
  FutureEither<Paginated<Payslip>> shopPayroll({
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) {
    shopPayrollCalls += 1;
    final h = shopPayrollHandler;
    if (h != null) return h(page, perPage, year, month);
    return Future.value(Right(Paginated.empty<Payslip>()));
  }
}

/// Convenience: an [EmployeesRepository] that fails every call with the
/// same [Failure]. Useful for failure-path provider tests.
class FailingEmployeesRepository implements EmployeesRepository {
  FailingEmployeesRepository({this.failure = const ServerFailure('boom')});
  final Failure failure;

  @override
  FutureEither<Paginated<Employee>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  }) => Future.value(Left(failure));

  @override
  FutureEither<EmployeeProfile> show(int employeeId) =>
      Future.value(Left(failure));

  @override
  FutureEither<MonthCalendar> attendance(
    int employeeId, {
    int? year,
    int? month,
  }) => Future.value(Left(failure));

  @override
  FutureEither<Paginated<Payslip>> payroll(
    int employeeId, {
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) => Future.value(Left(failure));

  @override
  FutureEither<Paginated<Payslip>> shopPayroll({
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) => Future.value(Left(failure));
}

// ── Sample factories ──────────────────────────────────────────────────

Paginated<Employee> makePage({
  required int page,
  required int lastPage,
  int perPage = 20,
  List<Employee>? items,
  int? total,
}) {
  final list =
      items ??
      List<Employee>.generate(
        2,
        (i) => Employee.fake(id: page * 10 + i, name: 'Emp ${page}_$i'),
      );
  return Paginated<Employee>(
    items: list,
    currentPage: page,
    perPage: perPage,
    total: total ?? list.length,
    lastPage: lastPage,
  );
}

AttendanceRecord makeAttendanceRecord({
  int id = 1,
  int shopEmployeeId = 1,
  AttendanceStatus status = AttendanceStatus.present,
  DateTime? date,
}) {
  return AttendanceRecord(
    id: id,
    shopId: 1,
    shopEmployeeId: shopEmployeeId,
    date: date ?? DateTime(2026, 4, 24),
    status: status,
    workedMinutes: 480,
  );
}
