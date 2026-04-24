import 'dart:io';

import 'package:arraf_shop/src/features/purchase_invoices/data/repositories/purchase_invoice_repository_impl.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_draft.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/repositories/purchase_invoice_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildFormData emits Laravel-shaped nested keys + multipart files',
    () async {
      final tmpDir = await Directory.systemTemp.createTemp('piv_form_');
      final imageA = await File('${tmpDir.path}/a.jpg').create();
      await imageA.writeAsBytes(const [0xFF, 0xD8, 0xFF]);
      final imageB = await File('${tmpDir.path}/b.jpg').create();
      await imageB.writeAsBytes(const [0xFF, 0xD8, 0xFF]);

      final header = PurchaseInvoiceDraftHeader(
        shopCustomerId: 7,
        supplierName: 'El-Sayed',
        paymentMethod: 'cash',
        discount: 50,
        paidAmount: 1000,
        saleDate: DateTime(2026, 4, 24),
      );

      final items = [
        DraftItem(
          shopItem: ShopItem.fake(id: 11),
          weightGramsTotal: 25,
          quantity: 2,
          manufacturerFee: 120,
          pieces: [
            DraftPiece(weight: 12, image: imageA),
            DraftPiece(image: imageB),
          ],
        ),
      ];

      final formData = buildFormData(header: header, items: items);
      final fieldKeys = formData.fields.map((e) => e.key).toList();
      final fileKeys = formData.files.map((e) => e.key).toList();

      // Header fields.
      expect(
        fieldKeys,
        containsAll(<String>[
          'shop_customer_id',
          'supplier_name',
          'discount',
          'paid_amount',
          'payment_method',
          'sale_date',
        ]),
      );
      expect(
        formData.fields.firstWhere((f) => f.key == 'sale_date').value,
        '2026-04-24',
      );

      // Item + piece nesting.
      expect(
        fieldKeys,
        containsAll(<String>[
          'items[0][shop_item_id]',
          'items[0][weight_grams_total]',
          'items[0][quantity]',
          'items[0][manufacturer_fee]',
          'items[0][pieces][0][weight]',
        ]),
      );

      // Two image files at the expected nested keys.
      expect(
        fileKeys,
        containsAll(<String>[
          'items[0][pieces][0][image]',
          'items[0][pieces][1][image]',
        ]),
      );
      expect(formData.files, hasLength(2));
    },
  );
}
