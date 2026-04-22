import 'package:equatable/equatable.dart';

class AuditReportSnapshot extends Equatable {
  final int expectedCount;
  final int scannedCount;
  final int countDifference;
  final double expectedWeight;
  final double scannedWeight;
  final double weightDifference;
  final int missingCount;
  final int unexpectedCount;
  final int notFoundCount;

  const AuditReportSnapshot({
    required this.expectedCount,
    required this.scannedCount,
    required this.countDifference,
    required this.expectedWeight,
    required this.scannedWeight,
    required this.weightDifference,
    required this.missingCount,
    required this.unexpectedCount,
    required this.notFoundCount,
  });

  @override
  List<Object?> get props => [
    expectedCount,
    scannedCount,
    missingCount,
    unexpectedCount,
  ];
}
