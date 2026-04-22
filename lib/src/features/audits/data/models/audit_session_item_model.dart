import '../../domain/entities/audit_session_item.dart';
import 'json_parsing.dart';

class AuditSessionItemModel extends AuditSessionItem {
  const AuditSessionItemModel({
    required super.id,
    required super.shopProductId,
    required super.barcode,
    super.sku,
    super.name,
    super.weightGrams,
    super.scannedAt,
  });

  factory AuditSessionItemModel.fromJson(Map<String, dynamic> json) {
    return AuditSessionItemModel(
      id: parseInt(json['id']),
      shopProductId: parseInt(json['shop_product_id']),
      barcode: (json['barcode'] as String?) ?? '',
      sku: json['sku'] as String?,
      name: json['name'] as String?,
      weightGrams: parseDoubleOrNull(json['weight_grams']),
      scannedAt: parseDateTime(json['scanned_at']),
    );
  }
}
