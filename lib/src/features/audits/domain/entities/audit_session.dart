import 'package:equatable/equatable.dart';

import 'actor_ref.dart';
import 'audit_report_snapshot.dart';
import 'audit_status.dart';

class AuditSession extends Equatable {
  final String uuid;
  final int shopId;
  final AuditStatus status;
  final int expectedCount;
  final double expectedWeightGrams;
  final int scannedCount;
  final double scannedWeightGrams;
  final int progressPercent;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final ActorRef? startedBy;
  final ActorRef? completedBy;
  final String channel;
  final AuditReportSnapshot? reportSnapshot;

  const AuditSession({
    required this.uuid,
    required this.shopId,
    required this.status,
    required this.expectedCount,
    required this.expectedWeightGrams,
    required this.scannedCount,
    required this.scannedWeightGrams,
    required this.progressPercent,
    required this.channel,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.startedBy,
    this.completedBy,
    this.reportSnapshot,
  });

  @override
  List<Object?> get props => [
    uuid,
    status,
    scannedCount,
    scannedWeightGrams,
    completedAt,
  ];
}
