import 'package:equatable/equatable.dart';

import '../entities/audit_scan_result.dart';

/// The realtime event pushed over `private-shop-audit.{sessionId}`
/// when a new scan is recorded server-side.
class AuditScanEvent extends Equatable {
  final int sessionId;
  final int scanId;
  final AuditScanResult result;
  final int scannedCount;
  final double scannedWeight;
  final String barcode;
  final String? productName;
  final String deviceLabel;
  final DateTime scannedAt;

  const AuditScanEvent({
    required this.sessionId,
    required this.scanId,
    required this.result,
    required this.scannedCount,
    required this.scannedWeight,
    required this.barcode,
    required this.deviceLabel,
    required this.scannedAt,
    this.productName,
  });

  /// Parse a raw Pusher event payload (already JSON-decoded into a map).
  /// Throws [FormatException] if any required field is missing/invalid so
  /// callers can surface a [ServerFailure] rather than silently dropping.
  factory AuditScanEvent.fromMap(Map<String, dynamic> map) {
    return AuditScanEvent(
      sessionId: (map['session_id'] as num).toInt(),
      scanId: (map['scan_id'] as num).toInt(),
      result: AuditScanResult.fromString(map['result'] as String),
      scannedCount: (map['scanned_count'] as num).toInt(),
      scannedWeight: (map['scanned_weight'] as num).toDouble(),
      barcode: map['barcode'] as String,
      productName: map['product_name'] as String?,
      deviceLabel: map['device_label'] as String,
      scannedAt: DateTime.parse(map['scanned_at'] as String).toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    scanId,
    result,
    scannedCount,
    scannedWeight,
    barcode,
    productName,
    deviceLabel,
    scannedAt,
  ];
}

/// Shop-wide audit list event: delivered on `private-shop-audits.{shopId}`
/// any time an audit session is started / scanned against / completed.
class AuditSessionEvent extends Equatable {
  final String uuid;
  final int shopId;
  final String status;
  final int expectedCount;
  final int scannedCount;
  final double expectedWeightGrams;
  final double scannedWeightGrams;
  final int progressPercent;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const AuditSessionEvent({
    required this.uuid,
    required this.shopId,
    required this.status,
    required this.expectedCount,
    required this.scannedCount,
    required this.expectedWeightGrams,
    required this.scannedWeightGrams,
    required this.progressPercent,
    required this.startedAt,
    required this.completedAt,
  });

  factory AuditSessionEvent.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(Object? raw) {
      if (raw is! String || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toLocal();
    }

    return AuditSessionEvent(
      uuid: map['uuid'] as String,
      shopId: (map['shop_id'] as num).toInt(),
      status: map['status'] as String,
      expectedCount: (map['expected_count'] as num?)?.toInt() ?? 0,
      scannedCount: (map['scanned_count'] as num?)?.toInt() ?? 0,
      expectedWeightGrams:
          (map['expected_weight_grams'] as num?)?.toDouble() ?? 0,
      scannedWeightGrams:
          (map['scanned_weight_grams'] as num?)?.toDouble() ?? 0,
      progressPercent: (map['progress_percent'] as num?)?.toInt() ?? 0,
      startedAt: parseDate(map['started_at']),
      completedAt: parseDate(map['completed_at']),
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    shopId,
    status,
    expectedCount,
    scannedCount,
    expectedWeightGrams,
    scannedWeightGrams,
    progressPercent,
    startedAt,
    completedAt,
  ];
}

/// Lifecycle states exposed by the realtime connection.
enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Subscribe to the scan-recorded feed for a given audit session.
///
/// Implementations MUST:
///  * open a single underlying transport and multiplex subscribers.
///  * reference-count subscriptions per `sessionId`: joining the same session
///    from two widgets results in one private channel; releasing both tears it
///    down.
///  * surface connection-state changes via [connectionState].
abstract class AuditRealtime {
  /// Join `private-shop-audit.{sessionId}` and stream every `scan.recorded`
  /// event as an [AuditScanEvent].
  ///
  /// The returned stream is broadcast-style and closes on [unsubscribe] once
  /// the refcount hits zero.
  Stream<AuditScanEvent> subscribe(int sessionId);

  /// Release one subscription to `sessionId`. Tears down the private channel
  /// when no subscribers remain. Safe to call multiple times.
  Future<void> unsubscribe(int sessionId);

  /// Join `private-shop-audits.{shopId}` and stream every `session.updated`
  /// event as an [AuditSessionEvent] — used by the list screen to keep
  /// cards in sync across devices.
  Stream<AuditSessionEvent> subscribeShop(int shopId);

  /// Release one subscription to `shopId`. Tears down the private channel
  /// when no subscribers remain.
  Future<void> unsubscribeShop(int shopId);

  /// Connection lifecycle, useful to drive banners / retry UI.
  Stream<RealtimeConnectionState> get connectionState;
}
