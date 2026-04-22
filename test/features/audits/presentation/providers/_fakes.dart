import 'dart:async';

import 'package:arraf_shop/src/features/audits/domain/entities/actor_ref.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan_result.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session_item.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/domain/realtime/audit_realtime.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

// -----------------------------------------------------------------------------
// Session / scan factories — keep tests concise.
// -----------------------------------------------------------------------------

AuditSession makeSession({
  String uuid = 'uuid-1',
  int shopId = 7,
  AuditStatus status = AuditStatus.inProgress,
  int expectedCount = 100,
  double expectedWeightGrams = 1000.0,
  int scannedCount = 0,
  double scannedWeightGrams = 0.0,
  int progressPercent = 0,
  String channel = 'private-shop-audit.17',
  DateTime? startedAt,
  DateTime? completedAt,
  AuditReportSnapshot? reportSnapshot,
  String? notes,
}) {
  return AuditSession(
    uuid: uuid,
    shopId: shopId,
    status: status,
    expectedCount: expectedCount,
    expectedWeightGrams: expectedWeightGrams,
    scannedCount: scannedCount,
    scannedWeightGrams: scannedWeightGrams,
    progressPercent: progressPercent,
    channel: channel,
    startedAt: startedAt ?? DateTime(2026, 4, 22, 10, 0),
    completedAt: completedAt,
    notes: notes,
    startedBy: const ActorRef(id: 3, name: 'Ali'),
    reportSnapshot: reportSnapshot,
  );
}

AuditScan makeScan({
  required int id,
  AuditScanResult result = AuditScanResult.valid,
  String barcode = '7-ABCDEF00',
  String deviceLabel = 'Test',
  double? weightGrams = 1.0,
  DateTime? scannedAt,
}) {
  return AuditScan(
    id: id,
    result: result,
    barcode: barcode,
    deviceLabel: deviceLabel,
    scannedAt: scannedAt ?? DateTime(2026, 4, 22, 10, 5),
    weightGrams: weightGrams,
    shopProductId: result == AuditScanResult.notFound ? null : 482,
  );
}

AuditScanEvent makeScanEvent({
  int sessionId = 17,
  required int scanId,
  AuditScanResult result = AuditScanResult.valid,
  int scannedCount = 1,
  double scannedWeight = 1.0,
  String barcode = '7-FROMSERVER',
  String deviceLabel = 'Other Device',
  DateTime? scannedAt,
}) {
  return AuditScanEvent(
    sessionId: sessionId,
    scanId: scanId,
    result: result,
    scannedCount: scannedCount,
    scannedWeight: scannedWeight,
    barcode: barcode,
    deviceLabel: deviceLabel,
    scannedAt: scannedAt ?? DateTime(2026, 4, 22, 10, 6),
  );
}

// -----------------------------------------------------------------------------
// FakeAuditRepository — every method is a programmable slot returning Either.
// -----------------------------------------------------------------------------

class FakeAuditRepository implements AuditRepository {
  // Callable slots so tests can inspect argument values.
  FutureEither<Paginated<AuditSession>> Function({int page, String? status})?
  listHandler;
  FutureEither<AuditSession> Function({String? notes})? startHandler;
  FutureEither<AuditSession> Function(String uuid)? showHandler;
  FutureEither<ScanResponse> Function({
    required String uuid,
    required String barcode,
    required String deviceLabel,
    int? shopEmployeeId,
  })?
  recordScanHandler;
  FutureEither<AuditSession> Function(String uuid)? completeHandler;
  FutureEither<AuditReportSnapshot> Function(String uuid)? summaryHandler;
  FutureEither<Paginated<AuditSessionItem>> Function(String uuid, {int page})?
  missingHandler;
  FutureEither<Paginated<AuditScan>> Function(String uuid, {int page})?
  unexpectedHandler;

  // Call inspection.
  int recordScanCalls = 0;
  String? lastRecordedBarcode;
  String? lastRecordedDeviceLabel;
  int? lastRecordedShopEmployeeId;

