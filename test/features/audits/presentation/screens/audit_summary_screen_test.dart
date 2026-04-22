import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_scan.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_session_item.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_summary_screen.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../providers/_fakes.dart';
import '_screen_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuditSummaryScreen', () {
    testWidgets('renders snapshot and empty missing list', (tester) async {
      setPhoneTestView(tester);
      addTearDown(() => resetTestView(tester));
      final repo = _SummaryRepo();

      await tester.pumpWidget(
        harness(repository: repo, child: const AuditSummaryScreen(uuid: 'u-9')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('audits.summary.overview'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('98'), findsOneWidget);
      expect(find.textContaining('audits.summary.no_missing'), findsOneWidget);
    });

    testWidgets('switches to unexpected tab and renders items', (tester) async {
      setPhoneTestView(tester);
      addTearDown(() => resetTestView(tester));
      final repo = _SummaryRepo(
        unexpectedScans: [makeScan(id: 101, barcode: '7-UNEX1')],
      );

      await tester.pumpWidget(
        harness(repository: repo, child: const AuditSummaryScreen(uuid: 'u-9')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Tap the second "Unexpected" text — the SegmentedButton label (which
      // includes a count placeholder), not the headline _Count label.
      await tester.tap(find.textContaining('audits.summary.unexpected').last);
      await tester.pumpAndSettle();

      expect(find.text('7-UNEX1'), findsOneWidget);
    });
  });
}

class _SummaryRepo extends FakeAuditRepository {
  _SummaryRepo({this.unexpectedScans = const <AuditScan>[]});

  final List<AuditScan> unexpectedScans;

  @override
  FutureEither<AuditReportSnapshot> summary(String uuid) async {
    return const Right(
      AuditReportSnapshot(
        expectedCount: 100,
        scannedCount: 98,
        countDifference: -2,
        expectedWeight: 1000,
        scannedWeight: 980,
        weightDifference: -20,
        missingCount: 2,
        unexpectedCount: 0,
        notFoundCount: 0,
      ),
    );
  }

  @override
  FutureEither<Paginated<AuditSessionItem>> missing(
    String uuid, {
    int page = 1,
  }) async {
    return const Right(
      Paginated<AuditSessionItem>(
        items: [],
        currentPage: 1,
        perPage: 20,
        total: 0,
        lastPage: 1,
      ),
    );
  }

  @override
  FutureEither<Paginated<AuditScan>> unexpected(
    String uuid, {
    int page = 1,
  }) async {
    return Right(
      Paginated<AuditScan>(
        items: unexpectedScans,
        currentPage: 1,
        perPage: 20,
        total: unexpectedScans.length,
        lastPage: 1,
      ),
    );
  }
}
