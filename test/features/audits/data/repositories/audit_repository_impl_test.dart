import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:arraf_shop/src/features/audits/data/audit_failures.dart';
import 'package:arraf_shop/src/features/audits/data/repositories/audit_repository_impl.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan_result.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session_item.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditRepositoryImpl', () {
    group('start', () {
      test('returns Right(AuditSession) for a canned 201 response', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 201,
              body: _envelope(_sessionJson),
            );
          },
        );
        final repo = AuditRepositoryImpl(dio: dio);

        final result = await repo.start(notes: 'Q2 audit');

        final session = _expectRight<AuditSession>(result);
        expect(session.uuid, _sessionJson['uuid']);
        expect(session.shopId, 7);
        expect(session.status, AuditStatus.inProgress);
        expect(session.expectedCount, 128);
        expect(session.expectedWeightGrams, 4213.517);
        expect(session.scannedCount, 0);
        expect(session.progressPercent, 0);
        expect(session.notes, 'Q2 audit');
        expect(session.channel, 'private-shop-audit.17');
        expect(session.startedBy?.id, 3);
        expect(session.startedBy?.name, 'Ali');

        expect(captured?.method, 'POST');
        expect(captured?.path, 'shops/my/audits');
        expect(captured?.data, {'notes': 'Q2 audit'});
      });

      test('omits notes from the body when null', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 201,
              body: _envelope(_sessionJson),
            );
          },
        );

        await AuditRepositoryImpl(dio: dio).start();

        expect(captured?.data, <String, dynamic>{});
      });
    });

    group('list', () {
      test('parses the paginated envelope and forwards filters', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 200,
              body: {
                'status': 'success',
                'message': 'Success',
                'data': [_sessionJson, _sessionJson],
                'meta': {
                  'current_page': 2,
                  'per_page': 20,
                  'total': 42,
                  'last_page': 3,
                },
              },
            );
          },
        );

        final result = await AuditRepositoryImpl(
          dio: dio,
        ).list(page: 2, status: 'in_progress');

        final page = _expectRight<Paginated<AuditSession>>(result);
        expect(page.items, hasLength(2));
        expect(page.currentPage, 2);
        expect(page.perPage, 20);
        expect(page.total, 42);
        expect(page.lastPage, 3);
        expect(page.hasMore, isTrue);

        expect(captured?.method, 'GET');
        expect(captured?.path, 'shops/my/audits');
        expect(captured?.queryParameters, {'page': 2, 'status': 'in_progress'});
      });

      test('drops the status filter when null', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 200,
              body: {
                'status': 'success',
                'message': 'Success',
                'data': <Map<String, dynamic>>[],
                'meta': {
                  'current_page': 1,
                  'per_page': 20,
                  'total': 0,
                  'last_page': 1,
                },
              },
            );
          },
        );

        await AuditRepositoryImpl(dio: dio).list();

        expect(captured?.queryParameters, {'page': 1});
      });
    });

    group('show', () {
      test('GETs the session by uuid and parses it', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 200,
              body: _envelope(_sessionJson),
            );
          },
        );

        final result = await AuditRepositoryImpl(dio: dio).show('abc-uuid');

        final session = _expectRight<AuditSession>(result);
        expect(session.uuid, _sessionJson['uuid']);
        expect(captured?.method, 'GET');
        expect(captured?.path, 'shops/my/audits/abc-uuid');
      });
    });

    group('recordScan', () {
      test('POSTs barcode + device label and parses both resources', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 201,
              body: {
                'status': 'success',
                'message': 'Scan recorded.',
                'data': {'scan': _scanJson, 'session': _sessionJson},
              },
            );
          },
        );

        final result = await AuditRepositoryImpl(dio: dio).recordScan(
          uuid: 'abc-uuid',
          barcode: '7-A1B2C3D4',
          deviceLabel: 'iPad — Floor 1',
          shopEmployeeId: 11,
        );

        final pair = _expectRight<ScanResponse>(result);
        expect(pair.scan.id, 912);
        expect(pair.scan.result, AuditScanResult.valid);
        expect(pair.scan.barcode, '7-A1B2C3D4');
        expect(pair.scan.shopEmployeeId, 11);
        expect(pair.scan.weightGrams, 3.215);
        expect(pair.session.uuid, _sessionJson['uuid']);

        expect(captured?.method, 'POST');
        expect(captured?.path, 'shops/my/audits/abc-uuid/scans');
        expect(captured?.data, {
          'barcode': '7-A1B2C3D4',
          'device_label': 'iPad — Floor 1',
          'shop_employee_id': 11,
        });
      });

      test('omits shop_employee_id when null (employee caller)', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 201,
              body: {
                'status': 'success',
                'message': 'Scan recorded.',
                'data': {'scan': _scanJson, 'session': _sessionJson},
              },
            );
          },
        );

        await AuditRepositoryImpl(dio: dio).recordScan(
          uuid: 'abc-uuid',
          barcode: '7-A1B2C3D4',
          deviceLabel: 'iPad — Floor 1',
        );

        expect(captured?.data, {
          'barcode': '7-A1B2C3D4',
          'device_label': 'iPad — Floor 1',
        });
      });
    });

    group('complete', () {
      test('POSTs to /complete and parses session', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 200,
              body: _envelope({
                ..._sessionJson,
                'status': 'completed',
                'completed_at': '2026-04-22T11:00:00+00:00',
                'completed_by': {'id': 3, 'name': 'Ali'},
                'report_snapshot': _reportSnapshotJson,
              }),
            );
          },
        );

        final result = await AuditRepositoryImpl(dio: dio).complete('abc-uuid');

        final session = _expectRight<AuditSession>(result);
        expect(session.status, AuditStatus.completed);
        expect(session.completedAt, isNotNull);
        expect(session.completedBy?.id, 3);
        expect(session.reportSnapshot?.expectedCount, 128);
        expect(session.reportSnapshot?.scannedCount, 125);
        expect(session.reportSnapshot?.countDifference, -3);
        expect(session.reportSnapshot?.weightDifference, -101.407);

        expect(captured?.method, 'POST');
        expect(captured?.path, 'shops/my/audits/abc-uuid/complete');
      });
    });

    group('summary', () {
      test('parses snapshot directly under data', () async {
        final dio = _stubbedDio(
          onRequest:
              (_) => _jsonResponse(
                statusCode: 200,
                body: _envelope(_reportSnapshotJson),
              ),
        );

        final result = await AuditRepositoryImpl(dio: dio).summary('abc-uuid');

        final snap = _expectRight<AuditReportSnapshot>(result);
        expect(snap.expectedCount, 128);
        expect(snap.missingCount, 4);
        expect(snap.unexpectedCount, 1);
      });
    });

    group('missing', () {
      test('parses paginated session items', () async {
        RequestOptions? captured;
        final dio = _stubbedDio(
          onRequest: (options) {
            captured = options;
            return _jsonResponse(
              statusCode: 200,
              body: {
                'status': 'success',
                'message': 'Success',
                'data': [_sessionItemJson],
                'meta': {
                  'current_page': 1,
                  'per_page': 20,
                  'total': 1,
                  'last_page': 1,
                },
              },
            );
          },
        );

        final result = await AuditRepositoryImpl(
          dio: dio,
        ).missing('abc-uuid', page: 1);

        final page = _expectRight<Paginated<AuditSessionItem>>(result);
        expect(page.items, hasLength(1));
        expect(page.items.first.barcode, '7-A1B2C3D4');
        expect(page.items.first.scannedAt, isNull);
        expect(captured?.path, 'shops/my/audits/abc-uuid/missing');
      });
    });

    group('unexpected', () {
      test('parses paginated scans', () async {
        final dio = _stubbedDio(
          onRequest:
              (_) => _jsonResponse(
                statusCode: 200,
                body: {
                  'status': 'success',
                  'message': 'Success',
                  'data': [
                    {
                      ..._scanJson,
                      'result': 'unexpected',
                      'shop_product_id': null,
                    },
                  ],
                  'meta': {
                    'current_page': 1,
                    'per_page': 20,
                    'total': 1,
                    'last_page': 1,
                  },
                },
              ),
        );

        final result = await AuditRepositoryImpl(
          dio: dio,
        ).unexpected('abc-uuid');

        final page = _expectRight<Paginated<AuditScan>>(result);
        expect(page.items, hasLength(1));
        expect(page.items.first.result, AuditScanResult.unexpected);
      });
    });

    group('error mapping', () {
      test('401 → AuthFailure', () async {
        final failure = await _failureFor(401, {
          'status': 'error',
          'message': 'Unauthenticated.',
        });
        expect(failure, isA<AuthFailure>());
        expect(failure.message, 'Unauthenticated.');
      });

      test('403 → ForbiddenFailure', () async {
        final failure = await _failureFor(403, {
          'status': 'error',
          'message': 'Forbidden.',
        });
        expect(failure, isA<ForbiddenFailure>());
      });

      test('404 → NotFoundFailure', () async {
        final failure = await _failureFor(404, {
          'status': 'error',
          'message': 'Not found.',
        });
        expect(failure, isA<NotFoundFailure>());
      });

      test('409 → ConflictFailure', () async {
        final failure = await _failureFor(409, {
          'status': 'error',
          'message': 'Session not in progress.',
        });
        expect(failure, isA<ConflictFailure>());
      });

      test('422 → ValidationFailure with field errors', () async {
        final failure = await _failureFor(422, {
          'status': 'error',
          'message': 'The given data was invalid.',
          'errors': {
            'barcode': ['The barcode field is required.'],
            'device_label': ['The device label field is required.'],
          },
        });
        expect(failure, isA<ValidationFailure>());
        final v = failure as ValidationFailure;
        expect(v.errors['barcode']?.first, 'The barcode field is required.');
        expect(
          v.firstFor('device_label'),
          'The device label field is required.',
        );
      });

      test('5xx → ServerFailure', () async {
        final failure = await _failureFor(500, {
          'status': 'error',
          'message': 'Server boom.',
        });
        expect(failure, isA<ServerFailure>());
      });
    });
  });
}

