import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/employee_profile.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/month_calendar.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/employees/domain/repositories/employees_repository.dart';
import 'package:arraf_shop/src/features/payroll/domain/entities/payslip.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

/// Programmable fake repository for the employees feature. Slot-based:
/// override the matching `*Handler` to inject the response for a test.
class FakeEmployeesRepository implements EmployeesRepository {
  FutureEither<Paginated<Employee>> Function({
    int page,
    int perPage,
    String? search,
  })?
  listHandler;

  int listCalls = 0;
  String? lastSearch;
  int? lastPerPage;

  @override
  FutureEither<Paginated<Employee>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  }) {
    listCalls += 1;
    lastSearch = search;
    lastPerPage = perPage;
    final h = listHandler;
    if (h != null) return h(page: page, perPage: perPage, search: search);
    return Future.value(
      Right(
        Paginated<Employee>(
          items: [Employee.fake(id: 1, name: 'Sara Mostafa')],
          currentPage: 1,
          perPage: perPage,
          total: 1,
          lastPage: 1,
        ),
      ),
    );
  }

  @override
  FutureEither<EmployeeProfile> show(int employeeId) {
    return Future.value(
      Right(EmployeeProfile(employee: Employee.fake(id: employeeId))),
    );
  }

  @override
  FutureEither<MonthCalendar> attendance(
    int employeeId, {
    int? year,
    int? month,
  }) async => throw UnimplementedError();

  @override
  FutureEither<Paginated<Payslip>> payroll(
    int employeeId, {
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) async => throw UnimplementedError();

  @override
  FutureEither<Paginated<Payslip>> shopPayroll({
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) async => throw UnimplementedError();
}
