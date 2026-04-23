import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audits_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../providers/_fakes.dart';
import '_screen_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuditsListScreen', () {
    testWidgets('renders sessions after successful load', (tester) async {
      final repo =
          FakeAuditRepository()
            ..listHandler =
                ({int page = 1, String? status}) async => Right(
                  Paginated(
                    items: [
                      makeSession(
                        uuid: 'u-1',
                        notes: 'Q1 audit',
                        scannedCount: 12,
                      ),
                      makeSession(
                        uuid: 'u-2',
                        notes: 'Q2 audit',
                        scannedCount: 3,
                      ),
                    ],
                    currentPage: 1,
                    perPage: 20,
                    total: 2,
                    lastPage: 1,
                  ),
                );
      final provider = AuditsListProvider(
        repository: repo,
        realtime: FakeAuditRealtime(),
      );

      String? opened;
      await tester.pumpWidget(
        harness(
          list: provider,
          child: AuditsListScreen(
            isOwner: true,
            onOpen: (session) => opened = session.uuid,
          ),
        ),
      );

      // Trigger the postFrameCallback which calls load().
      await tester.pump();
      await tester.pump();

      expect(find.text('Q1 audit'), findsOneWidget);
      expect(find.text('Q2 audit'), findsOneWidget);
      expect(
        find.byType(FloatingActionButton),
        findsOneWidget,
        reason: 'Owner should see start-new FAB',
      );

      await tester.tap(find.text('Q1 audit'));
      await tester.pump();
      expect(opened, 'u-1');
    });

    testWidgets('shows empty state when list is empty', (tester) async {
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

      await tester.pumpWidget(
        harness(
          list: provider,
          child: AuditsListScreen(isOwner: true, onOpen: (_) {}),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Empty-state title key is rendered because easy_localization is not
      // initialised in tests; we assert the key itself is reachable.
      expect(find.textContaining('audits.list.empty_title'), findsOneWidget);
    });

    testWidgets('hides FAB for employees', (tester) async {
      final provider = AuditsListProvider(
        repository: FakeAuditRepository(),
        realtime: FakeAuditRealtime(),
      );

      await tester.pumpWidget(
        harness(
          list: provider,
          child: AuditsListScreen(isOwner: false, onOpen: (_) {}),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
