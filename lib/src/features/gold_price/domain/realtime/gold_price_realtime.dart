import 'package:equatable/equatable.dart';

import '../entities/gold_price_item.dart';
import '../entities/gold_price_snapshot.dart';

/// The realtime payload pushed on the public `gold-price` channel
/// (event name `price.updated`) whenever an admin edits the latest
/// gold price record.
///
/// Wraps a [GoldPriceSnapshot] so the provider can swap state in one shot.
class GoldPriceUpdatedEvent extends Equatable {
  final GoldPriceSnapshot snapshot;

  const GoldPriceUpdatedEvent({required this.snapshot});

  factory GoldPriceUpdatedEvent.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => GoldPriceItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    DateTime? parsedDate;
    final raw = map['date'];
    if (raw is String && raw.isNotEmpty) {
      parsedDate = DateTime.tryParse(raw)?.toLocal();
    }

    return GoldPriceUpdatedEvent(
      snapshot: GoldPriceSnapshot(
        country: (map['country'] as String?) ?? 'eg',
        updatedAt: parsedDate,
        items: items,
      ),
    );
  }

  @override
  List<Object?> get props => [snapshot];
}

/// Subscriber to the public `gold-price` Pusher channel.
///
/// Methods are named with a `goldPrice` suffix so they don't collide
/// with sibling realtime contracts (e.g. [AuditRealtime.subscribe])
/// when one transport implements multiple channels.
abstract class GoldPriceRealtime {
  /// Stream of `price.updated` events. Broadcast-style; multiple listeners
  /// share one underlying Pusher channel.
  Stream<GoldPriceUpdatedEvent> subscribeGoldPrice();

  /// Release one subscription; tears down the channel when refcount hits 0.
  Future<void> unsubscribeGoldPrice();
}
