import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employees_picker_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '_fakes.dart';

Paginated<Employee> _page(List<Employee> items) => Paginated<Employee>(
  items: items,
  currentPage: 1,
  perPage: 100,
  total: items.length,
  lastPage: 1,
);

void main() {
  late FakeEmployeesRepository repo;
  late EmployeesPickerProvider provider;

  setUp(() {
    repo = FakeEmployeesRepository();
    provider = EmployeesPickerProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  test('initial state is empty + initial', () {
    expect(provider.status, AppStatus.initial);
    expect(provider.employees, isEmpty);
    expect(provider.selectedCount, 0);
  });

  test('load: success exposes employees and uses per_page=100', () async {
    repo.listHandler =
        ({int page = 1, int perPage = 100, String? search}) async => Right(
          _page([
            Employee.fake(id: 1, name: 'A'),
            Employee.fake(id: 2, name: 'B'),
          ]),
        );

    await provider.load();

    expect(provider.status, AppStatus.success);
    expect(provider.employees.map((e) => e.id), [1, 2]);
    expect(repo.lastPerPage, 100);
  });

  test('load: failure surfaces the message', () async {
    repo.listHandler =
        ({int page = 1, int perPage = 100, String? search}) async =>
            const Left(ServerFailure('nope'));

    await provider.load();

    expect(provider.status, AppStatus.failure);
    expect(provider.errorMessage, 'nope');
  });

  test('search forwards the trimmed query to the repository', () async {
    repo.listHandler =
        ({int page = 1, int perPage = 100, String? search}) async =>
            Right(_page(const []));

    await provider.search('  Sara  ');

    expect(provider.query, 'Sara');
    expect(repo.lastSearch, 'Sara');
  });

  test('toggle adds and removes ids; selectedCount tracks them', () {
    expect(provider.selectedCount, 0);

    provider.toggle(1);
    provider.toggle(2);
    provider.toggle(3);
    expect(provider.selectedCount, 3);
    expect(provider.isSelected(2), isTrue);

    provider.toggle(2);
    expect(provider.selectedCount, 2);
    expect(provider.isSelected(2), isFalse);
  });

  test('selection survives a re-search', () async {
    repo.listHandler =
        ({int page = 1, int perPage = 100, String? search}) async =>
            Right(_page([Employee.fake(id: 7)]));

    await provider.load();
    provider.toggle(7);
    expect(provider.isSelected(7), isTrue);

    await provider.search('X');
    expect(
      provider.isSelected(7),
      isTrue,
      reason: 'Selection set must persist across searches.',
    );
  });

  test('clearSelection drops everything', () {
    provider.toggle(1);
    provider.toggle(2);
    provider.clearSelection();
    expect(provider.selectedCount, 0);
  });
}
