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
    deviceLabel,
    scannedAt,
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

  /// Connection lifecycle, useful to drive banners / retry UI.
  Stream<RealtimeConnectionState> get connectionState;
}
