import 'dart:async';
import '../utils/utils.dart';
import '../config/app_config.dart';
import 'secure_storage_service.dart';
import 'package:dio/dio.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Dio get _dio => AppConfig.dio;
  SecureStorageService get _storage => SecureStorageService.instance;

  // Custom Backend doesn't have a built-in auth state stream, so we manage our own.
  final StreamController<Map<String, dynamic>?> _authStateController =
      StreamController<Map<String, dynamic>?>.broadcast();

  /// Stream of auth state changes. Emits the current user map or null.
  Stream<Map<String, dynamic>?> get authStateChanges => _authStateController.stream;

  /// POST /signin — returns raw `{user, token}` (no envelope).
  FutureEither<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    return runTask(() async {
      final response = await _dio.post<dynamic>(
        'signin',
        data: {'email': email, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );
      final body = response.data as Map<String, dynamic>;
      final user = body['user'] as Map<String, dynamic>?;
      final token = body['token'] as String?;

      if (token != null) {
        await _storage.writeOwnerToken(token);
      }

      _authStateController.add(user);
      return user;
    }, requiresNetwork: true);
  }

  /// POST /register — envelope-wrapped `{status, message, data: {user, token}}`.
  FutureEither<Map<String, dynamic>?> signUp({
    required String name,
    required String email,
    required String password,
    String? mobile,
    String? gender,
  }) async {
    return runTask(() async {
      final response = await _dio.post<dynamic>(
        'register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (mobile != null) 'mobile': mobile,
          if (gender != null) 'gender': gender,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      final user = data['user'] as Map<String, dynamic>?;
      final token = data['token'] as String?;

      if (token != null) {
        await _storage.writeOwnerToken(token);
      }

      _authStateController.add(user);
      return user;
    }, requiresNetwork: true);
  }

  /// POST /password/email — no body in response beyond the envelope.
  FutureEither<void> forgotPassword({required String email}) async {
    return runTask(() async {
      await _dio.post<dynamic>(
        'password/email',
        data: {'email': email},
        options: Options(extra: {'skipAuth': true}),
      );
    }, requiresNetwork: true);
  }

  /// POST /sign-out — invalidates the server token, clears local storage.
  FutureEither<void> logout() async {
    return runTask(() async {
      try {
        await _dio.post<dynamic>('sign-out');
      } finally {
        await _storage.clearActiveToken();
        _authStateController.add(null);
      }
    }, requiresNetwork: true);
  }

  /// GET /profile — JsonResource-wrapped `{data: {...user fields...}}`.
  FutureEither<Map<String, dynamic>?> getCurrentUser() async {
    return runTask(() async {
      final response = await _dio.get<dynamic>('profile');
      final body = response.data as Map<String, dynamic>;
      final user = (body['data'] as Map<String, dynamic>?) ?? body;
      return user;
    });
  }

  void dispose() {
    _authStateController.close();
  }
}
