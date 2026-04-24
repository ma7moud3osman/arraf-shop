import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/employees_repository.dart';

/// Loads the shop's employees and tracks a multi-select for the audit
/// session participants picker. Server-side search is delegated to
/// [EmployeesRepository.list] via [search]; the selection set is kept
/// client-side and survives across searches.
class EmployeesPickerProvider extends ChangeNotifier {
  EmployeesPickerProvider({required EmployeesRepository repository})
    : _repository = repository;

  final EmployeesRepository _repository;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  List<Employee> _employees = const [];
  List<Employee> get employees => _employees;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _query = '';
  String get query => _query;

  final Set<int> _selectedIds = <int>{};
  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool isSelected(int id) => _selectedIds.contains(id);

  bool _disposed = false;

  Future<void> load({String? search}) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    if (search != null) _query = search;
    _safeNotify();

    final result = await _repository.list(
      perPage: 100,
      search: _query.isEmpty ? null : _query,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<Employee> page) {
        _employees = page.items;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> search(String query) async {
    _query = query.trim();
    await load();
  }

  void toggle(int id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    _safeNotify();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
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
}
