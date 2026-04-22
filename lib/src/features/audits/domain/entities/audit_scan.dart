import 'package:equatable/equatable.dart';

import 'audit_scan_result.dart';

class AuditScan extends Equatable {
  final int id;
  final AuditScanResult result;
  final String barcode;
  final int? shopProductId;
  final String? productName;
  final int? shopEmployeeId;
  final String deviceLabel;
  final double? weightGrams;
  final DateTime scannedAt;

  const AuditScan({
    required this.id,
    required this.result,
    required this.barcode,
    required this.deviceLabel,
    required this.scannedAt,
    this.shopProductId,
    this.productName,
    this.shopEmployeeId,
    this.weightGrams,
  });

  /// Preferred human label: the product's name when known, else the raw
  /// scanned barcode (useful for `not_found` / optimistic rows).
  String get displayLabel =>
      (productName != null && productName!.isNotEmpty) ? productName! : barcode;

  @override
  List<Object?> get props => [id];
}
