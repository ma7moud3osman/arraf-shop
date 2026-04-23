import 'dart:async';
import 'dart:io' show HttpClient, Platform;

import '../imports/core_imports.dart';
import '../services/session_expired_handler.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

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

    dio.interceptors.add(_localeInterceptor());
    dio.interceptors.add(_authInterceptor());
    if (kDebugMode) {
      dio.interceptors.add(_prettyLogger());
    }

    _trustLocalDevHost(dio);
  }

  /// Read by [_localeInterceptor] to stamp `Accept-Language` on every
  /// request. Set from the app root once EasyLocalization is ready so
  /// Laravel can localize validation + domain error messages.
  static String currentLocale = 'en';

  /// Injects `Accept-Language: <locale>` on every outbound call. Laravel
  /// picks this up via the SetLocaleFromHeader middleware and localizes
  /// any `__(...)` string it emits.
  static Interceptor _localeInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Accept-Language'] = currentLocale;
        return handler.next(options);
      },
    );
  }

  /// In debug builds, trust the self-signed cert that Laravel Herd issues for
  /// `*.test` hosts so the device/simulator can talk to the local backend.
  /// Skipped on web (no `dart:io`) and disabled in release builds.
  static void _trustLocalDevHost(Dio dio) {
    if (kReleaseMode || kIsWeb) return;
    final host = Uri.tryParse(_getBaseUrl())?.host ?? '';
    if (!host.endsWith('.test')) return;

    final adapter = dio.httpClientAdapter;
    if (adapter is! IOHttpClientAdapter) return;

    adapter.createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (_, certHost, _) => certHost == host;
      return client;
    };
    AppLogger.warning(
      '🔓 Trusting self-signed cert for local dev host: $host '
      '(${Platform.operatingSystem})',
    );
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
        final alreadyRetried =
            e.requestOptions.extra['retriedAfter401'] == true;
        final skipAuth = e.requestOptions.extra['skipAuth'] == true;

        // 401 on a skipAuth endpoint (login/register) is a legitimate
        // "wrong credentials" response — surface it to the caller, don't
        // treat it as a session-expired event.
        if (!isUnauthorized || skipAuth) {
          return handler.next(e);
        }

        if (alreadyRetried) {
          // Second 401 after a token-less retry → the session really is
          // dead. Wipe everything and route the user back to login with a
          // toast so they know why.
          unawaited(SessionExpiredHandler.handle());
          return handler.next(e);
        }

        // Stale token → drop it and retry once. If the second attempt still
        // 401s, the branch above fires the session-expired flow.
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
          if (retryError.response?.statusCode == 401) {
            unawaited(SessionExpiredHandler.handle());
          }
          return handler.next(retryError);
        }
      },
    );
  }

  static Interceptor _prettyLogger() {
    return PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
      compact: true,
      maxWidth: 120,
    );
  }

  static String _getBaseUrl() {
    return dotenv.get(
      'API_BASE_URL',
      fallback: 'https://arraf_backend.test/api/',
    );
  }
}
