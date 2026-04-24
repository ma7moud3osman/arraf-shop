import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employees_list_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('EmployeesListProvider', () {
    late FakeEmployeesRepository repo;
    late EmployeesListProvider provider;

    setUp(() {
      repo = FakeEmployeesRepository();
      // Use a tiny debounce so search tests don't have to wait.
      provider = EmployeesListProvider(
        repository: repo,
        searchDebounce: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => provider.dispose());

    test('load() flips status and stores the page', () async {
      expect(provider.status, AppStatus.initial);

      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.employees, hasLength(2));
      expect(repo.listCalls, 1);
      expect(repo.lastListPage, 1);
    });

    test('load() failure exposes errorMessage and stays in failure', () async {
      final failingRepo = FailingEmployeesRepository(
        failure: const ServerFailure('nope'),
      );
      final failingProvider = EmployeesListProvider(repository: failingRepo);

      await failingProvider.load();

      expect(failingProvider.status, AppStatus.failure);
      expect(failingProvider.errorMessage, 'nope');
      expect(failingProvider.employees, isEmpty);
      failingProvider.dispose();
    });

    test('setSearch debounces and triggers load with search arg', () async {
      // Three rapid keystrokes — only the last should hit the repo.
      provider.setSearch('s');
      provider.setSearch('sa');
      provider.setSearch('sar');

      // Before debounce expires, no call should have run.
      expect(repo.listCalls, 0);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.listCalls, 1);
      expect(repo.lastSearch, 'sar');
    });

    test('loadMore appends the next page and updates currentPage', () async {
      repo.listHandler = (page, perPage, search) async {
        return Right(makePage(page: page, lastPage: 2, perPage: perPage));
      };

      await provider.load();
      expect(provider.employees, hasLength(2));
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.employees, hasLength(4));
      expect(provider.hasMore, isFalse);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      // Default fake: lastPage == currentPage, so hasMore is false from
      // the get-go.
      await provider.load();
      final before = repo.listCalls;

      await provider.loadMore();

      expect(repo.listCalls, before);
    });
  });

  group('Employee.initials', () {
    test('uses first letters of first + last name', () {
      expect(Employee.fake(name: 'Sara Mostafa').initials, 'SM');
    });
    test('falls back to a single letter for single-word names', () {
      expect(Employee.fake(name: 'Zain').initials, 'Z');
    });
  });
}
