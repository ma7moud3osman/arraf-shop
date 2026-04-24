import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_summary_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '_fakes.dart';

const _snapshot = AuditReportSnapshot(
  expectedCount: 100,
  scannedCount: 42,
  countDifference: -58,
  expectedWeight: 1000,
  scannedWeight: 420,
  weightDifference: -580,
  missingCount: 58,
  unexpectedCount: 1,
  notFoundCount: 0,
);

void main() {
  late FakeAuditRepository repo;
  late AuditSummaryProvider provider;

  setUp(() {
    repo = FakeAuditRepository();
    provider = AuditSummaryProvider(repository: repo);
  });

  tearDown(() => provider.dispose());

  test('initial state is AppStatus.initial with no snapshot', () {
    expect(provider.status, AppStatus.initial);
    expect(provider.snapshot, isNull);
  });

  test('load: success exposes the snapshot', () async {
    repo.summaryHandler = (uuid) async => const Right(_snapshot);

    await provider.load('uuid-1');

    expect(provider.status, AppStatus.success);
    expect(provider.snapshot?.scannedCount, 42);
    expect(provider.snapshot?.missingCount, 58);
  });

  test('load: failure surfaces the message', () async {
    repo.summaryHandler =
        (uuid) async => const Left(ServerFailure('mid-session boom'));

    await provider.load('uuid-1');

    expect(provider.status, AppStatus.failure);
    expect(provider.errorMessage, 'mid-session boom');
    expect(provider.snapshot, isNull);
  });

  test('load can be called repeatedly to refresh', () async {
    repo.summaryHandler = (uuid) async => const Right(_snapshot);
    await provider.load('uuid-1');

    repo.summaryHandler = (uuid) async => const Right(
          AuditReportSnapshot(
            expectedCount: 100,
            scannedCount: 80,
            countDifference: -20,
            expectedWeight: 1000,
            scannedWeight: 800,
            weightDifference: -200,
            missingCount: 20,
            unexpectedCount: 0,
            notFoundCount: 0,
          ),
        );
    await provider.load('uuid-1');

    expect(provider.snapshot?.scannedCount, 80);
  });
}
