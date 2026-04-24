import 'package:equatable/equatable.dart';

import 'gold_price_item.dart';

/// A point-in-time gold-price snapshot for a given country.
class GoldPriceSnapshot extends Equatable {
  final String country;
  final DateTime? updatedAt;
  final List<GoldPriceItem> items;

  const GoldPriceSnapshot({
    required this.country,
    required this.items,
    this.updatedAt,
  });

  GoldPriceItem? itemByKey(String key) {
    for (final item in items) {
      if (item.key == key) return item;
    }
    return null;
  }

  GoldPriceSnapshot copyWith({
    String? country,
    DateTime? updatedAt,
    List<GoldPriceItem>? items,
  }) {
    return GoldPriceSnapshot(
      country: country ?? this.country,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [country, updatedAt, items];
}
