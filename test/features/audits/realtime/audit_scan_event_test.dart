import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan_result.dart';
import 'package:arraf_shop/src/features/audits/domain/realtime/audit_realtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditScanEvent.fromMap', () {
    final validPayload = <String, dynamic>{
      'session_id': 17,
      'scan_id': 912,
      'result': 'valid',
      'scanned_count': 42,
      'scanned_weight': 1323.26,
      'barcode': '7-A1B2C3D4',
      'device_label': 'iPad — Floor 1',
      'scanned_at': '2026-04-22T10:19:07+00:00',
    };

    test('parses the contract payload', () {
      final event = AuditScanEvent.fromMap(validPayload);

      expect(event.sessionId, 17);
      expect(event.scanId, 912);
      expect(event.result, AuditScanResult.valid);
      expect(event.scannedCount, 42);
      expect(event.scannedWeight, 1323.26);
      expect(event.barcode, '7-A1B2C3D4');
      expect(event.deviceLabel, 'iPad — Floor 1');
      expect(event.scannedAt.toUtc(), DateTime.utc(2026, 4, 22, 10, 19, 7));
    });

    test('accepts snake_case scan results including not_found', () {
      final event = AuditScanEvent.fromMap({
        ...validPayload,
        'result': 'not_found',
      });
      expect(event.result, AuditScanResult.notFound);
    });

    test('throws FormatException on unknown result', () {
      expect(
        () => AuditScanEvent.fromMap({...validPayload, 'result': 'bogus'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on missing required fields', () {
      final missing = Map<String, dynamic>.from(validPayload)
        ..remove('barcode');
      expect(() => AuditScanEvent.fromMap(missing), throwsA(anything));
    });

    test('coerces integer-valued weight to double', () {
      final event = AuditScanEvent.fromMap({
        ...validPayload,
        'scanned_weight': 1000,
      });
      expect(event.scannedWeight, 1000.0);
    });

    test('equatable by value', () {
      final a = AuditScanEvent.fromMap(validPayload);
      final b = AuditScanEvent.fromMap(validPayload);
      expect(a, equals(b));
    });
  });
}
