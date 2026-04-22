import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_scan_result.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/realtime/audit_realtime.dart';
import '../../domain/repositories/audit_repository.dart';

/// Manages a single active [AuditSession]: joining, scanning (with optimistic
/// UI + reconciliation), completing, and merging realtime scan events.
///
/// The feed is a ring buffer of the latest [maxFeedSize] scans. Scans are
/// prepended (newest first). Realtime events are deduped against the feed by
/// scan id so locally-recorded scans aren't doubled when the server echoes.
class AuditSessionProvider extends ChangeNotifier {
  AuditSessionProvider({
    required AuditRepository repository,
    required AuditRealtime realtime,
    required String deviceLabel,
    int? shopEmployeeId,
  }) : _repository = repository,
       _realtime = realtime,
       _deviceLabel = deviceLabel,
       _shopEmployeeId = shopEmployeeId;

  static const int maxFeedSize = 20;

  final AuditRepository _repository;
  final AuditRealtime _realtime;
  final String _deviceLabel;
  final int? _shopEmployeeId;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  AuditSession? _session;
  AuditSession? get session => _session;

  final List<AuditScan> _feed = [];
  List<AuditScan> get feed => List.unmodifiable(_feed);

  /// Tracks the most recent [scan] call independently so it doesn't clobber
  /// the top-level [status] once the session is loaded.
  AppStatus _scanStatus = AppStatus.initial;
  AppStatus get scanStatus => _scanStatus;

  AppStatus _completeStatus = AppStatus.initial;
  AppStatus get completeStatus => _completeStatus;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  StreamSubscription<AuditScanEvent>? _realtimeSub;
  int? _subscribedSessionId;

  // Monotonic counter for optimistic placeholder ids (always negative so they
  // can't collide with real server-assigned ids, which are positive).
  int _optimisticSeq = 0;

  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> join(String uuid) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.show(uuid);
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (AuditSession s) {
        _session = s;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  /// Record a scan with optimistic UI.
  ///
  /// A placeholder [AuditScan] with a synthetic negative id is prepended
  /// immediately; the call then awaits the server and reconciles:
  ///  * success → replace placeholder with the server scan, update counters
  ///  * failure → remove placeholder and surface the failure
  Future<void> scan(String barcode) async {
    final current = _session;
    if (current == null) {
      _scanStatus = AppStatus.failure;
      _errorMessage = 'No active session';
      _safeNotify();
      return;
    }

    final optimisticId = _nextOptimisticId();
    final optimistic = AuditScan(
      id: optimisticId,
      result: AuditScanResult.valid,
      barcode: barcode,
      deviceLabel: _deviceLabel,
      scannedAt: DateTime.now(),
    );

    _prepend(optimistic);
    _scanStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.recordScan(
      uuid: current.uuid,
      barcode: barcode,
      deviceLabel: _deviceLabel,
      shopEmployeeId: _shopEmployeeId,
    );

    result.fold(
      (Failure f) {
        _feed.removeWhere((s) => s.id == optimisticId);
        _scanStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (ScanResponse response) {
        final idx = _feed.indexWhere((s) => s.id == optimisticId);
        if (idx >= 0) {
          _feed[idx] = response.scan;
        } else {
          _prepend(response.scan);
        }
        _session = response.session;
        _scanStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> complete() async {
    final current = _session;
    if (current == null) return;

    _completeStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.complete(current.uuid);
    result.fold(
      (Failure f) {
        _completeStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (AuditSession s) {
        _session = s;
        _completeStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  /// Subscribe to realtime scan events for the currently-loaded session.
  /// Safe to call multiple times; subsequent calls are no-ops while already
  /// subscribed. Returns `false` if no session is loaded or the id cannot be
  /// derived from the channel name.
  bool subscribe() {
    final current = _session;
    if (current == null) return false;
    if (_realtimeSub != null) return true;

    final sessionId = _sessionIdFromChannel(current.channel);
    if (sessionId == null) return false;

    _subscribedSessionId = sessionId;
    _realtimeSub = _realtime
        .subscribe(sessionId)
        .listen(_onRealtimeEvent, onError: _onRealtimeError);
    return true;
  }

  Future<void> unsubscribe() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    final id = _subscribedSessionId;
    _subscribedSessionId = null;
    if (id != null) {
      await _realtime.unsubscribe(id);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _onRealtimeEvent(AuditScanEvent event) {
    // Idempotency: drop events whose scan id is already in the feed.
    final exists = _feed.any((s) => s.id == event.scanId);
    if (exists) return;

    final scan = AuditScan(
      id: event.scanId,
      result: event.result,
      barcode: event.barcode,
      deviceLabel: event.deviceLabel,
      scannedAt: event.scannedAt,
    );
    _prepend(scan);

    final current = _session;
    if (current != null) {
      _session = _SessionCountersPatch.apply(
        current,
        scannedCount: event.scannedCount,
        scannedWeightGrams: event.scannedWeight,
      );
    }
    _safeNotify();
  }

  void _onRealtimeError(Object error) {
    _errorMessage = error.toString();
    _safeNotify();
  }

  void _prepend(AuditScan scan) {
    _feed.insert(0, scan);
    if (_feed.length > maxFeedSize) {
      _feed.removeRange(maxFeedSize, _feed.length);
    }
  }

  int _nextOptimisticId() {
    _optimisticSeq -= 1;
    return _optimisticSeq;
  }

  /// Backend channel format is `private-shop-audit.<numericId>`.
  static int? _sessionIdFromChannel(String channel) {
    final parts = channel.split('.');
    if (parts.isEmpty) return null;
    return int.tryParse(parts.last);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeSub?.cancel();
    super.dispose();
  }
}

/// Rebuilds an [AuditSession] with only the running counters replaced. Kept
/// private to the provider since it's a local concern — the domain entity is
/// immutable by design.
class _SessionCountersPatch {
  static AuditSession apply(
    AuditSession base, {
    required int scannedCount,
    required double scannedWeightGrams,
  }) {
    final expected = base.expectedWeightGrams;
    final percent =
        expected == 0
            ? 0
            : ((scannedWeightGrams / expected) * 100).clamp(0, 100).round();

    return AuditSession(
      uuid: base.uuid,
      shopId: base.shopId,
      status: base.status,
      expectedCount: base.expectedCount,
      expectedWeightGrams: base.expectedWeightGrams,
      scannedCount: scannedCount,
      scannedWeightGrams: scannedWeightGrams,
      progressPercent: percent,
      channel: base.channel,
      startedAt: base.startedAt,
      completedAt: base.completedAt,
      notes: base.notes,
      startedBy: base.startedBy,
      completedBy: base.completedBy,
      reportSnapshot: base.reportSnapshot,
    );
  }
}
