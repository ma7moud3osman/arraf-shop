import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../data/audit_failures.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_scan_result.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_status.dart';
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

  /// All barcodes known to be recorded in this session (from join seed +
  /// every scan response + every realtime event). Used for local-first
  /// duplicate detection so the scanner can reject dupes without a
  /// round-trip.
  final Set<String> _recordedBarcodes = <String>{};
  Set<String> get recordedBarcodes => Set.unmodifiable(_recordedBarcodes);

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

  StreamSubscription<AuditSessionEvent>? _shopSub;
  int? _subscribedShopId;

  // Monotonic counter for optimistic placeholder ids (always negative so they
  // can't collide with real server-assigned ids, which are positive).
  int _optimisticSeq = 0;

  bool _disposed = false;

  bool _scanInFlight = false;
  bool get scanInFlight => _scanInFlight;

  /// Monotonic counter incremented whenever the server rejects a scan as a
  /// duplicate (HTTP 409). The screen observes this to toast "already scanned"
  /// without flooding the main error UI.
  int _duplicateTick = 0;
  int get duplicateTick => _duplicateTick;

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
      (SessionWithScans payload) {
        _session = payload.session;
        // Feed shows only real recorded scans (never duplicates).
        _feed
          ..clear()
          ..addAll(
            payload.recentScans
                .where((s) => s.result != AuditScanResult.duplicate)
                .take(maxFeedSize),
          );
        // The recorded-barcodes set must include *all* previously scanned
        // barcodes (including historical duplicates) so the scanner can
        // suppress them locally.
        _recordedBarcodes
          ..clear()
          ..addAll(payload.recentScans.map((s) => s.barcode));
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

    // Local-first duplicate check: if this barcode is already known to be
    // recorded in this session, never hit the server. Bump the toast tick
    // so the screen shows a "duplicate" hint. Duplicates are *not* kept in
    // the feed — the feed only shows real recorded scans.
    if (_recordedBarcodes.contains(barcode)) {
      _duplicateTick += 1;
      _safeNotify();
      return;
    }

    // Re-entry guard: serialize scans so a hold-the-code-in-view storm can't
    // stack dozens of in-flight POSTs. The scanner view also debounces, but
    // debounce windows < network latency aren't enough on their own.
    if (_scanInFlight) return;
    _scanInFlight = true;

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
        if (f is ConflictFailure) {
          // Another device (or an in-flight race from this one) already
          // recorded this barcode. Keep the barcode out of the feed — just
          // nudge the toast and remember it's known so future scans short-
          // circuit locally.
          _recordedBarcodes.add(barcode);
          _duplicateTick += 1;
          _scanStatus = AppStatus.success;
        } else {
          _scanStatus = AppStatus.failure;
          _errorMessage = f.message;
        }
      },
      (ScanResponse response) {
        _recordedBarcodes.add(response.scan.barcode);
        _session = response.session;
        if (response.scan.result == AuditScanResult.duplicate) {
          // Legacy path (kept for older backends): drop the optimistic row
          // and surface as a toast instead of a feed entry.
          _feed.removeWhere((s) => s.id == optimisticId);
          _duplicateTick += 1;
        } else {
          final idx = _feed.indexWhere((s) => s.id == optimisticId);
          if (idx >= 0) {
            _feed[idx] = response.scan;
          } else {
            _prepend(response.scan);
          }
        }
        _scanStatus = AppStatus.success;
      },
    );
    _scanInFlight = false;
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

    final sessionId = _sessionIdFromChannel(current.channel);
    if (sessionId == null) return false;

    if (_realtimeSub == null) {
      _subscribedSessionId = sessionId;
      _realtimeSub = _realtime
          .subscribe(sessionId)
          .listen(_onRealtimeEvent, onError: _onRealtimeError);
    }

    // Also listen to the shop-wide feed so status changes driven by another
    // device (notably completion) propagate to this screen.
    if (_shopSub == null) {
      _subscribedShopId = current.shopId;
      _shopSub = _realtime
          .subscribeShop(current.shopId)
          .listen(_onShopEvent, onError: _onRealtimeError);
    }
    return true;
  }

  Future<void> unsubscribe() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    final sessionId = _subscribedSessionId;
    _subscribedSessionId = null;
    if (sessionId != null) {
      await _realtime.unsubscribe(sessionId);
    }

    await _shopSub?.cancel();
    _shopSub = null;
    final shopId = _subscribedShopId;
    _subscribedShopId = null;
    if (shopId != null) {
      await _realtime.unsubscribeShop(shopId);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _onRealtimeEvent(AuditScanEvent event) {
    // Always remember the barcode so future local scans can short-circuit.
    _recordedBarcodes.add(event.barcode);

    // Duplicates never enter the feed — they're already represented by the
    // original Valid row.
    if (event.result != AuditScanResult.duplicate) {
      // Idempotency: drop events whose scan id is already in the feed.
      final exists = _feed.any((s) => s.id == event.scanId);
      if (!exists) {
        _prepend(
          AuditScan(
            id: event.scanId,
            result: event.result,
            barcode: event.barcode,
            productName: event.productName,
            deviceLabel: event.deviceLabel,
            scannedAt: event.scannedAt,
          ),
        );
      }
    }

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

  void _onShopEvent(AuditSessionEvent event) {
    final current = _session;
    if (current == null || current.uuid != event.uuid) return;

    final nextStatus = AuditStatus.fromString(event.status);
    _session = AuditSession(
      uuid: current.uuid,
      shopId: current.shopId,
      status: nextStatus,
      expectedCount: event.expectedCount,
      expectedWeightGrams: event.expectedWeightGrams,
      scannedCount: event.scannedCount,
      scannedWeightGrams: event.scannedWeightGrams,
      progressPercent: event.progressPercent,
      channel: current.channel,
      startedAt: event.startedAt ?? current.startedAt,
      completedAt: event.completedAt ?? current.completedAt,
      notes: current.notes,
      startedBy: current.startedBy,
      completedBy: current.completedBy,
      reportSnapshot: current.reportSnapshot,
    );
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
    // Idempotent — safe if the screen already called unsubscribe() from its
    // own dispose. Tears down both subscriptions (session + shop) and
    // releases refcounts on the underlying Pusher channels.
    unawaited(unsubscribe());
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
    // Match the backend formula: percent is (scanned_count / expected_count).
    // Previously this was computed from weights, which drifted away from the
    // value the server returns and left the % label frozen at 0.
    final expected = base.expectedCount;
    final percent =
        expected == 0
            ? 0
            : ((scannedCount / expected) * 100).clamp(0, 100).round();

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
