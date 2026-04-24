import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/employees/domain/repositories/employees_repository.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employees_list_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/screens/employees_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';

import '../../_fakes.dart';

Widget _harness({
  required EmployeesListProvider list,
  required EmployeesRepository repo,
}) {
  return MaterialApp(
    home: ScreenUtilInit(
      designSize: const Size(375, 812),
      child: MultiProvider(
        providers: [
          Provider<EmployeesRepository>.value(value: repo),
          ChangeNotifierProvider<EmployeesListProvider>.value(value: list),
        ],
        child: Builder(builder: (_) => const EmployeesScreen()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmployeesScreen', () {
    testWidgets('renders the loaded employees', (tester) async {
      final repo =
          FakeEmployeesRepository()
            ..listHandler = (page, perPage, search) async {
              return Right(
                Paginated<Employee>(
                  items: [
                    Employee.fake(id: 1, name: 'Sara Mostafa', role: 'Cashier'),
                    Employee.fake(id: 2, name: 'Omar Ali', role: 'Manager'),
                  ],
                  currentPage: 1,
                  perPage: perPage,
                  total: 2,
                  lastPage: 1,
                ),
              );
            };
      final provider = EmployeesListProvider(repository: repo);

      await tester.pumpWidget(_harness(list: provider, repo: repo));

      // Trigger the postFrameCallback that calls load().
      await tester.pump();
      // Resolve the Future returned by the fake.
      await tester.pump();

      expect(find.text('Sara Mostafa'), findsOneWidget);
      expect(find.text('Omar Ali'), findsOneWidget);

      provider.dispose();
    });
  });
}
