import 'dart:async';

import 'package:arraf_shop/src/features/gold_price/domain/entities/gold_price_item.dart';
import 'package:arraf_shop/src/features/gold_price/domain/entities/gold_price_snapshot.dart';
import 'package:arraf_shop/src/features/gold_price/domain/realtime/gold_price_realtime.dart';
import 'package:arraf_shop/src/features/gold_price/domain/repositories/gold_price_repository.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

GoldPriceItem makeItem({
  String key = 'karat_21',
  String title = '21 Karat',
  String subtitle = 'EGP / gram',
  double sale = 4000,
  double buy = 3950,
  double diff = 5,
  String diffType = 'positive',
  bool isDollar = false,
}) {
  return GoldPriceItem(
    key: key,
    title: title,
    subtitle: subtitle,
    sale: sale,
    buy: buy,
    diff: diff,
    diffType: diffType,
    isDollar: isDollar,
  );
}

GoldPriceSnapshot makeSnapshot({
  String country = 'eg',
  DateTime? updatedAt,
  List<GoldPriceItem>? items,
}) {
  return GoldPriceSnapshot(
    country: country,
    updatedAt: updatedAt ?? DateTime(2026, 4, 24, 12, 0),
    items: items ?? [makeItem(), makeItem(key: 'karat_24', sale: 4500, buy: 4450)],
  );
}

class FakeGoldPriceRepository implements GoldPriceRepository {
  FutureEither<GoldPriceSnapshot> Function(String country)? todayHandler;
  FutureEither<GoldPriceSnapshot> Function(
    String country,
    Map<String, double> updates,
  )?
  updateHandler;

  int todayCalls = 0;
  int updateCalls = 0;
  Map<String, double>? lastUpdates;

  @override
  FutureEither<GoldPriceSnapshot> today({String country = 'eg'}) {
    todayCalls += 1;
    final h = todayHandler;
    if (h != null) return h(country);
    return Future.value(Right(makeSnapshot(country: country)));
  }

  @override
  FutureEither<GoldPriceSnapshot> update({
    String country = 'eg',
    required Map<String, double> updates,
  }) {
    updateCalls += 1;
    lastUpdates = updates;
    final h = updateHandler;
    if (h != null) return h(country, updates);

    final patched = makeSnapshot(country: country).items.map((item) {
      final saleKey = '${item.key}_sale';
      final buyKey = '${item.key}_buy';
      return item.copyWith(
        sale: updates[saleKey],
        buy: updates[buyKey],
      );
    }).toList(growable: false);
    return Future.value(
      Right(makeSnapshot(country: country, items: patched)),
    );
  }
}

class FailingGoldPriceRepository implements GoldPriceRepository {
  FailingGoldPriceRepository({this.failure = const ServerFailure('boom')});
  final Failure failure;

  @override
  FutureEither<GoldPriceSnapshot> today({String country = 'eg'}) =>
      Future.value(Left(failure));

  @override
  FutureEither<GoldPriceSnapshot> update({
    String country = 'eg',
    required Map<String, double> updates,
  }) =>
      Future.value(Left(failure));
}

class FakeGoldPriceRealtime implements GoldPriceRealtime {
  final _events = StreamController<GoldPriceUpdatedEvent>.broadcast();

  int subscribeCalls = 0;
  int unsubscribeCalls = 0;

  void emit(GoldPriceUpdatedEvent event) => _events.add(event);

  @override
  Stream<GoldPriceUpdatedEvent> subscribeGoldPrice() {
    subscribeCalls += 1;
    return _events.stream;
  }

  @override
  Future<void> unsubscribeGoldPrice() async {
    unsubscribeCalls += 1;
  }

  Future<void> close() => _events.close();
}
