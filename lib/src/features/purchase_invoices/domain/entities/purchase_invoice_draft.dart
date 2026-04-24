import 'dart:io';

import 'package:equatable/equatable.dart';

import 'shop_item.dart';

/// A single physical piece inside a draft item. Each piece carries an
/// optional weight override (for non-uniform splits) and an image file the
/// owner snapped at intake.
class DraftPiece extends Equatable {
  final double? weight;
  final File? image;

  const DraftPiece({this.weight, this.image});

  DraftPiece copyWith({double? weight, File? image, bool clearImage = false}) {
    return DraftPiece(
      weight: weight ?? this.weight,
      image: clearImage ? null : (image ?? this.image),
    );
  }

  @override
  List<Object?> get props => [weight, image?.path];
}

/// One row in the wizard's items step. Pieces always have length [quantity];
/// adjusting quantity resizes the list (preserving any existing entries).
class DraftItem extends Equatable {
  final ShopItem? shopItem;
  final double weightGramsTotal;
  final int quantity;
  final double manufacturerFee;
  final List<DraftPiece> pieces;

  const DraftItem({
    this.shopItem,
    this.weightGramsTotal = 0,
    this.quantity = 1,
    this.manufacturerFee = 0,
    this.pieces = const [DraftPiece()],
  });

  DraftItem copyWith({
    ShopItem? shopItem,
    double? weightGramsTotal,
    int? quantity,
    double? manufacturerFee,
    List<DraftPiece>? pieces,
  }) {
    return DraftItem(
      shopItem: shopItem ?? this.shopItem,
      weightGramsTotal: weightGramsTotal ?? this.weightGramsTotal,
      quantity: quantity ?? this.quantity,
      manufacturerFee: manufacturerFee ?? this.manufacturerFee,
      pieces: pieces ?? this.pieces,
    );
  }

  /// Computed line total preview (server is source of truth):
  /// `weight * gold_price_per_gram_per_karat + manufacturer_fee * quantity`.
  /// We don't have the gold price client-side, so this only sums the
  /// manufacturer fees.
  double get manufacturerFeeTotal => manufacturerFee * quantity;

  @override
  List<Object?> get props => [
    shopItem?.id,
    weightGramsTotal,
    quantity,
    manufacturerFee,
    pieces,
  ];
}
