import 'package:equatable/equatable.dart';

import '../entities/gold_price_item.dart';
import '../entities/gold_price_snapshot.dart';

/// The realtime payload pushed on the **private** per-shop channel
/// `shop.{shopId}.gold-price` (event name `price.updated`) whenever the
/// shop's 21K base buy/sale price is updated — from the panel, the
/// mobile app, or any other client.
///
/// Wraps a [GoldPriceSnapshot] so the provider can swap state in one shot.
class GoldPriceUpdatedEvent extends Equatable {
  final GoldPriceSnapshot snapshot;

  const GoldPriceUpdatedEvent({required this.snapshot});

  factory GoldPriceUpdatedEvent.fromMap(Map<String, dynamic> map) {
    final derivedBuy = _doubleMap(map['derived_buy']);
    final derivedSale = _doubleMap(map['derived_sale']);

    const supportedKarats = ['24', '22', '21', '18'];
    final items = supportedKarats
        .map(
          (karat) => GoldPriceItem(
            key: 'karat_$karat',
            title: karat,
            subtitle: '',
            sale: derivedSale[karat] ?? 0,
            buy: derivedBuy[karat] ?? 0,
            diff: 0,
            diffType: 'positive',
            isDollar: false,
          ),
        )
        .toList(growable: false);

    DateTime? parsedDate;
    final raw = map['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      parsedDate = DateTime.tryParse(raw)?.toLocal();
    }

    final shopId = map['shop_id'];

    return GoldPriceUpdatedEvent(
      snapshot: GoldPriceSnapshot(
        shopId:
            shopId is int ? shopId : (shopId is num ? shopId.toInt() : null),
        updatedAt: parsedDate,
        items: items,
      ),
    );
  }

  static Map<String, double> _doubleMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    raw.forEach((key, value) {
      final stringKey = key?.toString();
      if (stringKey == null) return;
      if (value is num) {
        out[stringKey] = value.toDouble();
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) out[stringKey] = parsed;
      }
    });
    return out;
  }

  @override
  List<Object?> get props => [snapshot];
}

/// Subscriber to the **private** per-shop gold-price Pusher channel.
///
/// Methods are named with a `goldPrice` suffix so they don't collide
/// with sibling realtime contracts (e.g. [AuditRealtime.subscribe])
/// when one transport implements multiple channels.
abstract class GoldPriceRealtime {
  /// Stream of `price.updated` events for the given shop. Broadcast-style;
  /// multiple listeners share one underlying Pusher channel.
  Stream<GoldPriceUpdatedEvent> subscribeGoldPrice(int shopId);

  /// Release one subscription; tears down the channel when refcount hits 0.
  Future<void> unsubscribeGoldPrice(int shopId);
}
