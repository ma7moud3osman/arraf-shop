import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

import 'package:arraf_shop/src/features/auth/domain/entities/auth_result.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/user.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService = AuthService.instance;

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return _authService.authStateChanges.map((userData) {
      if (userData == null) return null;
      return AppUser(
        id: userData['id']?.toString() ?? '',
        email: (userData['email'] as String?) ?? '',
        name: userData['name'] as String?,
        photoUrl: userData['photoUrl'] as String?,
        isAdmin: _isAdminFromJson(userData),
      );
    });
  }

  @override
  FutureEither<AuthResult> login({
    required String mobile,
    required String password,
  }) async {
    final result = await _authService.unifiedLogin(
      mobile: mobile,
      password: password,
    );

    return result.flatMap((payload) {
      if (payload == null) {
        return left(const ServerFailure('Login failed: empty response'));
      }

      final role = payload['role'] as String?;
      switch (role) {
        case 'owner':
          final userRaw = payload['user'] as Map<String, dynamic>?;
          if (userRaw == null) {
            return left(const ServerFailure('Login response missing user'));
          }
          _authService.emitOwnerAuthState(userRaw);
          final user = AppUser(
            id: userRaw['id'].toString(),
            email: (userRaw['email'] as String?) ?? '',
            name: userRaw['name'] as String?,
            photoUrl: userRaw['photoUrl'] as String?,
            isAdmin: _isAdminFromJson(userRaw),
          );
          return right<Failure, AuthResult>(OwnerAuthResult(user));

        case 'employee':
          final empRaw = payload['employee'] as Map<String, dynamic>?;
          if (empRaw == null) {
            return left(const ServerFailure('Login response missing employee'));
          }
          return right<Failure, AuthResult>(
            EmployeeAuthResult(ShopEmployee.fromJson(empRaw)),
          );

        default:
          return left(ServerFailure('Unknown actor role: $role'));
      }
    });
  }

  @override
  FutureEither<AppUser> signUp({
    required String name,
    required String email,
    required String mobile,
    required String password,
    String? gender,
  }) async {
    final result = await _authService.signUp(
      name: name,
      email: email,
      password: password,
      mobile: mobile,
      gender: gender,
    );

    return result.flatMap((userData) {
      if (userData == null) {
        return left(
          const ServerFailure('Sign up failed: User record corrupted'),
        );
      }

      final data = userData['user'] ?? userData;
      final user = AppUser(
        id: data['id'].toString(),
        email: data['email'] ?? email,
        name: name,
      );

      return right(user);
    });
  }

  @override
  FutureEither<void> forgotPassword({required String mobile}) {
    return _authService.forgotPassword(mobile: mobile);
  }

  @override
  FutureEither<void> logout() {
    return _authService.logout();
  }

  /// Tolerant parser: backend returns `is_admin` as a bool from
  /// `UserResource`, but old caches / OAuth payloads may still carry the
  /// `role` string. Accept either, default to false.
  static bool _isAdminFromJson(Map<String, dynamic> raw) {
    final flag = raw['is_admin'];
    if (flag is bool) return flag;
    if (flag is num) return flag != 0;
    if (flag is String) {
      return flag == '1' || flag.toLowerCase() == 'true';
    }
    final role = raw['role'];
    return role is String && role == 'admin';
  }

  @override
  FutureEither<AppUser?> checkAuthState() async {
    final result = await _authService.getCurrentUser();

    return result.map((userData) {
      if (userData == null) return null;

      return AppUser(
        id: userData['id']?.toString() ?? '',
        email: (userData['email'] as String?) ?? '',
        name: userData['name'] as String?,
        photoUrl: userData['photoUrl'] as String?,
        isAdmin: _isAdminFromJson(userData),
      );
    });
  }
}
