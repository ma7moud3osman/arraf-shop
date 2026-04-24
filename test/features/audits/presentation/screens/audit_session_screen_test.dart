import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_session_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/widgets/audit_progress_card.dart';
import 'package:arraf_shop/src/features/audits/presentation/widgets/audit_scan_row.dart';
import 'package:arraf_shop/src/features/audits/presentation/widgets/barcode_scanner_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../providers/_fakes.dart';
import '_screen_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(stubCameraPermission);
  tearDownAll(unstubCameraPermission);

  group('AuditSessionScreen', () {
    testWidgets('renders scanner, progress card, and scan feed', (
      tester,
    ) async {
      setPhoneTestView(tester);
      addTearDown(() => resetTestView(tester));
      final repo =
          FakeAuditRepository()
            ..showHandler =
                (uuid) async => Right(
                  SessionWithScans(
                    session: makeSession(
                      uuid: uuid,
                      scannedCount: 3,
                      scannedWeightGrams: 42.5,
                      expectedCount: 20,
                      progressPercent: 15,
                    ),
                  ),
                );
      final realtime = FakeAuditRealtime();
      final provider = AuditSessionProvider(
        repository: repo,
        realtime: realtime,
        deviceLabel: 'Test iPad',
      );

      await tester.pumpWidget(
        harness(
          session: provider,
          child: AuditSessionScreen(
            uuid: 'u-1',
            isOwner: true,
            onCompleted: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(BarcodeScannerView), findsOneWidget);
      expect(find.byType(AuditProgressCard), findsOneWidget);
      // Complete action shown for owner on an in-progress session.
      // Now rendered as an icon-only button with the label as a tooltip.
      expect(
        find.byTooltip('audits.session.complete'),
        findsOneWidget,
      );
      // Feed starts empty → empty state copy visible.
      expect(find.textContaining('audits.session.feed_empty'), findsOneWidget);

      await realtime.close();
    });

    testWidgets('hides complete button for employees', (tester) async {
      setPhoneTestView(tester);
      addTearDown(() => resetTestView(tester));
      final provider = AuditSessionProvider(
        repository: FakeAuditRepository(),
        realtime: FakeAuditRealtime(),
        deviceLabel: 'Test iPad',
      );

      await tester.pumpWidget(
        harness(
          session: provider,
          child: AuditSessionScreen(
            uuid: 'u-2',
            isOwner: false,
            onCompleted: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('audits.session.complete'), findsNothing);
    });

    testWidgets('renders feed rows after a realtime scan arrives', (
      tester,
    ) async {
      setPhoneTestView(tester);
      addTearDown(() => resetTestView(tester));
      final repo = FakeAuditRepository();
      final realtime = FakeAuditRealtime();
      final provider = AuditSessionProvider(
        repository: repo,
        realtime: realtime,
        deviceLabel: 'Test iPad',
      );

      await tester.pumpWidget(
        harness(
          session: provider,
          child: AuditSessionScreen(
            uuid: 'u-3',
            isOwner: true,
            onCompleted: (_) {},
          ),
        ),
      );
      // session.join + subscribe
      await tester.pump();
      await tester.pump();

      // Session resolved; subscribe the provider directly and push an event.
      expect(provider.session, isNotNull, reason: 'join should complete');
      realtime.emit(
        makeScanEvent(scanId: 900, scannedCount: 1, scannedWeight: 1.2),
      );
      await tester.pump();

      expect(find.byType(AuditScanRow), findsOneWidget);

      await realtime.close();
    });
  });
}
