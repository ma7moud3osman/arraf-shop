import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/failure.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/typedefs.dart';
import '../../../audits/data/audit_failures.dart';
import '../../domain/entities/gold_price_item.dart';
import '../../domain/entities/gold_price_snapshot.dart';
import '../../domain/repositories/gold_price_repository.dart';

/// Dio-backed implementation of [GoldPriceRepository].
///
/// `GET /api/goldprice/today?is_list=1` returns the karat list used by the
/// read screen; `PUT /api/gold-price` is the admin write endpoint added in
/// the backend's gold price update feature.
class GoldPriceRepositoryImpl implements GoldPriceRepository {
  GoldPriceRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  @override
  FutureEither<GoldPriceSnapshot> today({String country = 'eg'}) {
    return _run(() async {
      final response = await _dio.get<dynamic>(
        'goldprice/today',
        queryParameters: {'country': country, 'is_list': 1},
      );
      final data = response.data;
      final List<dynamic> rawItems = data is Map<String, dynamic>
          ? (data['data'] as List? ?? const [])
          : const [];
      final items = rawItems
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => GoldPriceItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return GoldPriceSnapshot(
        country: country,
        updatedAt: DateTime.now(),
        items: items,
      );
    });
  }

  @override
  FutureEither<GoldPriceSnapshot> update({
    String country = 'eg',
    required Map<String, double> updates,
  }) {
    return _run(() async {
      final response = await _dio.put<dynamic>(
        'gold-price',
        data: {'country': country, ...updates},
      );

      // The endpoint wraps the model with `GoldPriceResource`; the rich
      // realtime payload (with formatted items) flows over Pusher.
      // For the immediate HTTP response we ask `today` again so the
      // returned snapshot uses the same shape consumed everywhere else.
      final body = response.data;
      if (body is Map<String, dynamic> &&
          body['data'] is Map<String, dynamic>) {
        // Best-effort: try to derive items from the resource if it carries a
        // raw karat map. Otherwise fall back to a re-fetch.
      }
      final refreshed = await today(country: country);
      return refreshed.match(
        (failure) => throw _FailureBox(failure),
        (snapshot) => snapshot,
      );
    });
  }

  // --- helpers (mirrors AuditRepositoryImpl._run / _failureFromError) ---

  FutureEither<T> _run<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } on _FailureBox catch (boxed) {
      return left(boxed.failure);
    } catch (error, stackTrace) {
      AppLogger.error('GoldPrice repo task failed: $error', error, stackTrace);
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

/// Internal sentinel so `_run` can unwrap a downstream [Failure] without
/// double-wrapping it as a server error.
class _FailureBox implements Exception {
  _FailureBox(this.failure);
  final Failure failure;
}
