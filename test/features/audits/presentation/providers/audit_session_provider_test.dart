import 'package:arraf_shop/src/features/audits/data/audit_failures.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan_result.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '_fakes.dart';

void main() {
  late FakeAuditRepository repo;
  late FakeAuditRealtime realtime;
  late AuditSessionProvider provider;

  setUp(() {
    repo = FakeAuditRepository();
    realtime = FakeAuditRealtime();
    provider = AuditSessionProvider(
      repository: repo,
      realtime: realtime,
      deviceLabel: 'iPad — Floor 1',
      shopEmployeeId: 11,
    );
  });

  tearDown(() async {
    provider.dispose();
    await realtime.close();
  });

  // ---------------------------------------------------------------------------
  // join
  // ---------------------------------------------------------------------------

  group('join', () {
    test('loads and exposes the session on success', () async {
      repo.showHandler = (uuid) async => Right(
        SessionWithScans(session: makeSession(uuid: uuid, scannedCount: 5)),
      );

      await provider.join('uuid-xyz');

      expect(provider.status, AppStatus.success);
      expect(provider.session?.uuid, 'uuid-xyz');
      expect(provider.session?.scannedCount, 5);
    });

    test('sets failure + errorMessage on Left', () async {
      repo.showHandler = (uuid) async => const Left(ServerFailure('not found'));

      await provider.join('nope');

      expect(provider.status, AppStatus.failure);
      expect(provider.errorMessage, 'not found');
      expect(provider.session, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // scan — optimistic + reconcile
  // ---------------------------------------------------------------------------

  group('scan (optimistic)', () {
    setUp(() async {
      repo.showHandler = (uuid) async => Right(SessionWithScans(session: makeSession(uuid: uuid)));
      await provider.join('uuid-1');
    });

    test(
      'happy path: placeholder appears immediately, then reconciles',
      () async {
        final serverScan = makeScan(
          id: 912,
          barcode: '7-A1B2C3D4',
          result: AuditScanResult.valid,
        );
        repo.recordScanHandler =
            ({
              required String uuid,
              required String barcode,
              required String deviceLabel,
              int? shopEmployeeId,
            }) async => Right(
              ScanResponse(
                scan: serverScan,
                session: makeSession(
                  uuid: uuid,
                  scannedCount: 1,
                  scannedWeightGrams: 1,
                  progressPercent: 1,
                ),
              ),
            );

        final snapshots = <List<AuditScan>>[];
        provider.addListener(() {
          snapshots.add(List<AuditScan>.from(provider.feed));
        });

        await provider.scan('7-A1B2C3D4');

        // First snapshot is the optimistic placeholder — id must be negative.
        expect(snapshots.first, hasLength(1));
        expect(snapshots.first.first.id, lessThan(0));
        expect(snapshots.first.first.barcode, '7-A1B2C3D4');

        // Final feed contains exactly one scan, the server-assigned one.
        expect(provider.feed, hasLength(1));
        expect(provider.feed.single.id, 912);
        expect(provider.scanStatus, AppStatus.success);
        expect(provider.session?.scannedCount, 1);
      },
    );

    test(
      'failure removes the optimistic entry and surfaces the failure',
      () async {
        repo.recordScanHandler =
            ({
              required String uuid,
              required String barcode,
              required String deviceLabel,
              int? shopEmployeeId,
            }) async => const Left(ServerFailure('server said no'));

        await provider.scan('bad');

        expect(provider.feed, isEmpty);
        expect(provider.scanStatus, AppStatus.failure);
        expect(provider.errorMessage, 'server said no');
      },
    );

    test(
      'conflict (409) bumps duplicateTick and keeps scanStatus success',
      () async {
        repo.recordScanHandler =
            ({
              required String uuid,
              required String barcode,
              required String deviceLabel,
              int? shopEmployeeId,
            }) async => const Left(ConflictFailure('already scanned'));

        final before = provider.duplicateTick;
        await provider.scan('dup-barcode');

        expect(provider.feed, isEmpty);
        expect(provider.scanStatus, AppStatus.success);
        expect(provider.duplicateTick, before + 1);
      },
    );

    test('server-returned duplicate is kept out of the feed, toast only',
        () async {
      final dupScan = makeScan(
        id: 42,
        barcode: 'same-barcode',
        result: AuditScanResult.duplicate,
      );
      repo.recordScanHandler =
          ({
            required String uuid,
            required String barcode,
            required String deviceLabel,
            int? shopEmployeeId,
          }) async =>
              Right(ScanResponse(scan: dupScan, session: provider.session!));

      final before = provider.duplicateTick;
      await provider.scan('same-barcode');

      expect(provider.feed, isEmpty);
      expect(provider.duplicateTick, before + 1);
      expect(provider.recordedBarcodes, contains('same-barcode'));
    });

    test(
      'local-first: repeat of a known barcode skips the server entirely',
      () async {
        var calls = 0;
        repo.recordScanHandler =
            ({
              required String uuid,
              required String barcode,
              required String deviceLabel,
              int? shopEmployeeId,
            }) async {
              calls += 1;
              return Right(
                ScanResponse(
                  scan: makeScan(id: 100, barcode: barcode),
                  session: provider.session!,
                ),
              );
            };

        await provider.scan('X');
        expect(calls, 1);

        final before = provider.duplicateTick;
        await provider.scan('X');
        expect(calls, 1, reason: 'repeat must not hit the repository');
        expect(provider.duplicateTick, before + 1);
      },
    );

    test('passes deviceLabel and shopEmployeeId to the repository', () async {
      repo.recordScanHandler =
          ({
            required String uuid,
            required String barcode,
            required String deviceLabel,
            int? shopEmployeeId,
          }) async => Right(
            ScanResponse(
              scan: makeScan(id: 1, barcode: barcode, deviceLabel: deviceLabel),
              session: provider.session!,
            ),
          );

      await provider.scan('X');

      expect(repo.lastRecordedDeviceLabel, 'iPad — Floor 1');
      expect(repo.lastRecordedShopEmployeeId, 11);
    });

    test(
      'passes null shopEmployeeId when the caller is a ShopEmployee',
      () async {
        final employeeProvider = AuditSessionProvider(
          repository: repo,
          realtime: realtime,
          deviceLabel: 'Emp Device',
          shopEmployeeId: null,
        );
        repo.showHandler = (uuid) async => Right(SessionWithScans(session: makeSession(uuid: uuid)));
        await employeeProvider.join('uuid-1');

        repo.recordScanHandler =
            ({
              required String uuid,
              required String barcode,
              required String deviceLabel,
              int? shopEmployeeId,
            }) async => Right(
              ScanResponse(
                scan: makeScan(id: 2),
                session: employeeProvider.session!,
              ),
            );

        await employeeProvider.scan('Y');

        expect(repo.lastRecordedShopEmployeeId, isNull);
        employeeProvider.dispose();
      },
    );

    test('scan without a loaded session fails fast', () async {
      final empty = AuditSessionProvider(
        repository: repo,
        realtime: realtime,
        deviceLabel: 'd',
      );

      await empty.scan('x');

      expect(empty.scanStatus, AppStatus.failure);
      expect(empty.errorMessage, isNotNull);
      expect(repo.recordScanCalls, 0);
      empty.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // complete
  // ---------------------------------------------------------------------------

  group('complete', () {
    test('updates the session with the completed payload', () async {
      repo.showHandler = (uuid) async => Right(SessionWithScans(session: makeSession(uuid: uuid)));
      await provider.join('uuid-1');

      repo.completeHandler =
          (uuid) async =>
              Right(makeSession(uuid: uuid, status: AuditStatus.completed));

      await provider.complete();

      expect(provider.completeStatus, AppStatus.success);
      expect(provider.session?.status, AuditStatus.completed);
    });
  });

  // ---------------------------------------------------------------------------
  // subscribe + realtime merge
  // ---------------------------------------------------------------------------

  group('realtime', () {
    setUp(() async {
      repo.showHandler = (uuid) async => Right(
        SessionWithScans(
          session: makeSession(uuid: uuid, channel: 'private-shop-audit.17'),
        ),
      );
      await provider.join('uuid-1');
    });

    test('subscribe derives sessionId from the channel string', () {
      final ok = provider.subscribe();
      expect(ok, isTrue);
      expect(realtime.subscribeCalls, 1);
      expect(realtime.lastSubscribedSessionId, 17);
    });

    test('subscribe is a no-op when called twice', () {
      provider.subscribe();
      provider.subscribe();
      expect(realtime.subscribeCalls, 1);
    });

    test(
      'realtime event for an unknown scan is prepended to the feed',
      () async {
        provider.subscribe();

        realtime.emit(
          makeScanEvent(
            scanId: 500,
            barcode: 'FROM-SERVER',
            scannedCount: 1,
            scannedWeight: 2.5,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(provider.feed, hasLength(1));
        expect(provider.feed.single.id, 500);
        expect(provider.feed.single.barcode, 'FROM-SERVER');
        // Counters updated from the event payload.
        expect(provider.session?.scannedCount, 1);
        expect(provider.session?.scannedWeightGrams, 2.5);
      },
    );

    test('realtime event for an already-known scan id is ignored', () async {
      // Pre-seed the feed by recording a scan with id=912.
      repo.recordScanHandler =
          ({
            required String uuid,
            required String barcode,
            required String deviceLabel,
            int? shopEmployeeId,
          }) async => Right(
            ScanResponse(
              scan: makeScan(id: 912, barcode: barcode),
              session: provider.session!,
            ),
          );
      await provider.scan('7-A1B2C3D4');
      expect(provider.feed.single.id, 912);

      provider.subscribe();

      // Server echoes the same scan via realtime — must dedupe.
      realtime.emit(makeScanEvent(scanId: 912, barcode: '7-A1B2C3D4'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.feed, hasLength(1));
    });

    test('unsubscribe cancels and tells the realtime service', () async {
      provider.subscribe();
      await provider.unsubscribe();

      expect(realtime.unsubscribeCalls, 1);

      // Further events must not be buffered after unsubscribe.
      realtime.emit(makeScanEvent(scanId: 999));
      await Future<void>.delayed(Duration.zero);
      expect(provider.feed.any((s) => s.id == 999), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Feed cap
  // ---------------------------------------------------------------------------

  group('feed buffer', () {
    test('caps at 20 newest entries (mix of local + realtime)', () async {
      repo.showHandler = (uuid) async => Right(SessionWithScans(session: makeSession(uuid: uuid)));
      await provider.join('uuid-1');
      provider.subscribe();

      for (var i = 1; i <= 25; i++) {
        realtime.emit(makeScanEvent(scanId: i));
      }
      await Future<void>.delayed(Duration.zero);

      expect(provider.feed.length, AuditSessionProvider.maxFeedSize);
      // Newest-first: top is the last emitted event.
      expect(provider.feed.first.id, 25);
      // Oldest kept is 25 - 20 + 1 = 6.
      expect(provider.feed.last.id, 6);
    });
  });
}
