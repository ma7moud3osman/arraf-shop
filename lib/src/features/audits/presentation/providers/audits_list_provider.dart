import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/repositories/audit_repository.dart';

/// Lists the shop's audit sessions and handles starting a new one.
///
/// State:
/// * [status]   — overall lifecycle of the last `load`/`refresh` call.
/// * [sessions] — current list of sessions (page 1; pagination is a later step).
/// * [errorMessage] — populated when [status] == [AppStatus.failure].
///
/// [startNew] has its own lifecycle flag [startStatus] so that kicking off a
/// new session does not clobber the list's success state.
class AuditsListProvider extends ChangeNotifier {
  AuditsListProvider({required AuditRepository repository})
    : _repository = repository;

  final AuditRepository _repository;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  List<AuditSession> _sessions = const [];
  List<AuditSession> get sessions => _sessions;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AppStatus _startStatus = AppStatus.initial;
  AppStatus get startStatus => _startStatus;

  AuditSession? _lastStarted;

  /// The session produced by the most recent successful [startNew] call.
  /// Consumers should read-and-clear via [consumeLastStarted] after routing.
  AuditSession? get lastStarted => _lastStarted;

  AuditSession? consumeLastStarted() {
    final s = _lastStarted;
    _lastStarted = null;
    return s;
  }

  bool _disposed = false;

  Future<void> load() => _fetch();

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.list(page: 1);

    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<AuditSession> page) {
        _sessions = page.items;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  /// Starts a new audit session. On success, the new session is prepended to
  /// [sessions] and stored in [lastStarted] so the caller can navigate to it.
  Future<void> startNew({String? notes}) async {
    _startStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.start(notes: notes);

    result.fold(
      (Failure f) {
        _startStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (AuditSession session) {
        _sessions = [session, ..._sessions];
        _lastStarted = session;
        _startStatus = AppStatus.success;
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
