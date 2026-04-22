import 'package:dio/dio.dart';

import 'package:arraf_shop/src/config/app_config.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/employee_auth_repository.dart';
import 'package:arraf_shop/src/services/secure_storage_service.dart';
import 'package:arraf_shop/src/utils/utils.dart';

/// Dio-backed implementation of [EmployeeAuthRepository].
///
/// `runTask` wraps every call so network + unexpected errors surface as
/// [Failure] values on the Left side of the returned Either.
class EmployeeAuthRepositoryImpl implements EmployeeAuthRepository {
  EmployeeAuthRepositoryImpl({Dio? dio, SecureStorageService? storage})
      : _dio = dio ?? AppConfig.dio,
        _storage = storage ?? SecureStorageService.instance;

  final Dio _dio;
  final SecureStorageService _storage;

  @override
  FutureEither<ShopEmployee> me() async {
    return runTask(() async {
      final response = await _dio.get<dynamic>('shop-employees/me');
      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return ShopEmployee.fromJson(Map<String, dynamic>.from(data));
    });
  }

  @override
  FutureEither<void> logout() async {
    return runTask(() async {
      try {
        await _dio.post<dynamic>('shop-employees/logout');
      } finally {
        // Always drop local auth even if the server call failed — a stale
        // token on the device is worse than a best-effort sign-out.
        await _storage.clearActiveToken();
      }
    });
  }
}
