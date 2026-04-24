import 'package:dio/dio.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/entities/shop_item.dart';
import '../../domain/repositories/shop_item_repository.dart';
import '../models/shop_item_model.dart';
import '_dio_failure_mapper.dart';

class ShopItemRepositoryImpl implements ShopItemRepository {
  ShopItemRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  @override
  FutureEither<List<ShopItem>> list({String? search, int perPage = 30}) {
    return runDio<List<ShopItem>>(tag: 'ShopItems', () async {
      final response = await _dio.get<dynamic>(
        'shops/my/shop-items',
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
          .map((m) => ShopItemModel.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    });
  }
}
