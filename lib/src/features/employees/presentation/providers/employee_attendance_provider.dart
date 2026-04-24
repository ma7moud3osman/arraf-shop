import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/month_calendar.dart';
import '../../domain/repositories/employees_repository.dart';

/// Holds the focused-month attendance calendar for a single employee.
/// Month navigation is handled here so the screen widget stays presentational.
class EmployeeAttendanceProvider extends ChangeNotifier {
  EmployeeAttendanceProvider({
    required EmployeesRepository repository,
    required this.employeeId,
    DateTime? initialMonth,
  }) : _repository = repository,
       _focusedMonth = _firstDayOfMonth(initialMonth ?? DateTime.now());

  final EmployeesRepository _repository;
  final int employeeId;

  DateTime _focusedMonth;
  AppStatus _status = AppStatus.initial;
  MonthCalendar? _calendar;
  String? _errorMessage;
  bool _disposed = false;

  DateTime get focusedMonth => _focusedMonth;
  AppStatus get status => _status;
  MonthCalendar? get calendar => _calendar;
  String? get errorMessage => _errorMessage;

  /// Map keyed by `YYYY-MM-DD` for quick day-cell lookup.
  Map<String, CalendarDay> get daysByDate {
    final cal = _calendar;
    if (cal == null) return const {};
    return {for (final d in cal.days) _dateKey(d.date): d};
  }

  CalendarDay? dayFor(DateTime date) => daysByDate[_dateKey(date)];

  Future<void> load() => _loadMonth(_focusedMonth);

  Future<void> refresh() => load();

  Future<void> nextMonth() {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    return changeMonth(next);
  }

  Future<void> previousMonth() {
    final prev = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    return changeMonth(prev);
  }

  Future<void> changeMonth(DateTime month) async {
    _focusedMonth = _firstDayOfMonth(month);
    await _loadMonth(_focusedMonth);
  }

  Future<void> _loadMonth(DateTime month) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.attendance(
      employeeId,
      year: month.year,
      month: month.month,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (MonthCalendar calendar) {
        _calendar = calendar;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
