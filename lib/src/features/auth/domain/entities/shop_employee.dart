import 'package:equatable/equatable.dart';

/// Authenticated shop employee — the token-bearing actor behind an
/// employee-mode session.
///
/// Parallels [AppUser] but models the `ShopEmployee` server resource
/// (different token, different endpoint, different scope).
class ShopEmployee extends Equatable {
  final int id;
  final int shopId;
  final String name;
  final String code;
  final String? role;
  final bool isActive;

  const ShopEmployee({
    required this.id,
    required this.shopId,
    required this.name,
    required this.code,
    this.role,
    this.isActive = true,
  });

  factory ShopEmployee.fromJson(Map<String, dynamic> json) {
    // `shop_id` may come in at the top level (new ShopEmployeeResource) OR
    // nested inside `shop.id` (older eager-loaded payloads). Accept either.
    int parseShopId() {
      final direct = json['shop_id'];
      if (direct is num) return direct.toInt();
      final nested = json['shop'];
      if (nested is Map && nested['id'] is num) {
        return (nested['id'] as num).toInt();
      }
      return 0;
    }

    return ShopEmployee(
      id: (json['id'] as num).toInt(),
      shopId: parseShopId(),
      name: json['name'] as String? ?? '',
      code: json['code']?.toString() ?? '',
      role: json['role'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, shopId, name, code, role, isActive];
}
