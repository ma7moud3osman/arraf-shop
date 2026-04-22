import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceHistoryProvider extends ChangeNotifier {
  AttendanceHistoryProvider({required AttendanceRepository repository})
    : _repository = repository,
      _focusedMonth = _firstDayOfMonth(DateTime.now());

  final AttendanceRepository _repository;

  DateTime _focusedMonth;
  AppStatus _status = AppStatus.initial;
  List<AttendanceRecord> _records = const [];
  String? _errorMessage;

  DateTime get focusedMonth => _focusedMonth;
  AppStatus get status => _status;
  String? get errorMessage => _errorMessage;

  /// Map keyed by `YYYY-MM-DD` for O(1) lookup when painting calendar cells.
  Map<String, AttendanceRecord> get recordsByDate {
    return {for (final r in _records) _dateKey(r.date): r};
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
      (records) {
        _records = records;
        _status = AppStatus.success;
      },
    );
    notifyListeners();
  }

  static DateTime _firstDayOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
