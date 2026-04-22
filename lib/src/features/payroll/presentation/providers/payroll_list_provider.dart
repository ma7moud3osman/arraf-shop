import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../domain/entities/payslip.dart';
import '../../domain/repositories/payroll_repository.dart';

class PayrollListProvider extends ChangeNotifier {
  PayrollListProvider({required PayrollRepository repository})
    : _repository = repository;

  final PayrollRepository _repository;

  AppStatus _status = AppStatus.initial;
  List<Payslip> _payslips = const [];
  int? _year;
  int? _month;
  String? _errorMessage;

  AppStatus get status => _status;
  List<Payslip> get payslips => _payslips;
  int? get year => _year;
  int? get month => _month;
  String? get errorMessage => _errorMessage;

  bool get hasFilter => _year != null || _month != null;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final result = await _repository.list(year: _year, month: _month);
    result.fold(
      (failure) {
        _status = AppStatus.failure;
        _errorMessage = failure.message;
      },
      (records) {
        _payslips = records;
        _status = AppStatus.success;
      },
    );
    notifyListeners();
  }

  Future<void> refresh() => load();

  /// Apply month + year filter. Pass `null` to either to clear that axis.
  Future<void> setFilter({int? year, int? month}) async {
    _year = year;
    _month = month;
    await load();
  }

  Future<void> clearFilter() => setFilter(year: null, month: null);
}
