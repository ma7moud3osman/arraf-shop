import 'package:arraf_shop/src/features/audits/domain/entities/audit_report_snapshot.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_session_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_summary_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audits_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../providers/_fakes.dart';
import '_screen_harness.dart';

/// Golden smoke tests for the three audit screens.
///
/// Scope: each screen is rendered once in a **deterministic** state and
/// snapshotted. Pixel goldens are inherently sensitive to font metrics and
/// Flutter-version changes — these tests are intended to catch obvious layout
/// regressions, not every style tweak.
///
/// To regenerate baselines after an intentional visual change run:
///   flutter test --update-goldens \
///     test/features/audits/presentation/screens/screen_goldens_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(stubCameraPermission);
  tearDownAll(unstubCameraPermission);

  void pinView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
  }

  void resetView(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('audits list — empty state', (tester) async {
    pinView(tester);
    addTearDown(() => resetView(tester));

    final repo =
        FakeAuditRepository()
          ..listHandler =
              ({int page = 1, String? status}) async => const Right(
                Paginated(
                  items: [],
                  currentPage: 1,
                  perPage: 20,
                  total: 0,
                  lastPage: 1,
                ),
              );
    final provider = AuditsListProvider(
      repository: repo,
      realtime: FakeAuditRealtime(),
    );
    addTearDown(provider.dispose);

    // Seed the provider to success-empty *before* pumping so the skeleton
    // loading state (which has a known layout overflow in the card widget
    // under narrow skeletonized constraints) never appears.
    await provider.load();

    await tester.pumpWidget(
      harness(
        list: provider,
        child: AuditsListScreen(isAdmin: true, onOpen: (_) {}),
      ),
    );
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/audits_list_empty.png'),
    );
  });

  testWidgets('audit session — scanner permission denied', (tester) async {
    pinView(tester);
    addTearDown(() => resetView(tester));

    final repo =
        FakeAuditRepository()
          ..showHandler =
              (uuid) async => Right(
                SessionWithScans(
                  session: makeSession(
                    uuid: uuid,
                    scannedCount: 0,
                    scannedWeightGrams: 0,
                    progressPercent: 0,
                  ),
                ),
              );
    final realtime = FakeAuditRealtime();
    addTearDown(realtime.close);
    final provider = AuditSessionProvider(
      repository: repo,
      realtime: realtime,
      deviceLabel: 'iPad',
    );
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      harness(
        session: provider,
        child: AuditSessionScreen(
          uuid: 'u-golden',
          isOwner: true,
          onCompleted: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/audit_session_loaded.png'),
    );
  });

  testWidgets('audit summary — completed snapshot', (tester) async {
    pinView(tester);
    addTearDown(() => resetView(tester));

    const snapshot = AuditReportSnapshot(
      expectedCount: 128,
      scannedCount: 125,
      countDifference: -3,
      expectedWeight: 4213.517,
      scannedWeight: 4112.110,
      weightDifference: -101.407,
      missingCount: 4,
      unexpectedCount: 1,
      notFoundCount: 0,
    );

    final repo =
        FakeAuditRepository()
          ..summaryHandler = (uuid) async => const Right(snapshot);

    await tester.pumpWidget(
      harness(
        repository: repo,
        child: const AuditSummaryScreen(uuid: 'u-golden'),
      ),
    );
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/audit_summary_completed.png'),
    );
  });
}
