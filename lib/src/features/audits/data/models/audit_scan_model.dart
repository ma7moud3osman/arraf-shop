import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_scan_result.dart';
import 'json_parsing.dart';

class AuditScanModel extends AuditScan {
  const AuditScanModel({
    required super.id,
    required super.result,
    required super.barcode,
    required super.deviceLabel,
    required super.scannedAt,
    super.shopProductId,
    super.productName,
    super.shopEmployeeId,
    super.weightGrams,
  });

  factory AuditScanModel.fromJson(Map<String, dynamic> json) {
    return AuditScanModel(
      id: parseInt(json['id']),
      result: AuditScanResult.fromString(json['result'] as String),
      barcode: (json['barcode_scanned'] ?? json['barcode'] ?? '') as String,
      shopProductId: parseIntOrNull(json['shop_product_id']),
      productName: json['product_name'] as String?,
      shopEmployeeId: parseIntOrNull(json['shop_employee_id']),
      deviceLabel: (json['device_label'] as String?) ?? '',
      weightGrams: parseDoubleOrNull(json['weight_grams']),
      scannedAt: parseDateTime(json['scanned_at']) ?? DateTime.now(),
    );
  }
}
