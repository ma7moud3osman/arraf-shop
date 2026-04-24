import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/employee_profile.dart';
import '../../domain/repositories/employees_repository.dart';

class EmployeeDetailProvider extends ChangeNotifier {
  EmployeeDetailProvider({
    required EmployeesRepository repository,
    required this.employeeId,
  }) : _repository = repository;

  final EmployeesRepository _repository;
  final int employeeId;

  AppStatus _status = AppStatus.initial;
  EmployeeProfile? _profile;
  String? _errorMessage;
  bool _disposed = false;

  AppStatus get status => _status;
  EmployeeProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.show(employeeId);
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (EmployeeProfile profile) {
        _profile = profile;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

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
