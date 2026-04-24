import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/purchase_invoice.dart';

class PurchaseInvoiceItemModel extends PurchaseInvoiceItem {
  const PurchaseInvoiceItemModel({
    required super.id,
    required super.weightGrams,
    required super.goldPricePerGram,
    required super.manufacturingFee,
    required super.unitTotal,
    super.karat,
    super.shopItemId,
    super.imageUrl,
    super.imageThumbUrl,
    super.barcode,
    super.costPrice,
  });

  factory PurchaseInvoiceItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final productMap =
        product is Map ? Map<String, dynamic>.from(product) : null;

    return PurchaseInvoiceItemModel(
      id: parseInt(json['id']),
      karat: json['karat']?.toString(),
      weightGrams: parseDouble(json['weight_grams']),
      goldPricePerGram: parseDouble(json['gold_price_per_gram']),
      manufacturingFee: parseDouble(json['manufacturing_fee']),
      unitTotal: parseDouble(json['unit_total']),
      shopItemId: parseIntOrNull(productMap?['shop_item_id']),
      imageUrl: productMap?['image_url'] as String?,
      imageThumbUrl: productMap?['image_thumb_url'] as String?,
      barcode: productMap?['barcode'] as String?,
      costPrice: parseDoubleOrNull(productMap?['cost_price']),
    );
  }
}

class PurchaseInvoiceModel extends PurchaseInvoice {
  const PurchaseInvoiceModel({
    required super.id,
    required super.total,
    required super.subtotal,
    required super.discount,
    required super.paidAmount,
    required super.items,
    super.invoiceNumber,
    super.paymentMethod,
    super.notes,
    super.saleDate,
  });

  factory PurchaseInvoiceModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items =
        rawItems is List
            ? rawItems
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (m) => PurchaseInvoiceItemModel.fromJson(
                    Map<String, dynamic>.from(m),
                  ),
                )
                .toList(growable: false)
            : const <PurchaseInvoiceItem>[];

    return PurchaseInvoiceModel(
      id: parseInt(json['id']),
      invoiceNumber: json['invoice_number'] as String?,
      total: parseDouble(json['total']),
      subtotal: parseDouble(json['subtotal']),
      discount: parseDouble(json['discount']),
      paidAmount: parseDouble(json['paid_amount']),
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      saleDate: parseDateTime(json['sale_date']),
      items: items,
    );
  }
}
