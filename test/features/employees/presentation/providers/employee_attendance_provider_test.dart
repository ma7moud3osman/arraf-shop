import 'package:arraf_shop/src/features/employees/domain/entities/month_calendar.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employee_attendance_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('EmployeeAttendanceProvider', () {
    late FakeEmployeesRepository repo;
    late EmployeeAttendanceProvider provider;

    setUp(() {
      repo = FakeEmployeesRepository();
      provider = EmployeeAttendanceProvider(
        repository: repo,
        employeeId: 5,
        initialMonth: DateTime(2026, 4, 24),
      );
    });

    tearDown(() => provider.dispose());

    test('load() fetches the focused month', () async {
      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.calendar, isA<MonthCalendar>());
      expect(repo.lastAttendanceYear, 2026);
      expect(repo.lastAttendanceMonth, 4);
    });

    test('changeMonth() switches month and re-fetches', () async {
      await provider.load();
      await provider.changeMonth(DateTime(2026, 3, 15));

      expect(provider.focusedMonth, DateTime(2026, 3, 1));
      expect(repo.lastAttendanceMonth, 3);
      expect(repo.attendanceCalls, 2);
    });

    test('nextMonth and previousMonth navigate by one month', () async {
      await provider.nextMonth();
      expect(provider.focusedMonth, DateTime(2026, 5, 1));

      await provider.previousMonth();
      expect(provider.focusedMonth, DateTime(2026, 4, 1));
    });

    test('dayFor returns the matching CalendarDay', () async {
      await provider.load();
      final day = provider.dayFor(DateTime(2026, 4, 10));

      expect(day, isNotNull);
      expect(day!.date.day, 10);
    });

    test('failure surfaces the error message', () async {
      repo.attendanceHandler =
          (_, _, _) async => const Left(ServerFailure('boom'));

      await provider.load();

      expect(provider.status, AppStatus.failure);
      expect(provider.errorMessage, 'boom');
    });
  });
}
