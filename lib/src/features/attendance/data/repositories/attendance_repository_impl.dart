import 'package:fpdart/fpdart.dart';

import '../../../../services/dio_service.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/typedefs.dart';
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
  FutureEither<List<AttendanceRecord>> history({
    required int year,
    required int month,
  }) async {
    final result = await _dio.get(
      'attendance/me',
      queryParameters: {'year': year, 'month': month},
    );
    return result.flatMap((response) {
      final body = response.data as Map<String, dynamic>;
      final raw = body['data'];
      final list = raw is List ? raw : <dynamic>[];
      final records = list
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => AttendanceRecordModel.fromJson(
                Map<String, dynamic>.from(m),
              ))
          .toList();
      return right<Failure, List<AttendanceRecord>>(records);
    });
  }
}
