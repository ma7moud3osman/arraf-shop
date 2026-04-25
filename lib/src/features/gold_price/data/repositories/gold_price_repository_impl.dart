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
/// Talks to the per-shop endpoints introduced when the gold price moved
/// from country-scoped to shop-scoped:
///   * `GET /api/gold-price` returns the caller's shop 21K base + derived
///     buy/sale maps;
///   * `PUT /api/gold-price` updates the same row (no country, owner or
///     admin only).
///
/// Both responses are adapted into [GoldPriceSnapshot] so the existing
/// UI (which iterates `karat_18` … `karat_24` items) keeps working
/// unchanged.
class GoldPriceRepositoryImpl implements GoldPriceRepository {
  GoldPriceRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  static const List<String> _supportedKarats = ['24', '22', '21', '18'];

  @override
  FutureEither<GoldPriceSnapshot> today() {
    return _run(() async {
      final response = await _dio.get<dynamic>('gold-price');
      return _snapshotFromEnvelope(response.data);
    });
  }

  @override
  FutureEither<GoldPriceSnapshot> update({
    required Map<String, double> updates,
  }) {
    return _run(() async {
      final response = await _dio.put<dynamic>('gold-price', data: updates);
      return _snapshotFromEnvelope(response.data);
    });
  }

  /// Adapts the `{status, message, data}` envelope returned by both the
  /// GET and the PUT into [GoldPriceSnapshot]. Synthesises one
  /// [GoldPriceItem] per supported karat from the `derived_buy` and
  /// `derived_sale` maps the backend computes.
  GoldPriceSnapshot _snapshotFromEnvelope(dynamic body) {
    final envelope =
        body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final data = envelope['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};

    final derivedBuy = _doubleMap(map['derived_buy']);
    final derivedSale = _doubleMap(map['derived_sale']);

    final items = _supportedKarats
        .map(
          (karat) => GoldPriceItem(
            key: 'karat_$karat',
            title: karat,
            subtitle: '',
            sale: derivedSale[karat] ?? 0,
            buy: derivedBuy[karat] ?? 0,
            diff: 0,
            diffType: 'positive',
            isDollar: false,
          ),
        )
        .toList(growable: false);

    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      updatedAt = DateTime.tryParse(raw)?.toLocal();
    }

    final shopId = map['shop_id'];

    return GoldPriceSnapshot(
      shopId: shopId is int ? shopId : (shopId is num ? shopId.toInt() : null),
      updatedAt: updatedAt,
      items: items,
    );
  }

  static Map<String, double> _doubleMap(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    raw.forEach((key, value) {
      final stringKey = key?.toString();
      if (stringKey == null) return;
      if (value is num) {
        out[stringKey] = value.toDouble();
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) out[stringKey] = parsed;
      }
    });
    return out;
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
