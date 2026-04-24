import 'package:arraf_shop/src/features/purchase_invoices/data/models/purchase_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PurchaseInvoiceModel.fromJson parses supplier_name + pdf_share_url',
    () {
      final json = <String, dynamic>{
        'id': 42,
        'invoice_number': 'INV-42',
        'total': '12500.00',
        'subtotal': '12000.00',
        'discount': '0.00',
        'paid_amount': '5000.00',
        'payment_method': 'cash',
        'supplier_name': 'El-Sayed',
        'pdf_share_url': 'https://share.example/inv/42?signature=xyz',
        'sale_date': '2026-04-24',
        'items': const <Map<String, dynamic>>[],
      };

      final invoice = PurchaseInvoiceModel.fromJson(json);

      expect(invoice.id, 42);
      expect(invoice.supplierName, 'El-Sayed');
      expect(
        invoice.pdfShareUrl,
        'https://share.example/inv/42?signature=xyz',
      );
    },
  );
}
