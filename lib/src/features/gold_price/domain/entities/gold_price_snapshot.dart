import 'package:equatable/equatable.dart';

import 'gold_price_item.dart';

/// A point-in-time per-shop gold-price snapshot.
///
/// `shopId` identifies the owning shop (used for the realtime channel).
/// The legacy `country` field is kept on the entity but defaults to an
/// empty string — the price is now per-shop on the backend, so the
/// country dimension no longer applies.
class GoldPriceSnapshot extends Equatable {
  final int? shopId;
  final String country;
  final DateTime? updatedAt;
  final List<GoldPriceItem> items;

  const GoldPriceSnapshot({
    required this.items,
    this.shopId,
    this.country = '',
    this.updatedAt,
  });

  GoldPriceItem? itemByKey(String key) {
    for (final item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  GoldPriceSnapshot copyWith({
    int? shopId,
    String? country,
    DateTime? updatedAt,
    List<GoldPriceItem>? items,
  }) {
    return GoldPriceSnapshot(
      shopId: shopId ?? this.shopId,
      country: country ?? this.country,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [shopId, country, updatedAt, items];
}
