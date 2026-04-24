import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/typedefs.dart';
import '../../../audits/data/audit_failures.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/shop_settings_repository.dart';

/// Dio-backed [ShopSettingsRepository]. Failure mapping mirrors
/// `GoldPriceRepositoryImpl` so providers can switch on the concrete
/// subtype.
class ShopSettingsRepositoryImpl implements ShopSettingsRepository {
  ShopSettingsRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  static const _path = 'shops/my/settings';

  @override
  FutureEither<ShopSettings> fetch() {
    return _run(() async {
      final response = await _dio.get<dynamic>(_path);
      return _parse(response.data);
    });
  }

  @override
  FutureEither<ShopSettings> update(List<int> weeklyHolidays) {
    return _run(() async {
      final response = await _dio.put<dynamic>(
        _path,
        data: {'weekly_holidays': weeklyHolidays},
      );
      return _parse(response.data);
    });
  }

  ShopSettings _parse(dynamic body) {
    final envelope =
        body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final raw = envelope['data'];
    final data =
        raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    final list = data['weekly_holidays'];
    final days = list is List
        ? list
            .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
            .whereType<int>()
            .where((d) => d >= 1 && d <= 7)
            .toList(growable: false)
        : const <int>[];
    return ShopSettings(weeklyHolidays: days);
  }

  // --- helpers (mirrors GoldPriceRepositoryImpl._run / _failureFromError) ---

  FutureEither<T> _run<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } on _FailureBox catch (boxed) {
      return left(boxed.failure);
    } catch (error, stackTrace) {
      AppLogger.error('ShopSettings repo task failed: $error', error, stackTrace);
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

class _FailureBox implements Exception {
  _FailureBox(this.failure);
  final Failure failure;
}
