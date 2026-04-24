import 'package:arraf_shop/src/features/audits/data/audit_failures.dart';
import 'package:arraf_shop/src/features/gold_price/domain/realtime/gold_price_realtime.dart';
import 'package:arraf_shop/src/features/gold_price/presentation/providers/gold_price_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('GoldPriceProvider', () {
    late FakeGoldPriceRepository repo;
    late FakeGoldPriceRealtime realtime;
    late GoldPriceProvider provider;

    setUp(() {
      repo = FakeGoldPriceRepository();
      realtime = FakeGoldPriceRealtime();
      provider = GoldPriceProvider(repository: repo, realtime: realtime);
    });

    tearDown(() async {
      provider.dispose();
      await realtime.close();
    });

    test('load() flips status and stores the snapshot', () async {
      expect(provider.status, AppStatus.initial);

      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.snapshot, isNotNull);
      expect(provider.snapshot!.items, isNotEmpty);
      expect(repo.todayCalls, 1);
    });

    test('load() failure exposes errorMessage and stays in failure', () async {
      final failingRepo = FailingGoldPriceRepository(
        failure: const ServerFailure('nope'),
      );
      final failingProvider = GoldPriceProvider(
        repository: failingRepo,
        realtime: realtime,
      );

      await failingProvider.load();

      expect(failingProvider.status, AppStatus.failure);
      expect(failingProvider.errorMessage, 'nope');
      expect(failingProvider.snapshot, isNull);

      failingProvider.dispose();
    });

    test('subscribes to realtime exactly once after first successful load',
        () async {
      await provider.load();
      await provider.load();

      expect(realtime.subscribeCalls, 1);
    });

    test('realtime event for the same country replaces the snapshot', () async {
      await provider.load();

      final pushed = makeSnapshot(
        country: 'eg',
        items: [makeItem(key: 'karat_21', sale: 9999, buy: 9900)],
      );
      realtime.emit(GoldPriceUpdatedEvent(snapshot: pushed));

      await Future<void>.delayed(Duration.zero);

      final item = provider.snapshot!.itemByKey('karat_21');
      expect(item, isNotNull);
      expect(item!.sale, 9999);
    });

    test('realtime event for a different country is ignored', () async {
      await provider.load();
      final before = provider.snapshot;

      final foreign = makeSnapshot(
        country: 'sa',
        items: [makeItem(key: 'karat_21', sale: 1)],
      );
      realtime.emit(GoldPriceUpdatedEvent(snapshot: foreign));
      await Future<void>.delayed(Duration.zero);

      expect(provider.snapshot, same(before));
    });

    test('update() success patches snapshot and returns null', () async {
      await provider.load();

      final error = await provider.update({'karat_21_sale': 5555});

      expect(error, isNull);
      expect(provider.updateStatus, AppStatus.success);
      expect(repo.updateCalls, 1);
      expect(repo.lastUpdates, {'karat_21_sale': 5555});
    });

    test('update() failure surfaces the message', () async {
      repo.updateHandler = (_, _) async =>
          const Left(ForbiddenFailure('not allowed'));

      final error = await provider.update({'karat_21_sale': 1});

      expect(error, 'not allowed');
      expect(provider.updateStatus, AppStatus.failure);
    });

    test('clearUpdateStatus resets after a failure', () async {
      repo.updateHandler = (_, _) async =>
          const Left(ServerFailure('bad'));
      await provider.update({'karat_21_sale': 1});
      expect(provider.updateStatus, AppStatus.failure);

      provider.clearUpdateStatus();
      expect(provider.updateStatus, AppStatus.initial);
    });

    test('dispose() unsubscribes from the realtime channel', () async {
      // Use a local realtime + provider so the shared tearDown dispose
      // doesn't fire on an already-disposed provider.
      final localRealtime = FakeGoldPriceRealtime();
      final localProvider = GoldPriceProvider(
        repository: repo,
        realtime: localRealtime,
      );

      await localProvider.load();
      localProvider.dispose();

      expect(localRealtime.unsubscribeCalls, 1);
      await localRealtime.close();
    });
  });

  group('GoldPriceUpdatedEvent.fromMap', () {
    test('parses items + country + date', () {
      final event = GoldPriceUpdatedEvent.fromMap({
        'country': 'eg',
        'date': '2026-04-24T12:34:56+00:00',
        'items': [
          {
            'key': 'karat_21',
            'title': '21',
            'subtitle': 'EGP/g',
            'sale': 4321,
            'buy': 4300,
            'diff': 5,
            'diff_type': 'positive',
            'is_dollar': false,
          },
        ],
      });

      expect(event.snapshot.country, 'eg');
      expect(event.snapshot.items, hasLength(1));
      expect(event.snapshot.items.first.sale, 4321);
      expect(event.snapshot.updatedAt, isNotNull);
    });

    test('tolerates missing date / items', () {
      final event = GoldPriceUpdatedEvent.fromMap({'country': 'eg'});
      expect(event.snapshot.items, isEmpty);
      expect(event.snapshot.updatedAt, isNull);
    });
  });
}
