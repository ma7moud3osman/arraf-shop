import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_status.dart';
import '../../domain/realtime/audit_realtime.dart';
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
  AuditsListProvider({
    required AuditRepository repository,
    required AuditRealtime realtime,
  }) : _repository = repository,
       _realtime = realtime;

  final AuditRepository _repository;
  final AuditRealtime _realtime;

  StreamSubscription<AuditSessionEvent>? _realtimeSub;
  int? _subscribedShopId;

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
        // Now that we know the shop, subscribe to its realtime feed if we
        // haven't already. `subscribeRealtime()` is a no-op if a sub is live.
        _maybeSubscribeFromSessions();
      },
    );
    _safeNotify();
  }

  void _maybeSubscribeFromSessions() {
    if (_realtimeSub != null) return;
    if (_sessions.isEmpty) return;
    subscribeRealtime();
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

  /// Subscribe to shop-wide audit events. Safe to call multiple times.
  /// The shop id is derived from the currently-loaded sessions; if the
  /// list is still empty (no shop known yet) this is a no-op and the
  /// subscription will be established automatically on the next load.
  bool subscribeRealtime() {
    if (_realtimeSub != null) return true;
    final shopId = _sessions.isNotEmpty ? _sessions.first.shopId : null;
    if (shopId == null) return false;

    _subscribedShopId = shopId;
    _realtimeSub = _realtime
        .subscribeShop(shopId)
        .listen(_onRealtimeEvent, onError: (_) {});
    return true;
  }

  Future<void> unsubscribeRealtime() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    final id = _subscribedShopId;
    _subscribedShopId = null;
    if (id != null) {
      await _realtime.unsubscribeShop(id);
    }
  }

  void _onRealtimeEvent(AuditSessionEvent event) {
    final status = AuditStatus.fromString(event.status);
    final idx = _sessions.indexWhere((s) => s.uuid == event.uuid);
    if (idx >= 0) {
      final current = _sessions[idx];
      _sessions = List.of(_sessions)
        ..[idx] = _SessionPatch.apply(current, event, status);
    } else {
      // Brand-new session (e.g. another device just started one). Prepend.
      _sessions = [_SessionPatch.synthesize(event, status), ..._sessions];
    }
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Release the underlying shop-audits Pusher channel refcount so the
    // transport can disconnect when no one is watching any more.
    unawaited(unsubscribeRealtime());
    super.dispose();
  }
}

/// Rebuilds [AuditSession] instances from realtime events. Kept private —
/// the domain entity is immutable by design, and the event payload is a
/// trimmed summary (no actor refs, no report snapshot).
class _SessionPatch {
  static AuditSession apply(
    AuditSession base,
    AuditSessionEvent event,
    AuditStatus status,
  ) {
    return AuditSession(
      uuid: base.uuid,
      shopId: base.shopId,
      status: status,
      expectedCount: event.expectedCount,
      expectedWeightGrams: event.expectedWeightGrams,
      scannedCount: event.scannedCount,
      scannedWeightGrams: event.scannedWeightGrams,
      progressPercent: event.progressPercent,
      channel: base.channel,
      startedAt: event.startedAt ?? base.startedAt,
      completedAt: event.completedAt ?? base.completedAt,
      notes: base.notes,
      startedBy: base.startedBy,
      completedBy: base.completedBy,
      reportSnapshot: base.reportSnapshot,
    );
  }

  static AuditSession synthesize(AuditSessionEvent event, AuditStatus status) {
    return AuditSession(
      uuid: event.uuid,
      shopId: event.shopId,
      status: status,
      expectedCount: event.expectedCount,
      expectedWeightGrams: event.expectedWeightGrams,
      scannedCount: event.scannedCount,
      scannedWeightGrams: event.scannedWeightGrams,
      progressPercent: event.progressPercent,
      channel: 'private-shop-audit.${event.uuid}',
      startedAt: event.startedAt,
      completedAt: event.completedAt,
    );
  }
}
