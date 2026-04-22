import 'dart:convert';
import 'dart:typed_data';

import 'package:arraf_shop/src/features/audits/data/repositories/audit_repository_impl.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan_result.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'presentation/providers/_fakes.dart' show FakeAuditRealtime;

/// End-to-end integration for the audit flow, exercising real providers over
/// a real [AuditRepositoryImpl] backed by a stubbed Dio (so no real network,
/// no real Pusher).
///
/// Scope (per Track I §4):
///   1. post-login state — we assume an authenticated Dio (token injected by
///      Track A's interceptor in production; here we just hand the repository
///      a pre-configured Dio)
///   2. start a new session  (POST /shops/my/audits)
///   3. scan a valid barcode (POST /shops/my/audits/{uuid}/scans)
///   4. scan a duplicate barcode (same endpoint; server returns result=duplicate)
///   5. complete the session (POST /shops/my/audits/{uuid}/complete)
///
/// Pusher is represented by the domain [AuditRealtime] abstraction, faked
/// here — the E2E mirrors a session that uses realtime but where the server
/// never echoes back (no events emitted). Dedup / merge logic has its own
/// tests in [AuditSessionProvider] unit tests.
void main() {
  late _ScriptedAdapter adapter;
  late Dio dio;
  late AuditRepositoryImpl repository;
  late FakeAuditRealtime realtime;

  setUp(() {
    adapter = _ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://e2e.stub/api/'))
      ..httpClientAdapter = adapter;
    repository = AuditRepositoryImpl(dio: dio);
    realtime = FakeAuditRealtime();
  });

  tearDown(() async {
    await realtime.close();
  });

  test(
    'login → start → scan valid → scan duplicate → complete is end-to-end coherent',
    () async {
      // ── Script the backend ────────────────────────────────────────────────
      const uuid = 'e2e-uuid-0001';
      adapter
        ..onPost(
          'shops/my/audits',
          respondWith: _envelope(
            _sessionJson(
              uuid: uuid,
              status: 'in_progress',
              scannedCount: 0,
              scannedWeightGrams: 0,
              progressPercent: 0,
            ),
          ),
          statusCode: 201,
        )
        ..onPost(
          'shops/my/audits/$uuid/scans',
          respondWith: _envelope({
            'scan': _scanJson(
              id: 1001,
              result: 'valid',
              barcode: '7-VALID00',
              weightGrams: 3.215,
            ),
            'session': _sessionJson(
              uuid: uuid,
              status: 'in_progress',
              scannedCount: 1,
              scannedWeightGrams: 3.215,
              progressPercent: 1,
            ),
          }),
          statusCode: 201,
          matchCall: 1, // first scan POST
        )
        ..onPost(
          'shops/my/audits/$uuid/scans',
          respondWith: _envelope({
            'scan': _scanJson(
              id: 1002,
              result: 'duplicate',
              barcode: '7-VALID00',
              weightGrams: 3.215,
            ),
            'session': _sessionJson(
              uuid: uuid,
              status: 'in_progress',
              scannedCount: 1,
              scannedWeightGrams: 3.215,
              progressPercent: 1,
            ),
          }),
          statusCode: 201,
          matchCall: 2, // second scan POST
        )
        ..onPost(
          'shops/my/audits/$uuid/complete',
          respondWith: _envelope(
            _sessionJson(
              uuid: uuid,
              status: 'completed',
              scannedCount: 1,
              scannedWeightGrams: 3.215,
              progressPercent: 1,
              completedAt: '2026-04-22T11:00:00+00:00',
            ),
          ),
          statusCode: 200,
        )
        ..onGet(
          'shops/my/audits/$uuid',
          respondWith: _envelope(
            _sessionJson(
              uuid: uuid,
              status: 'in_progress',
              scannedCount: 0,
              scannedWeightGrams: 0,
              progressPercent: 0,
            ),
          ),
          statusCode: 200,
        );

      // ── Wire providers ────────────────────────────────────────────────────
      final listProvider = AuditsListProvider(repository: repository);
      final sessionProvider = AuditSessionProvider(
        repository: repository,
        realtime: realtime,
        deviceLabel: 'iPad — Floor 1',
        shopEmployeeId: 11,
      );

      addTearDown(listProvider.dispose);
      addTearDown(sessionProvider.dispose);

      // ── 1. Start a new session ────────────────────────────────────────────
      await listProvider.startNew(notes: 'E2E audit');
      expect(listProvider.startStatus, AppStatus.success);
      expect(listProvider.sessions, hasLength(1));
      final started = listProvider.sessions.first;
      expect(started.uuid, uuid);
      expect(started.status, AuditStatus.inProgress);

      // ── 2. Join the session (navigation landing) ──────────────────────────
      await sessionProvider.join(started.uuid);
      expect(sessionProvider.status, AppStatus.success);
      expect(sessionProvider.session?.uuid, uuid);

      // Subscribe to realtime (no events scripted; dedupe covered in unit tests).
      sessionProvider.subscribe();
      expect(realtime.subscribeCalls, 1);
      expect(realtime.lastSubscribedSessionId, 17);

      // ── 3. Scan valid ─────────────────────────────────────────────────────
      await sessionProvider.scan('7-VALID00');
      expect(sessionProvider.scanStatus, AppStatus.success);
      expect(sessionProvider.feed, hasLength(1));
      expect(sessionProvider.feed.single.id, 1001);
      expect(sessionProvider.feed.single.result, AuditScanResult.valid);
      expect(sessionProvider.session?.scannedCount, 1);

      // ── 4. Scan duplicate (same barcode) ──────────────────────────────────
      await sessionProvider.scan('7-VALID00');
      expect(sessionProvider.scanStatus, AppStatus.success);
      // Both scans appear in the feed, newest (duplicate) first.
      expect(sessionProvider.feed, hasLength(2));
      expect(sessionProvider.feed.first.id, 1002);
      expect(sessionProvider.feed.first.result, AuditScanResult.duplicate);
      expect(sessionProvider.feed.last.id, 1001);
      // Server held scanned_count at 1 for the duplicate.
      expect(sessionProvider.session?.scannedCount, 1);

      // ── 5. Complete the session ───────────────────────────────────────────
      await sessionProvider.complete();
      expect(sessionProvider.completeStatus, AppStatus.success);
      expect(sessionProvider.session?.status, AuditStatus.completed);
      expect(sessionProvider.session?.completedAt, isNotNull);

      // ── Final cross-checks ────────────────────────────────────────────────
      expect(adapter.requestLog.map((r) => '${r.method} ${r.path}').toList(), [
        'POST shops/my/audits',
        'GET shops/my/audits/$uuid',
        'POST shops/my/audits/$uuid/scans',
        'POST shops/my/audits/$uuid/scans',
        'POST shops/my/audits/$uuid/complete',
      ]);

      // Owner-mode: shop_employee_id is forwarded on scan POSTs.
      final scanBodies =
          adapter.requestLog
              .where((r) => r.method == 'POST' && r.path.endsWith('/scans'))
              .map((r) => r.body)
              .toList();
      expect(scanBodies, hasLength(2));
      for (final body in scanBodies) {
        expect(body['barcode'], '7-VALID00');
        expect(body['device_label'], 'iPad — Floor 1');
        expect(body['shop_employee_id'], 11);
      }
    },
  );
}

