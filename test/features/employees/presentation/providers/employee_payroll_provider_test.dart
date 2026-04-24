import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_payroll_provider.dart';
import 'package:arraf_shop/src/features/payroll/domain/entities/payslip.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

Payslip _payslip(int id, int year, int month) => Payslip(
  id: id,
  year: year,
  month: month,
  baseSalary: 8000,
  totalIncentives: 0,
  totalDeductions: 0,
  netSalary: 8000,
  workingDays: 22,
  absentDays: 0,
  totalLateMinutes: 0,
  totalEarlyLeaveMinutes: 0,
  isLocked: true,
  isPaid: true,
);

void main() {
  group('EmployeePayrollProvider', () {
    late FakeEmployeesRepository repo;
    late EmployeePayrollProvider provider;

    setUp(() {
      repo = FakeEmployeesRepository();
      provider = EmployeePayrollProvider(repository: repo, employeeId: 9);
    });

    tearDown(() => provider.dispose());

    test('load() success populates payslips list', () async {
      repo.payrollHandler = (_, page, perPage, _, _) async {
        return Right(
          Paginated<Payslip>(
            items: [_payslip(1, 2026, 4), _payslip(2, 2026, 3)],
            currentPage: page,
            perPage: perPage,
            total: 2,
            lastPage: page,
          ),
        );
      };

      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.payslips, hasLength(2));
      expect(provider.hasMore, isFalse);
    });

    test('loadMore appends the next page', () async {
      repo.payrollHandler = (_, page, perPage, _, _) async {
        return Right(
          Paginated<Payslip>(
            items: [_payslip(page * 10, 2026, page)],
            currentPage: page,
            perPage: perPage,
            total: 4,
            lastPage: 2,
          ),
        );
      };

      await provider.load();
      expect(provider.payslips, hasLength(1));
      expect(provider.hasMore, isTrue);

      await provider.loadMore();

      expect(provider.payslips, hasLength(2));
      expect(provider.hasMore, isFalse);
      expect(repo.payrollCalls, 2);
    });

    test('setFilter triggers reload with year/month args', () async {
      await provider.setFilter(year: 2026, month: 3);

      expect(provider.year, 2026);
      expect(provider.month, 3);
      expect(provider.hasFilter, isTrue);
      expect(repo.payrollCalls, 1);
    });
  });
}
