import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShopEmployee.fromJson', () {
    test('parses a full payload', () {
      final emp = ShopEmployee.fromJson(const {
        'id': 11,
        'shop_id': 7,
        'name': 'Ali',
        'code': 'EMP-001',
        'role': 'sales',
        'is_active': true,
      });

      expect(emp.id, 11);
      expect(emp.shopId, 7);
      expect(emp.name, 'Ali');
      expect(emp.code, 'EMP-001');
      expect(emp.role, 'sales');
      expect(emp.isActive, isTrue);
    });

    test('coerces numeric-string code to string', () {
      final emp = ShopEmployee.fromJson(const {
        'id': 1,
        'shop_id': 1,
        'name': 'X',
        'code': 12345,
      });
      expect(emp.code, '12345');
    });

    test('defaults optional fields gracefully', () {
      final emp = ShopEmployee.fromJson(const {
        'id': 2,
        'shop_id': 3,
        'name': 'Y',
        'code': 'C2',
      });
      expect(emp.role, isNull);
      expect(emp.isActive, isTrue);
    });

    test('equatable by value', () {
      final a = ShopEmployee.fromJson(const {
        'id': 1,
        'shop_id': 1,
        'name': 'a',
        'code': 'x',
      });
      final b = ShopEmployee.fromJson(const {
        'id': 1,
        'shop_id': 1,
        'name': 'a',
        'code': 'x',
      });
      expect(a, equals(b));
    });
  });
}
