import 'dart:io';

import 'package:arraf_shop/src/features/audits/data/audit_failures.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
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

  group('saveDraft', () {
    test('happy path: calls createDraft and stores the returned invoice',
        () async {
      provider.setItemShopItem(0, makeItem());
      provider.setItemWeightTotal(0, 10);
      provider.setItemQuantity(0, 2);
      provider.setItemManufacturerFee(0, 100);

      repo.createDraftInvoice = PurchaseInvoice.fake(id: 77, isDraft: true);

      final ok = await provider.saveDraft();

      expect(ok, isTrue);
      expect(repo.createDraftCalls, 1);
      expect(provider.saveDraftStatus, AppStatus.success);
      expect(provider.created?.id, 77);
      expect(provider.created?.isDraft, isTrue);
      // No pieces in the draft payload — the repo only cares about items.
      expect(repo.lastDraftItems, hasLength(1));
    });

    test('422: stores validation errors', () async {
      repo.createDraftFailure = const ValidationFailure(
        'oops',
        errors: {
          'items.0.weight_grams_total': ['required'],
        },
      );

      final ok = await provider.saveDraft();

      expect(ok, isFalse);
      expect(provider.saveDraftStatus, AppStatus.failure);
      expect(
        provider.validationErrors['items.0.weight_grams_total'],
        ['required'],
      );
    });
  });

  group('resume flow (loadDraft → complete)', () {
    test('loadDraft switches to editingDraft mode, locks Phase 1 fields',
        () async {
      repo.fetchInvoice = PurchaseInvoice.fake(
        id: 51,
        isDraft: true,
        draftItems: [
          PurchaseInvoiceDraftItem.fake(
            id: 1,
            shopItemId: 9,
            shopItemLabel: 'Bracelets · Lazurde · 21K',
            karat: '21',
            quantity: 2,
            weightGramsTotal: 30,
            manufacturerFee: 150,
          ),
        ],
      );

      final ok = await provider.loadDraft(51);

      expect(ok, isTrue);
      expect(provider.draftInvoiceId, 51);
      expect(provider.mode, CreatePurchaseInvoiceMode.editingDraft);
      expect(provider.isEditingDraft, isTrue);
      expect(provider.items, hasLength(1));
      expect(provider.items.first.shopItem?.id, 9);
      expect(provider.items.first.weightGramsTotal, 30);
      expect(provider.items.first.quantity, 2);
      expect(provider.items.first.pieces, hasLength(2));

      // Phase 1 mutators are ignored in editingDraft mode.
      final before = provider.items.first;
      provider.setItemWeightTotal(0, 99);
      provider.addItem();
      provider.removeItem(0);
      expect(provider.items, hasLength(1));
      expect(provider.items.first, before);
    });

    test('complete() calls completeDraft with draftInvoiceId', () async {
      repo.fetchInvoice = PurchaseInvoice.fake(
        id: 51,
        isDraft: true,
        draftItems: [PurchaseInvoiceDraftItem.fake()],
      );
      await provider.loadDraft(51);

      // Fill per-piece weights so itemsAreValid allows complete.
      for (var j = 0; j < provider.items.first.pieces.length; j++) {
        provider.setPieceWeight(0, j, 10);
      }

      repo.completeDraftInvoice = PurchaseInvoice.fake(id: 51);

      final ok = await provider.complete();

      expect(ok, isTrue);
      expect(repo.completeDraftCalls, 1);
      expect(repo.lastCompletedDraftId, 51);
      expect(provider.created?.id, 51);
      expect(provider.created?.isDraft, isFalse);
    });

    test('loadDraft failure surfaces the error and stays in creating mode',
        () async {
      repo.fetchFailure = const ServerFailure('nope');
      final ok = await provider.loadDraft(99);
      expect(ok, isFalse);
      expect(provider.mode, CreatePurchaseInvoiceMode.creating);
      expect(provider.errorMessage, 'nope');
    });
  });

  group('phaseOneIsValid', () {
    test('false while an item is missing shopItem or weight, true when set',
        () {
      expect(provider.phaseOneIsValid, isFalse);
      provider.setItemShopItem(0, makeItem());
      expect(provider.phaseOneIsValid, isFalse, reason: 'weight is still 0');
      provider.setItemWeightTotal(0, 10);
      expect(provider.phaseOneIsValid, isTrue);
    });
  });
}
