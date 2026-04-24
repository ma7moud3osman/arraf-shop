import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/audit_report_snapshot.dart';
import '../../domain/repositories/audit_repository.dart';

/// Lightweight provider for the live-summary sheet.
///
/// The post-audit summary screen consumes the same `summary` endpoint via
/// ad-hoc state in [AuditSummaryScreen]; this provider exists so the
/// mid-session bottom sheet can be re-fetched on demand without leaking
/// `setState`-style logic into the host screen.
class AuditSummaryProvider extends ChangeNotifier {
  AuditSummaryProvider({required AuditRepository repository})
      : _repository = repository;

  final AuditRepository _repository;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  AuditReportSnapshot? _snapshot;
  AuditReportSnapshot? get snapshot => _snapshot;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _disposed = false;

  Future<void> load(String uuid) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.summary(uuid);
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (AuditReportSnapshot snap) {
        _snapshot = snap;
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
}
