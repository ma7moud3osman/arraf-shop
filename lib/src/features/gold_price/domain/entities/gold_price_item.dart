import 'package:equatable/equatable.dart';

/// One karat / unit row of the gold price table (e.g. "karat_21", "ounce").
///
/// Mirrors the shape produced by `GoldPrice::formatToList()` on the backend
/// but trimmed to the fields the mobile UI actually uses.
class GoldPriceItem extends Equatable {
  /// Field key on the backend (`karat_24`, `karat_21`, `ounce`, ...).
  final String key;

  /// Display title resolved from i18n on the backend.
  final String title;

  /// Display subtitle resolved from i18n on the backend.
  final String subtitle;

  final double sale;
  final double buy;
  final double diff;
  final String diffType;
  final bool isDollar;

  const GoldPriceItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.sale,
    required this.buy,
    required this.diff,
    required this.diffType,
    required this.isDollar,
  });

  factory GoldPriceItem.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw) ?? 0;
      return 0;
    }

    return GoldPriceItem(
      key: (json['key'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      subtitle: (json['subtitle'] as String?) ?? '',
      sale: asDouble(json['sale']),
      buy: asDouble(json['buy']),
      diff: asDouble(json['diff']),
      diffType: (json['diff_type'] as String?) ?? 'positive',
      isDollar: json['is_dollar'] == true,
    );
  }

  GoldPriceItem copyWith({double? sale, double? buy, double? diff}) {
    return GoldPriceItem(
      key: key,
      title: title,
      subtitle: subtitle,
      sale: sale ?? this.sale,
      buy: buy ?? this.buy,
      diff: diff ?? this.diff,
      diffType: diffType,
      isDollar: isDollar,
    );
  }

  @override
  List<Object?> get props => [
    key,
    title,
    subtitle,
    sale,
    buy,
    diff,
    diffType,
    isDollar,
  ];
}
