import 'package:equatable/equatable.dart';

class AuditSessionItem extends Equatable {
  final int id;
  final int shopProductId;
  final String barcode;
  final String? sku;
  final String? name;
  final double? weightGrams;
  final DateTime? scannedAt;

  const AuditSessionItem({
    required this.id,
    required this.shopProductId,
    required this.barcode,
    this.sku,
    this.name,
    this.weightGrams,
    this.scannedAt,
  });

  @override
  List<Object?> get props => [id, scannedAt];
}
