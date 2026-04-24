import 'package:equatable/equatable.dart';

/// Catalog "template" the shop owner has defined in Filament. Picked from
/// in the create-purchase-invoice wizard to prefill karat / fees / category.
class ShopItem extends Equatable {
  final int id;
  final int shopId;
  final String? karat;
  final String? variant;
  final double costFee;
  final double manufacturingFee;
  final int minimumStockLevel;
  final String? status;
  final String? countryIsoCode;
  final String displayLabel;
  final int stockOnHand;
  final String? merchantGroupName;
  final String? manufacturerName;

  const ShopItem({
    required this.id,
    required this.shopId,
    required this.costFee,
    required this.manufacturingFee,
    required this.minimumStockLevel,
    required this.displayLabel,
    required this.stockOnHand,
    this.karat,
    this.variant,
    this.status,
    this.countryIsoCode,
    this.merchantGroupName,
    this.manufacturerName,
  });

  /// Convenience constructor for tests / fakes.
  factory ShopItem.fake({
    int id = 1,
    String displayLabel = 'Bracelets · Lazurde · 21K',
    String? karat = '21',
    String? variant = 'Bracelet',
    double manufacturingFee = 120,
    int stockOnHand = 5,
    String? merchantGroupName = 'Bracelets',
    String? manufacturerName = 'Lazurde',
  }) {
    return ShopItem(
      id: id,
      shopId: 1,
      karat: karat,
      variant: variant,
      costFee: 0,
      manufacturingFee: manufacturingFee,
      minimumStockLevel: 0,
      status: 'Active',
      countryIsoCode: 'eg',
      displayLabel: displayLabel,
      stockOnHand: stockOnHand,
      merchantGroupName: merchantGroupName,
      manufacturerName: manufacturerName,
    );
  }

  @override
  List<Object?> get props => [
    id,
    shopId,
    karat,
    variant,
    costFee,
    manufacturingFee,
    minimumStockLevel,
    status,
    displayLabel,
    stockOnHand,
    merchantGroupName,
    manufacturerName,
  ];
}
