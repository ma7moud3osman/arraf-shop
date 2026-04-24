import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../../payroll/domain/entities/payslip.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/employees_repository.dart';

/// Paginated payslips for one employee. Supports optional year/month filters
/// (used as a "jump to period" filter on the payslips tab).
class EmployeePayrollProvider extends ChangeNotifier {
  EmployeePayrollProvider({
    required EmployeesRepository repository,
    required this.employeeId,
  }) : _repository = repository;

  final EmployeesRepository _repository;
  final int employeeId;

  AppStatus _status = AppStatus.initial;
  AppStatus _moreStatus = AppStatus.initial;
  Paginated<Payslip> _page = Paginated.empty<Payslip>();
  int? _year;
  int? _month;
  String? _errorMessage;
  bool _disposed = false;

  AppStatus get status => _status;
  AppStatus get moreStatus => _moreStatus;
  List<Payslip> get payslips => _page.items;
  bool get hasMore => _page.hasMore;
  int? get year => _year;
  int? get month => _month;
  bool get hasFilter => _year != null || _month != null;
  String? get errorMessage => _errorMessage;
  int get total => _page.total;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.payroll(
      employeeId,
      page: 1,
      year: _year,
      month: _month,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<Payslip> page) {
        _page = page;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (!hasMore) return;
    if (_moreStatus == AppStatus.loading) return;
    _moreStatus = AppStatus.loading;
    _safeNotify();

    final next = _page.currentPage + 1;
    final result = await _repository.payroll(
      employeeId,
      page: next,
      year: _year,
      month: _month,
    );
    result.fold(
      (Failure f) {
        _moreStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<Payslip> page) {
        _page = _page.appending(page);
        _moreStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> setFilter({int? year, int? month}) async {
    _year = year;
    _month = month;
    await load();
  }

  Future<void> clearFilter() => setFilter(year: null, month: null);

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
