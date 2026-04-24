import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../utils/failure.dart';
import '../../../../utils/logger.dart';
import '../../../../utils/typedefs.dart';
import '../../../audits/data/audit_failures.dart';

/// Shared `try { … } catch DioException` helper. Mirrors the inline
/// `_failureFromError` blocks in `EmployeesRepositoryImpl` /
/// `GoldPriceRepositoryImpl` so all purchase-invoice repos surface the
/// same Auth/Forbidden/NotFound/Validation/Network/Server taxonomy.
FutureEither<T> runDio<T>(
  Future<T> Function() action, {
  String tag = 'PurchaseInvoices',
}) async {
  try {
    return Right(await action());
  } catch (error, stackTrace) {
    AppLogger.error('$tag repo task failed: $error', error, stackTrace);
    return Left(failureFromError(error));
  }
}

Failure failureFromError(Object error) {
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
          errors: parseValidationErrors(envelope['errors']),
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

Map<String, List<String>> parseValidationErrors(Object? raw) {
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
