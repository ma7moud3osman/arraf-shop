import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

class AppErrorHandler {
  /// Coerces any throwable into a user-facing error string.
  ///
  /// Prioritises:
  /// 1. [DioException] response body — surfaces Laravel validation errors
  ///    (422) and custom `message` fields from the ApiResponder envelope.
  /// 2. Plain [String] errors.
  /// 3. `error.message` if present.
  /// 4. `error.toString()`.
  static String format(dynamic error) {
    if (error is String) return error;

    if (error is DioException) {
      final fromBody = _extractFromDioResponse(error);
      if (fromBody != null && fromBody.isNotEmpty) return fromBody;

      final status = error.response?.statusCode;
      if (status != null) {
        return _fallbackForStatus(status);
      }

      // No HTTP response: connection refused, DNS failure, timeout, etc.
      // Surface a single "no internet" message rather than Dio's raw text.
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'errors.no_internet'.tr();
        default:
          break;
      }
    }

    try {
      final dynamic msg = error?.message;
      if (msg is String && msg.isNotEmpty) return msg;
      final str = error?.toString();
      if (str is String && str.isNotEmpty) return str;
    } catch (_) {}

    return 'errors.unexpected'.tr();
  }

  static String? _extractFromDioResponse(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;

    // Laravel 422: { "message": "...", "errors": { "field": ["msg1"] } }
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final firstList = errors.values.first;
      if (firstList is List && firstList.isNotEmpty) {
        final first = firstList.first;
        if (first is String && first.isNotEmpty) return first;
      }
    }

    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;

    return null;
  }

  static String _fallbackForStatus(int status) {
    return switch (status) {
      401 => 'errors.unauthenticated'.tr(),
      403 => 'errors.forbidden'.tr(),
      404 => 'errors.not_found'.tr(),
      409 => 'errors.conflict'.tr(),
      422 => 'errors.validation'.tr(),
      >= 500 => 'errors.server'.tr(),
      _ => 'errors.request_failed'.tr(namedArgs: {'status': '$status'}),
    };
  }
}
