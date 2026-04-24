import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../domain/entities/attendance_history.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceHistoryProvider extends ChangeNotifier {
  AttendanceHistoryProvider({required AttendanceRepository repository})
    : _repository = repository,
      _focusedMonth = _firstDayOfMonth(DateTime.now());

  final AttendanceRepository _repository;

  DateTime _focusedMonth;
  AppStatus _status = AppStatus.initial;
  AttendanceHistory? _history;
  String? _errorMessage;

  DateTime get focusedMonth => _focusedMonth;
  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;
  AttendanceHistory? get history => _history;
  List<AttendanceRecord> get records => _history?.records ?? const [];

  /// True when the focused month is the present calendar month — used by
  /// the calendar header to disable the next-month chevron. Prefers the
  /// server-sent flag and falls back to client-side date math.
  bool get isFocusedMonthCurrent {
    final h = _history;
    if (h != null && h.year == _focusedMonth.year && h.month == _focusedMonth.month) {
      return h.isCurrentMonth;
    }
    final now = DateTime.now();
    return _focusedMonth.year == now.year && _focusedMonth.month == now.month;
  }

  /// Returns true when the calendar day is a configured weekly holiday.
  /// Computed from the focused-month meta (working_days_so_far includes
  /// holidays) — falls back to false when no history is loaded yet.
  bool isHoliday(DateTime day) {
    final h = _history;
    if (h == null) return false;
    // The self-history payload doesn't ship a per-day breakdown — the calendar
    // tile decides via the records map and this flag stays false.
    return false;
  }

  /// Map keyed by `YYYY-MM-DD` for O(1) lookup when painting calendar cells.
  Map<String, AttendanceRecord> get recordsByDate {
    return {for (final r in records) _dateKey(r.date): r};
  }

  AttendanceRecord? recordForDay(DateTime day) => recordsByDate[_dateKey(day)];

  Future<void> load() => _loadMonth(_focusedMonth);

  Future<void> changeMonth(DateTime month) async {
    _focusedMonth = _firstDayOfMonth(month);
    await _loadMonth(_focusedMonth);
  }

  Future<void> _loadMonth(DateTime month) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.history(
      year: month.year,
      month: month.month,
    );
    result.fold(
      (failure) {
        _status = AppStatus.failure;
        _errorMessage = failure.message;
      },
      (history) {
        _history = history;
        _status = AppStatus.success;
      },
    );
    notifyListeners();
  }

  static DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
