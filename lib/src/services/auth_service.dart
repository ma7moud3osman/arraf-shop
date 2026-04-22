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
  Stream<Map<String, dynamic>?> get authStateChanges =>
      _authStateController.stream;

  /// Emit an owner user map on the auth-state stream. Called by the
  /// repository after a successful owner branch of [unifiedLogin], since the
  /// repo is the layer that discriminates the role.
  void emitOwnerAuthState(Map<String, dynamic>? user) {
    _authStateController.add(user);
  }

  /// POST /login — unified login for owners + employees.
  ///
  /// Returns the envelope's `data` block:
  /// `{token, role: "owner"|"employee", user: ..., employee: ...}`.
  /// This method owns token persistence: owner tokens go to the owner
  /// slot, employee tokens go to the employee slot. The stream emission
  /// (SessionProvider wiring) is left to the repo since only it knows
  /// which actor landed.
  FutureEither<Map<String, dynamic>?> unifiedLogin({
    required String mobile,
    required String password,
  }) async {
    return runTask(() async {
      final response = await _dio.post<dynamic>(
        'login',
        data: {'mobile': mobile, 'password': password},
        options: Options(extra: {'skipAuth': true}),
      );

      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      final token = data['token'] as String?;
      final role = data['role'] as String?;

      if (token != null && token.isNotEmpty) {
        if (role == 'employee') {
          await _storage.writeEmployeeToken(token);
        } else {
          await _storage.writeOwnerToken(token);
        }
      }

      return data;
    });
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
    });
  }

  /// POST /password/mobile — sends a reset code to the user's mobile.
  FutureEither<void> forgotPassword({required String mobile}) async {
    return runTask(() async {
      await _dio.post<dynamic>(
        'password/mobile',
        data: {'mobile': mobile},
        options: Options(extra: {'skipAuth': true}),
      );
    });
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
    });
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
