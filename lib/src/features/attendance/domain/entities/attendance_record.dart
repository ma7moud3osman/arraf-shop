import 'package:equatable/equatable.dart';

import 'attendance_status.dart';

class AttendanceRecord extends Equatable {
  final int id;
  final int shopId;
  final int shopEmployeeId;
  final DateTime date;
  final DateTime? checkInAt;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkInAccuracy;
  final DateTime? checkOutAt;
  final double? checkOutLat;
  final double? checkOutLng;
  final double? checkOutAccuracy;
  final int? workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final AttendanceStatus status;
  final bool isManualOverride;
  final String? notes;

  const AttendanceRecord({
    required this.id,
    required this.shopId,
    required this.shopEmployeeId,
    required this.date,
    required this.status,
    this.checkInAt,
    this.checkInLat,
    this.checkInLng,
    this.checkInAccuracy,
    this.checkOutAt,
    this.checkOutLat,
    this.checkOutLng,
    this.checkOutAccuracy,
    this.workedMinutes,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.isManualOverride = false,
    this.notes,
  });

  bool get hasCheckedIn => checkInAt != null;
  bool get hasCheckedOut => checkOutAt != null;

  @override
  List<Object?> get props => [id, date, checkInAt, checkOutAt, status];
}
