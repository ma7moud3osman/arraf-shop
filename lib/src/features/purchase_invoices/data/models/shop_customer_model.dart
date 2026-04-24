import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/shop_customer.dart';

class ShopCustomerModel extends ShopCustomer {
  const ShopCustomerModel({
    required super.id,
    required super.name,
    super.phone,
    super.balance,
  });

  factory ShopCustomerModel.fromJson(Map<String, dynamic> json) {
    return ShopCustomerModel(
      id: parseInt(json['id']),
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      balance: parseDoubleOrNull(json['balance']),
    );
  }
}