// --- Canonical JSON fixtures (mirror contract §3) ---

const Map<String, dynamic> _sessionJson = {
  'uuid': '9f4a3b82-aaaa-bbbb-cccc-1234567890ab',
  'shop_id': 7,
  'status': 'in_progress',
  'expected_count': 128,
  'expected_weight_grams': 4213.517,
  'scanned_count': 0,
  'scanned_weight_grams': 0,
  'progress_percent': 0,
  'started_at': '2026-04-22T10:14:05+00:00',
  'completed_at': null,
  'started_by': {'id': 3, 'name': 'Ali'},
  'completed_by': null,
  'notes': 'Q2 audit',
  'channel': 'private-shop-audit.17',
  'report_snapshot': null,
  'created_at': '2026-04-22T10:14:05+00:00',
  'updated_at': '2026-04-22T10:14:05+00:00',
};

const Map<String, dynamic> _scanJson = {
  'id': 912,
  'result': 'valid',
  'barcode_scanned': '7-A1B2C3D4',
  'shop_product_id': 482,
  'shop_employee_id': 11,
  'device_label': 'iPad — Floor 1',
  'weight_grams': 3.215,
  'scanned_at': '2026-04-22T10:19:07+00:00',
};

const Map<String, dynamic> _sessionItemJson = {
  'id': 2201,
  'shop_product_id': 482,
  'barcode': '7-A1B2C3D4',
  'sku': 'SKU-7-A1B2C3',
  'name': '22K bracelet',
  'weight_grams': 3.215,
  'scanned_at': null,
};

