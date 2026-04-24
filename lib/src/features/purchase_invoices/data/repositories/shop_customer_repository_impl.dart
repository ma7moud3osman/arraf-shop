import 'package:dio/dio.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/entities/shop_customer.dart';
import '../../domain/repositories/shop_customer_repository.dart';
import '../models/shop_customer_model.dart';
import '_dio_failure_mapper.dart';

class ShopCustomerRepositoryImpl implements ShopCustomerRepository {
  ShopCustomerRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  @override
  FutureEither<List<ShopCustomer>> list({String? search, int perPage = 30}) {
    return runDio<List<ShopCustomer>>(tag: 'ShopCustomers', () async {
      final response = await _dio.get<dynamic>(
        'shops/my/customers',
        queryParameters: {
          'per_page': perPage,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      final body = response.data;
      final raw = body is Map<String, dynamic> ? body['data'] : null;
      final list = raw is List ? raw : const <dynamic>[];
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => ShopCustomerModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    });
  }
}
