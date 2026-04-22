@Tags(['integration'])
library;

import 'dart:io';

import 'package:arraf_shop/src/features/audits/domain/realtime/audit_realtime.dart';
import 'package:arraf_shop/src/services/pusher_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests that require real Pusher test credentials.
///
/// Usage:
///   * Create `.env.test` at the project root with `PUSHER_APP_KEY=...`
///     and `PUSHER_APP_CLUSTER=...`.
///   * Run with `flutter test --tags integration`.
///
/// When keys are missing the whole group is skipped — these never fail CI.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final envFile = File('${Directory.current.path}/.env.test');
  final hasEnvFile = envFile.existsSync();

  setUpAll(() async {
    if (hasEnvFile) {
      await dotenv.load(fileName: '.env.test');
    }
  });

  final skip =
      !hasEnvFile
          ? 'No .env.test at project root — skipping Pusher integration tests.'
          : (dotenv.maybeGet('PUSHER_APP_KEY') ?? '').isEmpty
          ? 'PUSHER_APP_KEY missing from .env.test — skipping.'
          : null;

  group('PusherService (network)', () {
    test(
      'connects and exposes a non-disconnected state',
      () async {
        final service = PusherService.instance;
        addTearDown(service.dispose);

        final transitions = <RealtimeConnectionState>[];
        final sub = service.connectionState.listen(transitions.add);
        addTearDown(sub.cancel);

        // Trigger lazy init by subscribing to a throw-away session.
        final _ = service.subscribe(999999).listen((_) {});
        addTearDown(() => service.unsubscribe(999999));

        await Future<void>.delayed(const Duration(seconds: 5));
        expect(
          transitions,
          contains(
            isIn([
              RealtimeConnectionState.connecting,
              RealtimeConnectionState.connected,
            ]),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
      skip: skip,
    );
  });
}