// =============================================================================
//  Scripted Dio adapter
// =============================================================================

class _RequestLogEntry {
  _RequestLogEntry({
    required this.method,
    required this.path,
    required this.body,
  });
  final String method;
  final String path;
  final Map<String, dynamic> body;
}

class _ScriptedRoute {
  _ScriptedRoute({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.body,
    this.matchCall,
  });
  final String method;
  final String path;
  final int statusCode;
  final Map<String, dynamic> body;
  final int? matchCall; // 1-based; null = match any call count
  int hitCount = 0;
}

class _ScriptedAdapter implements HttpClientAdapter {
  final List<_ScriptedRoute> _routes = [];
  final List<_RequestLogEntry> requestLog = [];
  final Map<String, int> _callCounts = {};

  void onPost(
    String path, {
    required Map<String, dynamic> respondWith,
    required int statusCode,
    int? matchCall,
  }) {
    _routes.add(
      _ScriptedRoute(
        method: 'POST',
        path: path,
        statusCode: statusCode,
        body: respondWith,
        matchCall: matchCall,
      ),
    );
  }

  void onGet(
    String path, {
    required Map<String, dynamic> respondWith,
    required int statusCode,
  }) {
    _routes.add(
      _ScriptedRoute(
        method: 'GET',
        path: path,
        statusCode: statusCode,
        body: respondWith,
      ),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    _callCounts[key] = (_callCounts[key] ?? 0) + 1;
    final thisCall = _callCounts[key]!;

    Map<String, dynamic> bodyMap;
    final raw = options.data;
    if (raw is Map<String, dynamic>) {
      bodyMap = raw;
    } else if (raw == null) {
      bodyMap = const {};
    } else {
      bodyMap = {'_raw': raw.toString()};
    }

    requestLog.add(
      _RequestLogEntry(
        method: options.method,
        path: options.path,
        body: bodyMap,
      ),
    );

    final route = _routes.firstWhere(
      (r) =>
          r.method == options.method &&
          r.path == options.path &&
          (r.matchCall == null || r.matchCall == thisCall),
      orElse:
          () =>
              throw StateError(
                'No scripted response for $key (call #$thisCall). '
                'Registered: ${_routes.map((r) => "${r.method} ${r.path}").toList()}',
              ),
    );
    route.hitCount += 1;

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(route.body)));
    return ResponseBody.fromBytes(
      bytes,
      route.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// =============================================================================
//  JSON fixtures (mirror contract §3)
// =============================================================================

Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
  'status': 'success',
  'message': 'ok',
  'data': data,
};

Map<String, dynamic> _sessionJson({
  required String uuid,
  required String status,
  required int scannedCount,
  required double scannedWeightGrams,
  required int progressPercent,
  String? completedAt,
}) {
  return {
    'uuid': uuid,
    'shop_id': 7,
    'status': status,
    'expected_count': 128,
    'expected_weight_grams': 4213.517,
    'scanned_count': scannedCount,
    'scanned_weight_grams': scannedWeightGrams,
    'progress_percent': progressPercent,
    'started_at': '2026-04-22T10:14:05+00:00',
    'completed_at': completedAt,
    'started_by': {'id': 3, 'name': 'Ali'},
    'completed_by': completedAt == null ? null : {'id': 3, 'name': 'Ali'},
    'notes': 'E2E audit',
    'channel': 'private-shop-audit.17',
    'report_snapshot': null,
    'created_at': '2026-04-22T10:14:05+00:00',
    'updated_at': '2026-04-22T10:19:12+00:00',
  };
}

Map<String, dynamic> _scanJson({
  required int id,
  required String result,
  required String barcode,
  double? weightGrams,
}) {
  return {
    'id': id,
    'result': result,
    'barcode_scanned': barcode,
    'shop_product_id': result == 'not_found' ? null : 482,
    'shop_employee_id': 11,
    'device_label': 'iPad — Floor 1',
    'weight_grams': weightGrams,
    'scanned_at': '2026-04-22T10:19:07+00:00',
  };
}
