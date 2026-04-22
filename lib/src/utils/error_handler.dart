import 'package:dio/dio.dart';

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
    }

    try {
      final dynamic msg = error?.message;
      if (msg is String && msg.isNotEmpty) return msg;
      final str = error?.toString();
      if (str is String && str.isNotEmpty) return str;
    } catch (_) {}

    return 'An unexpected error occurred';
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
      401 => 'You are not signed in.',
      403 => 'You do not have permission to do that.',
      404 => 'Not found.',
      409 => 'Conflict — please try again.',
      422 => 'Some of the information you entered is invalid.',
      >= 500 => 'Server error. Please try again.',
      _ => 'Request failed ($status).',
    };
  }
}
