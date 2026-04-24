import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/employee_profile.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_detail_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('EmployeeDetailProvider', () {
    late FakeEmployeesRepository repo;

    setUp(() => repo = FakeEmployeesRepository());

    test('load() success exposes the profile', () async {
      final provider = EmployeeDetailProvider(repository: repo, employeeId: 7);

      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.profile, isA<EmployeeProfile>());
      expect(provider.profile!.employee.id, 7);
      expect(repo.showCalls, 1);

      provider.dispose();
    });

    test('load() failure surfaces the message', () async {
      repo.showHandler = (_) async => const Left(NetworkFailure('offline'));
      final provider = EmployeeDetailProvider(repository: repo, employeeId: 7);

      await provider.load();

      expect(provider.status, AppStatus.failure);
      expect(provider.errorMessage, 'offline');
      expect(provider.profile, isNull);

      provider.dispose();
    });

    test('refresh re-runs show()', () async {
      final provider = EmployeeDetailProvider(repository: repo, employeeId: 7);
      await provider.load();
      await provider.refresh();

      expect(repo.showCalls, 2);
      provider.dispose();
    });

    test('exposes the configured employeeId', () {
      final provider = EmployeeDetailProvider(repository: repo, employeeId: 42);
      expect(provider.employeeId, 42);
      // sanity: Employee.fake honours the requested id
      expect(Employee.fake(id: 42).id, 42);
      provider.dispose();
    });
  });
}
