import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/shop_item.dart';

class ShopItemModel extends ShopItem {
  const ShopItemModel({
    required super.id,
    required super.shopId,
    required super.costFee,
    required super.manufacturingFee,
    required super.minimumStockLevel,
    required super.displayLabel,
    required super.stockOnHand,
    super.karat,
    super.variant,
    super.status,
    super.countryIsoCode,
    super.merchantGroupName,
    super.manufacturerName,
  });

  factory ShopItemModel.fromJson(Map<String, dynamic> json) {
    final group = json['merchant_group'];
    final manufacturer = json['manufacturer'];

    return ShopItemModel(
      id: parseInt(json['id']),
      shopId: parseInt(json['shop_id']),
      karat: json['karat']?.toString(),
      variant: json['variant'] as String?,
      costFee: parseDouble(json['cost_fee']),
      manufacturingFee: parseDouble(json['manufacturing_fee']),
      minimumStockLevel: parseInt(json['minimum_stock_level']),
      status: json['status'] as String?,
      countryIsoCode: json['country_iso_code'] as String?,
      displayLabel: (json['display_label'] as String?) ?? '',
      stockOnHand: parseInt(json['stock_on_hand']),
      merchantGroupName: group is Map ? group['name'] as String? : null,
      manufacturerName:
          manufacturer is Map ? manufacturer['name'] as String? : null,
    );
  }
}
