import 'dart:io';

import 'package:arraf_shop/src/features/audits/data/audit_failures.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_fakes.dart';

void main() {
  late FakePurchaseInvoiceRepository repo;
  late CreatePurchaseInvoiceProvider provider;

  setUp(() {
    repo = FakePurchaseInvoiceRepository();
    provider = CreatePurchaseInvoiceProvider(repository: repo);
  });

  tearDown(() {
    provider.dispose();
  });

  ShopItem makeItem({int id = 1}) => ShopItem.fake(id: id);

  group('items', () {
    test('starts with one empty draft item', () {
      expect(provider.items, hasLength(1));
      expect(provider.items.first.shopItem, isNull);
    });

    test('addItem appends; removeItem keeps at least one', () {
      provider.addItem();
      provider.addItem();
      expect(provider.items, hasLength(3));

      provider.removeItem(2);
      provider.removeItem(1);
      provider.removeItem(0); // refused — keeps last one
      expect(provider.items, hasLength(1));
    });

    test('setItemQuantity resizes the pieces list (preserving entries)', () {
      provider.setItemQuantity(0, 3);
      expect(provider.items.first.pieces, hasLength(3));

      provider.setPieceWeight(0, 0, 7.5);
      provider.setItemQuantity(0, 5);
      expect(provider.items.first.pieces, hasLength(5));
      expect(provider.items.first.pieces.first.weight, 7.5);

      provider.setItemQuantity(0, 2);
      expect(provider.items.first.pieces, hasLength(2));
      expect(provider.items.first.pieces.first.weight, 7.5);
    });

    test('quantity below 1 is clamped to 1', () {
      provider.setItemQuantity(0, 0);
      expect(provider.items.first.quantity, 1);
      expect(provider.items.first.pieces, hasLength(1));
    });
  });

  group('itemsAreValid', () {
    test(
      'requires shop item, weight, image AND per-piece weight on every piece',
      () async {
        // 2 items × 2 pieces.
        provider.addItem();
        for (final i in [0, 1]) {
          provider.setItemShopItem(i, makeItem(id: i + 1));
          provider.setItemWeightTotal(i, 10);
          provider.setItemQuantity(i, 2);
          provider.setItemManufacturerFee(i, 100);
        }
        expect(provider.itemsAreValid, isFalse, reason: 'no images yet');

        final tmpDir = await Directory.systemTemp.createTemp('piv_test_');
        final file = await File('${tmpDir.path}/x.jpg').create();
        await file.writeAsBytes(const [0, 1, 2, 3]);

        // Attach images on every piece — still missing per-piece weights.
        for (final i in [0, 1]) {
          for (final j in [0, 1]) {
            provider.setPieceImage(i, j, file);
          }
        }
        expect(
          provider.itemsAreValid,
          isFalse,
          reason: 'per-piece weight still missing',
        );
        expect(
          provider.submitBlockers.any((b) => b.key == 'missing_piece_weight'),
          isTrue,
        );

        // Fill weights on every piece — now valid.
        for (final i in [0, 1]) {
          for (final j in [0, 1]) {
            provider.setPieceWeight(i, j, 5);
          }
        }
        expect(provider.itemsAreValid, isTrue);
        expect(provider.submitBlockers, isEmpty);
      },
    );

    test(
      'image blocker is debug-aware: missing image is not a blocker in debug',
      () async {
        provider.setItemShopItem(0, makeItem());
        provider.setItemWeightTotal(0, 10);
        provider.setItemQuantity(0, 2);
        provider.setPieceWeight(0, 0, 5);
        provider.setPieceWeight(0, 1, 5);

        // Tests run under kDebugMode = true, so missing piece image must
        // NOT block submission. Production builds re-enable the rule.
        expect(provider.itemsAreValid, isTrue);
        expect(
          provider.submitBlockers.where((b) => b.key == 'missing_piece_image'),
          isEmpty,
        );
      },
    );
  });

  group('submit', () {
    test('success: returns true, stores `created`, flips to success', () async {
      final ok = await provider.submit();
      expect(ok, isTrue);
      expect(provider.status, AppStatus.success);
      expect(provider.created, isNotNull);
      expect(repo.createCalls, 1);
    });

    test('422: stores validation errors, flips to failure', () async {
      repo.failure = const ValidationFailure(
        'Validation failed',
        errors: {
          'items.0.shop_item_id': ['required'],
        },
      );

      final ok = await provider.submit();

      expect(ok, isFalse);
      expect(provider.status, AppStatus.failure);
      expect(provider.errorMessage, 'Validation failed');
      expect(provider.validationErrors['items.0.shop_item_id'], ['required']);
    });
  });
}
