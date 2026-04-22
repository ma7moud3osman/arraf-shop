import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_status.dart';
import 'actor_ref_model.dart';
import 'audit_report_snapshot_model.dart';
import 'json_parsing.dart';

class AuditSessionModel extends AuditSession {
  const AuditSessionModel({
    required super.uuid,
    required super.shopId,
    required super.status,
    required super.expectedCount,
    required super.expectedWeightGrams,
    required super.scannedCount,
    required super.scannedWeightGrams,
    required super.progressPercent,
    required super.channel,
    super.startedAt,
    super.completedAt,
    super.notes,
    super.startedBy,
    super.completedBy,
    super.reportSnapshot,
  });

  factory AuditSessionModel.fromJson(Map<String, dynamic> json) {
    return AuditSessionModel(
      uuid: json['uuid'] as String,
      shopId: parseInt(json['shop_id']),
      status: AuditStatus.fromString(json['status'] as String),
      expectedCount: parseInt(json['expected_count']),
      expectedWeightGrams: parseDouble(json['expected_weight_grams']),
      scannedCount: parseInt(json['scanned_count']),
      scannedWeightGrams: parseDouble(json['scanned_weight_grams']),
      progressPercent: parseInt(json['progress_percent']),
      startedAt: parseDateTime(json['started_at']),
      completedAt: parseDateTime(json['completed_at']),
      notes: json['notes'] as String?,
      startedBy:
          json['started_by'] is Map<String, dynamic>
              ? ActorRefModel.fromJson(
                json['started_by'] as Map<String, dynamic>,
              )
              : null,
      completedBy:
          json['completed_by'] is Map<String, dynamic>
              ? ActorRefModel.fromJson(
                json['completed_by'] as Map<String, dynamic>,
              )
              : null,
      channel: (json['channel'] as String?) ?? '',
      reportSnapshot:
          json['report_snapshot'] is Map<String, dynamic>
              ? AuditReportSnapshotModel.fromJson(
                json['report_snapshot'] as Map<String, dynamic>,
              )
              : null,
    );
  }
}