const Map<String, dynamic> _reportSnapshotJson = {
  'expected_count': 128,
  'scanned_count': 125,
  'count_difference': -3,
  'expected_weight': 4213.517,
  'scanned_weight': 4112.110,
  'weight_difference': -101.407,
  'missing_count': 4,
  'unexpected_count': 1,
  'not_found_count': 0,
};

Map<String, dynamic> _envelope(Map<String, dynamic> data) => {
  'status': 'success',
  'message': 'Success',
  'data': data,
};

T _expectRight<T>(dynamic either) {
  return either.fold<T>(
    (l) => fail('expected Right but got Left($l)'),
    (r) => r as T,
  );
}

Future<Failure> _failureFor(int status, Object body) async {
  final dio = _stubbedDio(
    onRequest: (_) => _jsonResponse(statusCode: status, body: body),
  );
  final result = await AuditRepositoryImpl(dio: dio).show('any');
  return result.fold((l) => l, (_) => fail('expected Left for $status'));
}

// --- Test stubs ---

Dio _stubbedDio({required ResponseBody Function(RequestOptions) onRequest}) {
  // Default validateStatus (200–299) so non-2xx responses surface as
  // DioException — that's the path the repo's failure mapper catches.
  final dio = Dio(BaseOptions(baseUrl: 'https://stub.local/api/'));
  dio.httpClientAdapter = _FakeAdapter(onRequest);
  return dio;
}

ResponseBody _jsonResponse({required int statusCode, required Object body}) {
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  return ResponseBody.fromBytes(
    bytes,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final ResponseBody Function(RequestOptions) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}
