import '../../domain/entities/audit_report_snapshot.dart';
import 'json_parsing.dart';

class AuditReportSnapshotModel extends AuditReportSnapshot {
  const AuditReportSnapshotModel({
    required super.expectedCount,
    required super.scannedCount,
    required super.countDifference,
    required super.expectedWeight,
    required super.scannedWeight,
    required super.weightDifference,
    required super.missingCount,
    required super.unexpectedCount,
    required super.notFoundCount,
  });

  factory AuditReportSnapshotModel.fromJson(Map<String, dynamic> json) {
    return AuditReportSnapshotModel(
      expectedCount: parseInt(json['expected_count']),
      scannedCount: parseInt(json['scanned_count']),
      countDifference: parseInt(json['count_difference']),
      expectedWeight: parseDouble(json['expected_weight']),
      scannedWeight: parseDouble(json['scanned_weight']),
      weightDifference: parseDouble(json['weight_difference']),
      missingCount: parseInt(json['missing_count']),
      unexpectedCount: parseInt(json['unexpected_count']),
      notFoundCount: parseInt(json['not_found_count']),
    );
  }

  Map<String, dynamic> toJson() => {
    'expected_count': expectedCount,
    'scanned_count': scannedCount,
    'count_difference': countDifference,
    'expected_weight': expectedWeight,
    'scanned_weight': scannedWeight,
    'weight_difference': weightDifference,
    'missing_count': missingCount,
    'unexpected_count': unexpectedCount,
    'not_found_count': notFoundCount,
  };
}
