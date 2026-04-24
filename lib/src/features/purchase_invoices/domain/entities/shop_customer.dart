import 'package:equatable/equatable.dart';

/// Lightweight shop customer used as the "supplier" / merchant in the
/// purchase-invoice flow. Mirrors `ShopCustomerApiResource` from the
/// backend.
class ShopCustomer extends Equatable {
  final int id;
  final String name;
  final String? phone;
  final double? balance;

  const ShopCustomer({
    required this.id,
    required this.name,
    this.phone,
    this.balance,
  });

  factory ShopCustomer.fake({
    int id = 1,
    String name = 'El-Sayed Gold Trading',
    String? phone = '+201111111111',
  }) {
    return ShopCustomer(id: id, name: name, phone: phone, balance: 0);
  }

  @override
  List<Object?> get props => [id, name, phone, balance];
}
