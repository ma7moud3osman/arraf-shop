import 'package:arraf_shop/src/config/app_config.dart';
import 'package:arraf_shop/src/utils/error_handler.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/logger.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../domain/entities/audit_report_snapshot.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_session_item.dart';
import '../../domain/repositories/audit_repository.dart';
import '../audit_failures.dart';
import '../models/audit_report_snapshot_model.dart';
import '../models/audit_scan_model.dart';
import '../models/audit_session_item_model.dart';
import '../models/audit_session_model.dart';
import '../models/json_parsing.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  static const _basePath = 'shops/my/audits';

  @override
  FutureEither<Paginated<AuditSession>> list({int page = 1, String? status}) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        _basePath,
        queryParameters: {'page': page, if (status != null) 'status': status},
      );
      return _parsePaginated(
        response.data as Map<String, dynamic>,
        AuditSessionModel.fromJson,
      );
    });
  }

  @override
  FutureEither<AuditSession> start({
    String? notes,
    List<int> participantEmployeeIds = const [],
  }) {
    return _run(() async {
      final response = await _dio.post<dynamic>(
        _basePath,
        data: {
          if (notes != null) 'notes': notes,
          'participant_employee_ids': participantEmployeeIds,
        },
      );
      return AuditSessionModel.fromJson(_unwrapData(response.data));
    });
  }

  @override
  FutureEither<SessionWithScans> show(String uuid) {
    return _run(() async {
      final response = await _dio.get<dynamic>('$_basePath/$uuid');
      final data = _unwrapData(response.data);
      final rawScans = (data['recent_scans'] as List?) ?? const [];
      final scans = rawScans
          .whereType<Map<String, dynamic>>()
          .map(AuditScanModel.fromJson)
          .toList(growable: false);
      return SessionWithScans(
        session: AuditSessionModel.fromJson(data),
        recentScans: scans,
      );
    });
  }

  @override
  FutureEither<ScanResponse> recordScan({
    required String uuid,
    required String barcode,
    required String deviceLabel,
    int? shopEmployeeId,
  }) {
    return _run(() async {
      final response = await _dio.post<dynamic>(
        '$_basePath/$uuid/scans',
        data: {
          'barcode': barcode,
          'device_label': deviceLabel,
          if (shopEmployeeId != null) 'shop_employee_id': shopEmployeeId,
        },
      );
      final data = _unwrapData(response.data);
      return ScanResponse(
        scan: AuditScanModel.fromJson(data['scan'] as Map<String, dynamic>),
        session: AuditSessionModel.fromJson(
          data['session'] as Map<String, dynamic>,
        ),
      );
    });
  }

  @override
  FutureEither<AuditSession> complete(String uuid) {
    return _run(() async {
      final response = await _dio.post<dynamic>('$_basePath/$uuid/complete');
      return AuditSessionModel.fromJson(_unwrapData(response.data));
    });
  }

  @override
  FutureEither<AuditReportSnapshot> summary(String uuid) {
    return _run(() async {
      final response = await _dio.get<dynamic>('$_basePath/$uuid/summary');
      return AuditReportSnapshotModel.fromJson(_unwrapData(response.data));
    });
  }

  @override
  FutureEither<Paginated<AuditSessionItem>> missing(
    String uuid, {
    int page = 1,
  }) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        '$_basePath/$uuid/missing',
        queryParameters: {'page': page},
      );
      return _parsePaginated(
        response.data as Map<String, dynamic>,
        AuditSessionItemModel.fromJson,
      );
    });
  }

  @override
  FutureEither<Paginated<AuditScan>> unexpected(String uuid, {int page = 1}) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        '$_basePath/$uuid/unexpected',
        queryParameters: {'page': page},
      );
      return _parsePaginated(
        response.data as Map<String, dynamic>,
        AuditScanModel.fromJson,
      );
    });
  }

  // --- helpers ---

  /// Wraps an async block in try/catch and returns [FutureEither<T>].
  ///
  /// Mirrors the semantics of `runTask` (see lib/src/utils/task_runner.dart);
  /// Dio surfaces network errors naturally as [DioException] which we map to
  /// a [Failure] here. Tests can therefore drive the repo deterministically.
  FutureEither<T> _run<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } catch (error, stackTrace) {
      // 409 is an expected "barcode already scanned" signal that higher
      // layers surface as a duplicate toast — logging it at ERROR with a
      // stack trace every time is just noise.
      if (error is DioException && error.response?.statusCode == 409) {
        AppLogger.info('Audit repo: conflict ${error.requestOptions.path}');
      } else {
        AppLogger.error('Audit repo task failed: $error', error, stackTrace);
      }
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
        case 409:
          return ConflictFailure(message, error: error);
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
    return ServerFailure(AppErrorHandler.format(error), error: error);
  }

  Map<String, List<String>> _parseValidationErrors(Object? raw) {
    if (raw is! Map<String, dynamic>) return const {};
    return raw.map((field, value) {
      if (value is List) {
        return MapEntry(
          field,
          value.map((e) => e.toString()).toList(growable: false),
        );
      }
      return MapEntry(field, <String>[value.toString()]);
    });
  }

  Map<String, dynamic> _unwrapData(dynamic body) {
    final map = body as Map<String, dynamic>;
    final data = map['data'];
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Response envelope missing "data" object');
  }

  Paginated<T> _parsePaginated<T>(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawItems = (body['data'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(itemFromJson)
        .toList(growable: false);

    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    return Paginated<T>(
      items: items,
      currentPage: parseInt(meta['current_page'], defaultValue: 1),
      perPage: parseInt(meta['per_page'], defaultValue: items.length),
      total: parseInt(meta['total'], defaultValue: items.length),
      lastPage: parseInt(meta['last_page'], defaultValue: 1),
    );
  }
}
