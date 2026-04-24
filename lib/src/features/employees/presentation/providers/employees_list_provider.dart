import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/debouncer.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/employees_repository.dart';

/// Paginated employees list with debounced server-side search.
///
/// * [load]    — replace + reset paging.
/// * [refresh] — re-fetch page 1 with the current search.
/// * [loadMore] — append the next page; no-op if [hasMore] is false.
/// * [setSearch] — debounces by 350ms then calls [load].
class EmployeesListProvider extends ChangeNotifier {
  EmployeesListProvider({
    required EmployeesRepository repository,
    Duration searchDebounce = const Duration(milliseconds: 350),
  }) : _repository = repository,
       _debouncer = Debouncer(delay: searchDebounce);

  final EmployeesRepository _repository;
  final Debouncer _debouncer;

  AppStatus _status = AppStatus.initial;
  AppStatus _moreStatus = AppStatus.initial;
  Paginated<Employee> _page = Paginated.empty<Employee>();
  String _search = '';
  String? _errorMessage;
  bool _disposed = false;

  AppStatus get status => _status;
  AppStatus get moreStatus => _moreStatus;
  List<Employee> get employees => _page.items;
  String get search => _search;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _page.hasMore;
  int get total => _page.total;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.list(
      page: 1,
      search: _search.isEmpty ? null : _search,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<Employee> page) {
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
    final result = await _repository.list(
      page: next,
      search: _search.isEmpty ? null : _search,
    );
    result.fold(
      (Failure f) {
        _moreStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<Employee> page) {
        _page = _page.appending(page);
        _moreStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  /// Updates the search term and schedules a debounced reload. Pass empty
  /// to clear the filter.
  void setSearch(String query) {
    final next = query.trim();
    if (next == _search) return;
    _search = next;
    _safeNotify();
    _debouncer.run(() {
      if (_disposed) return;
      load();
    });
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debouncer.dispose();
    super.dispose();
  }
}
