import 'package:arraf_shop/src/features/employees/domain/repositories/employees_repository.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_attendance_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_detail_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_payroll_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/widgets/employee_attendance_tab.dart';
import 'package:arraf_shop/src/features/employees/presentation/widgets/employee_payroll_tab.dart';
import 'package:arraf_shop/src/features/employees/presentation/widgets/employee_profile_tab.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Owner-facing detail screen for one employee. Three tabs:
/// Profile · Attendance · Payslips.
///
/// Each tab is backed by its own provider, scoped to this screen instance
/// so opening a different employee gives a fresh load (rather than
/// reusing stale state from a previously-viewed teammate).
class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    required this.name,
  });

  final int employeeId;
  final String name;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create:
              (ctx) => EmployeeDetailProvider(
                repository: ctx.read<EmployeesRepository>(),
                employeeId: employeeId,
              )..load(),
        ),
        ChangeNotifierProvider(
          create:
              (ctx) => EmployeeAttendanceProvider(
                repository: ctx.read<EmployeesRepository>(),
                employeeId: employeeId,
              ),
        ),
        ChangeNotifierProvider(
          create:
              (ctx) => EmployeePayrollProvider(
                repository: ctx.read<EmployeesRepository>(),
                employeeId: employeeId,
              ),
        ),
      ],
      child: _EmployeeDetailView(name: name),
    );
  }
}

class _EmployeeDetailView extends StatelessWidget {
  const _EmployeeDetailView({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name),
          bottom: TabBar(
            isScrollable: false,
            tabs: [
              Tab(text: 'employees.tabs.profile'.tr()),
              Tab(text: 'employees.tabs.attendance'.tr()),
              Tab(text: 'employees.tabs.payslips'.tr()),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeeProfileTab(),
            EmployeeAttendanceTab(),
            EmployeePayrollTab(),
          ],
        ),
      ),
    );
  }
}