  @override
  FutureEither<Paginated<AuditSession>> list({int page = 1, String? status}) {
    final h = listHandler;
    if (h != null) return h(page: page, status: status);
    return Future.value(
      const Right(
        Paginated<AuditSession>(
          items: [],
          currentPage: 1,
          perPage: 20,
          total: 0,
          lastPage: 1,
        ),
      ),
    );
  }

  @override
  FutureEither<AuditSession> start({String? notes}) {
    final h = startHandler;
    if (h != null) return h(notes: notes);
    return Future.value(Right(makeSession(notes: notes)));
  }

  @override
  FutureEither<AuditSession> show(String uuid) {
    final h = showHandler;
    if (h != null) return h(uuid);
    return Future.value(Right(makeSession(uuid: uuid)));
  }

  @override
  FutureEither<ScanResponse> recordScan({
    required String uuid,
    required String barcode,
    required String deviceLabel,
    int? shopEmployeeId,
  }) {
    recordScanCalls += 1;
    lastRecordedBarcode = barcode;
    lastRecordedDeviceLabel = deviceLabel;
    lastRecordedShopEmployeeId = shopEmployeeId;

    final h = recordScanHandler;
    if (h != null) {
      return h(
        uuid: uuid,
        barcode: barcode,
        deviceLabel: deviceLabel,
        shopEmployeeId: shopEmployeeId,
      );
    }
    return Future.value(
      Right(
        ScanResponse(
          scan: makeScan(id: 1, barcode: barcode, deviceLabel: deviceLabel),
          session: makeSession(scannedCount: 1, scannedWeightGrams: 1),
        ),
      ),
    );
  }

  @override
  FutureEither<AuditSession> complete(String uuid) {
    final h = completeHandler;
    if (h != null) return h(uuid);
    return Future.value(
      Right(
        makeSession(
          uuid: uuid,
          status: AuditStatus.completed,
          completedAt: DateTime(2026, 4, 22, 11, 0),
        ),
      ),
    );
  }

  @override
  FutureEither<AuditReportSnapshot> summary(String uuid) {
    final h = summaryHandler;
    if (h != null) return h(uuid);
    return Future.value(const Left(ServerFailure('not implemented')));
  }

  @override
  FutureEither<Paginated<AuditSessionItem>> missing(
    String uuid, {
    int page = 1,
  }) {
    final h = missingHandler;
    if (h != null) return h(uuid, page: page);
    return Future.value(
      const Right(
        Paginated<AuditSessionItem>(
          items: [],
          currentPage: 1,
          perPage: 20,
          total: 0,
          lastPage: 1,
        ),
      ),
    );
  }

  @override
  FutureEither<Paginated<AuditScan>> unexpected(String uuid, {int page = 1}) {
    final h = unexpectedHandler;
    if (h != null) return h(uuid, page: page);
    return Future.value(
      const Right(
        Paginated<AuditScan>(
          items: [],
          currentPage: 1,
          perPage: 20,
          total: 0,
          lastPage: 1,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FakeAuditRealtime — pushes events through a controllable broadcast stream.
// -----------------------------------------------------------------------------

class FakeAuditRealtime implements AuditRealtime {
  final _events = StreamController<AuditScanEvent>.broadcast();
  final _connection = StreamController<RealtimeConnectionState>.broadcast();

  int subscribeCalls = 0;
  int unsubscribeCalls = 0;
  int? lastSubscribedSessionId;

  void emit(AuditScanEvent event) => _events.add(event);

  void emitError(Object error) => _events.addError(error);

  @override
  Stream<AuditScanEvent> subscribe(int sessionId) {
    subscribeCalls += 1;
    lastSubscribedSessionId = sessionId;
    return _events.stream;
  }

  @override
  Future<void> unsubscribe(int sessionId) async {
    unsubscribeCalls += 1;
  }

  @override
  Stream<RealtimeConnectionState> get connectionState => _connection.stream;

  Future<void> close() async {
    await _events.close();
    await _connection.close();
  }
}
