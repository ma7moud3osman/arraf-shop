import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/entities/attendance_status.dart';

class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.id,
    required super.shopId,
    required super.shopEmployeeId,
    required super.date,
    required super.status,
    super.checkInAt,
    super.checkInLat,
    super.checkInLng,
    super.checkInAccuracy,
    super.checkOutAt,
    super.checkOutLat,
    super.checkOutLng,
    super.checkOutAccuracy,
    super.workedMinutes,
    super.lateMinutes,
    super.earlyLeaveMinutes,
    super.isManualOverride,
    super.notes,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: parseInt(json['id']),
      shopId: parseInt(json['shop_id']),
      shopEmployeeId: parseInt(json['shop_employee_id']),
      date: parseDateTime(json['date']) ?? DateTime.now(),
      status: AttendanceStatus.fromString(
        (json['status'] as String?) ?? 'present',
      ),
      checkInAt: parseDateTime(json['check_in_at']),
      checkInLat: parseDoubleOrNull(json['check_in_lat']),
      checkInLng: parseDoubleOrNull(json['check_in_lng']),
      checkInAccuracy: parseDoubleOrNull(json['check_in_accuracy']),
      checkOutAt: parseDateTime(json['check_out_at']),
      checkOutLat: parseDoubleOrNull(json['check_out_lat']),
      checkOutLng: parseDoubleOrNull(json['check_out_lng']),
      checkOutAccuracy: parseDoubleOrNull(json['check_out_accuracy']),
      workedMinutes: parseIntOrNull(json['worked_minutes']),
      lateMinutes: parseIntOrNull(json['late_minutes']) ?? 0,
      earlyLeaveMinutes: parseIntOrNull(json['early_leave_minutes']) ?? 0,
      isManualOverride: (json['is_manual_override'] as bool?) ?? false,
      notes: json['notes'] as String?,
    );
  }
}
