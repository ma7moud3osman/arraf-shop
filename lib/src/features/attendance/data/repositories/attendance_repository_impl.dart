import 'package:fpdart/fpdart.dart';

import '../../../../services/dio_service.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/entities/attendance_history.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../models/attendance_record_model.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl({DioService? dio})
    : _dio = dio ?? DioService.instance;

  final DioService _dio;

  @override
  FutureEither<AttendanceRecord?> today() async {
    final result = await _dio.get('attendance/today');
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final data = body['data'];
      if (data == null) return right<Failure, AttendanceRecord?>(null);
      return right(
        AttendanceRecordModel.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    });
  }

  @override
  FutureEither<AttendanceRecord> checkIn({
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    final result = await _dio.post(
      'attendance/check-in',
      data: {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      return right(AttendanceRecordModel.fromJson(data));
    });
  }

  @override
  FutureEither<AttendanceRecord> checkOut({
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    final result = await _dio.post(
      'attendance/check-out',
      data: {
        'lat': lat,
        'lng': lng,
        if (accuracy != null) 'accuracy': accuracy,
      },
    );
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);
      return right(AttendanceRecordModel.fromJson(data));
    });
  }

  @override
  FutureEither<AttendanceHistory> history({
    required int year,
    required int month,
  }) async {
    final result = await _dio.get(
      'attendance/me',
      queryParameters: {'year': year, 'month': month},
    );
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final data = body['data'];

      // Tolerate both the legacy list shape (records inline in `data`) and
      // the current envelope shape ({attendances: [...], ...meta}).
      List<dynamic> rawRecords = const [];
      Map<String, dynamic> meta = const {};

      if (data is List) {
        rawRecords = data;
      } else if (data is Map) {
        meta = Map<String, dynamic>.from(data);
        final att = meta['attendances'] ?? meta['records'];
        if (att is List) rawRecords = att;
      }

      final records = rawRecords
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (m) => AttendanceRecordModel.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false);

      final history = AttendanceHistory(
        year: (meta['year'] as int?) ?? year,
        month: (meta['month'] as int?) ?? month,
        daysInMonth: (meta['days_in_month'] as int?) ?? 0,
        isCurrentMonth: (meta['is_current_month'] as bool?) ?? false,
        isFutureMonth: (meta['is_future_month'] as bool?) ?? false,
        workingDays: (meta['working_days'] as int?) ?? 0,
        workingDaysSoFar: (meta['working_days_so_far'] as int?) ?? 0,
        holidayDays: (meta['holiday_days'] as int?) ?? 0,
        presentDays: (meta['present_days'] as int?) ?? 0,
        absentDays: (meta['absent_days'] as int?) ?? 0,
        totalWorkedMinutes: (meta['total_worked_minutes'] as int?) ?? 0,
        totalLateMinutes: (meta['total_late_minutes'] as int?) ?? 0,
        records: records,
      );

      return right<Failure, AttendanceHistory>(history);
    });
  }
}
