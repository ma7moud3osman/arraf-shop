import '../imports/core_imports.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();
  static late final Dio dio;

  static String get baseUrl => _getBaseUrl();

  static Future<void> init() async {
    dio = Dio(
      BaseOptions(
        baseUrl: _getBaseUrl(),
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_authInterceptor());
    dio.interceptors.add(_loggingInterceptor());
  }

  /// Injects `Authorization: Bearer <token>` from secure storage on every
  /// request, and retries once after clearing the token on a 401 so a stale
  /// cache can't wedge the app into a signed-in-but-broken state.
  static Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Skip unauthenticated endpoints (login, register, forgot password).
        if (options.extra['skipAuth'] == true) {
          return handler.next(options);
        }

        final token = await SecureStorageService.instance.readActiveToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final isUnauthorized = e.response?.statusCode == 401;
        final alreadyRetried = e.requestOptions.extra['retriedAfter401'] == true;

        if (!isUnauthorized || alreadyRetried) {
          return handler.next(e);
        }

        // Stale token → drop it and retry once. If the second attempt still
        // 401s, bubble up so the UI can route to login.
        await SecureStorageService.instance.clearActiveToken();

        final retryOptions = Options(
          method: e.requestOptions.method,
          headers: Map<String, dynamic>.from(e.requestOptions.headers)
            ..remove('Authorization'),
          extra: Map<String, dynamic>.from(e.requestOptions.extra)
            ..['retriedAfter401'] = true,
          contentType: e.requestOptions.contentType,
          responseType: e.requestOptions.responseType,
        );

        try {
          final response = await dio.request<dynamic>(
            e.requestOptions.path,
            data: e.requestOptions.data,
            queryParameters: e.requestOptions.queryParameters,
            options: retryOptions,
          );
          return handler.resolve(response);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      },
    );
  }

  static Interceptor _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.info('🌐 [DIO] REQUEST[${options.method}] => PATH: ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.info('✅ [DIO] RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        AppLogger.error('❌ [DIO] ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}');
        return handler.next(e);
      },
    );
  }

  static String _getBaseUrl() {
    return dotenv.get('API_BASE_URL', fallback: 'https://arraf_backend.test/api/');
  }
}
