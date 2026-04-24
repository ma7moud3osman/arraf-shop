import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/typedefs.dart';
import '../../../attendance/data/models/attendance_record_model.dart';
import '../../../attendance/domain/entities/attendance_record.dart';
import '../../../audits/data/audit_failures.dart';
import '../../../payroll/data/models/payslip_model.dart';
import '../../../payroll/domain/entities/payslip.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_profile.dart';
import '../../domain/entities/month_calendar.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/employees_repository.dart';
import '../models/employee_model.dart';
import '../models/month_calendar_model.dart';

/// Dio-backed implementation of [EmployeesRepository]. Failure mapping
/// mirrors `GoldPriceRepositoryImpl` (Auth/Forbidden/NotFound/Validation/
/// Network/Server) so providers can switch on the concrete subtype
/// without re-parsing HTTP details.
class EmployeesRepositoryImpl implements EmployeesRepository {
  EmployeesRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  static const _basePath = 'shops/my/employees';

  @override
  FutureEither<Paginated<Employee>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        _basePath,
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      return _parsePaginated<Employee>(
        response.data,
        EmployeeModel.fromJson,
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    });
  }

  @override
  FutureEither<EmployeeProfile> show(int employeeId) {
    return _run(() async {
      final response = await _dio.get<dynamic>('$_basePath/$employeeId');
      final body = response.data as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(body['data'] as Map);

      final employee = EmployeeModel.fromJson(
        Map<String, dynamic>.from(data['employee'] as Map),
      );

      final attendance = (data['recent_attendance'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (m) => AttendanceRecordModel.fromJson(Map<String, dynamic>.from(m)),
          )
          .toList(growable: false);

      final payroll = (data['recent_payroll'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => PayslipModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);

      return EmployeeProfile(
        employee: employee,
        recentAttendance: attendance.cast<AttendanceRecord>(),
        recentPayroll: payroll.cast<Payslip>(),
      );
    });
  }

  @override
  FutureEither<MonthCalendar> attendance(
    int employeeId, {
    int? year,
    int? month,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        '$_basePath/$employeeId/attendance',
        queryParameters: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      final body = response.data as Map<String, dynamic>;
      return MonthCalendarModel.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
    });
  }

  @override
  FutureEither<Paginated<Payslip>> payroll(
    int employeeId, {
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        '$_basePath/$employeeId/payroll',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      return _parsePaginated<Payslip>(
        response.data,
        (m) => PayslipModel.fromJson(m),
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    });
  }

  @override
  FutureEither<Paginated<Payslip>> shopPayroll({
    int page = 1,
    int perPage = 24,
    int? year,
    int? month,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        'shops/my/payroll',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      return _parsePaginated<Payslip>(
        response.data,
        (m) => PayslipModel.fromJson(m),
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    });
  }

  // --- helpers ---

  Paginated<T> _parsePaginated<T>(
    dynamic body,
    T Function(Map<String, dynamic>) fromJson, {
    required int fallbackPage,
    required int fallbackPerPage,
  }) {
    final envelope =
        body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final raw = envelope['data'];
    final list = raw is List ? raw : const <dynamic>[];
    final items = list
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    final meta = envelope['meta'];
    if (meta is Map<String, dynamic>) {
      return Paginated<T>(
        items: items,
        currentPage: _intFrom(meta['current_page']) ?? fallbackPage,
        perPage: _intFrom(meta['per_page']) ?? fallbackPerPage,
        total: _intFrom(meta['total']) ?? items.length,
        lastPage: _intFrom(meta['last_page']) ?? fallbackPage,
      );
    }
    return Paginated<T>(
      items: items,
      currentPage: fallbackPage,
      perPage: fallbackPerPage,
      total: items.length,
      lastPage: fallbackPage,
    );
  }

  int? _intFrom(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  FutureEither<T> _run<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } catch (error, stackTrace) {
      AppLogger.error('Employees repo task failed: $error', error, stackTrace);
      return left(_failureFromError(error));
    }
  }

  Failure _failureFromError(Object error) {
    if (error is DioException) {
      final response = error.response;
      final body = response?.data;
      final envelope =
          body is Map<String, dynamic> ? body : const <String, dynamic>{};
      final message =
          (envelope['message'] as String?) ?? error.message ?? 'Request failed';

      switch (response?.statusCode) {
        case 401:
          return AuthFailure(message, error: error);
        case 403:
          return ForbiddenFailure(message, error: error);
        case 404:
          return NotFoundFailure(message, error: error);
        case 422:
          return ValidationFailure(
            message,
            errors: _parseValidationErrors(envelope['errors']),
            error: error,
          );
      }

      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkFailure(message, error: error);
        default:
          return ServerFailure(message, error: error);
      }
    }
    return UnknownFailure(error.toString(), error: error);
  }

  Map<String, List<String>> _parseValidationErrors(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<String>>{};
    raw.forEach((key, value) {
      if (key is! String) return;
      if (value is List) {
        out[key] = value.whereType<String>().toList(growable: false);
      } else if (value is String) {
        out[key] = [value];
      }
    });
    return out;
  }
}
