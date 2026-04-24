import 'package:equatable/equatable.dart';

/// Slim post-create representation of a purchase invoice. Only the fields
/// the success screen actually renders are modeled — the backend response
/// is much richer.
class PurchaseInvoice extends Equatable {
  final int id;
  final String? invoiceNumber;
  final double total;
  final double subtotal;
  final double discount;
  final double paidAmount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? saleDate;
  final String? pdfShareUrl;
  final List<PurchaseInvoiceItem> items;

  const PurchaseInvoice({
    required this.id,
    required this.total,
    required this.subtotal,
    required this.discount,
    required this.paidAmount,
    required this.items,
    this.invoiceNumber,
    this.paymentMethod,
    this.notes,
    this.saleDate,
    this.pdfShareUrl,
  });

  factory PurchaseInvoice.fake({int id = 99, String? pdfShareUrl}) {
    return PurchaseInvoice(
      id: id,
      invoiceNumber: 'INV-$id',
      total: 12500,
      subtotal: 12000,
      discount: 0,
      paidAmount: 5000,
      paymentMethod: 'cash',
      pdfShareUrl: pdfShareUrl,
      items: [PurchaseInvoiceItem.fake()],
    );
  }

  @override
  List<Object?> get props => [
    id,
    invoiceNumber,
    total,
    subtotal,
    discount,
    paidAmount,
    paymentMethod,
    pdfShareUrl,
    items,
  ];
}

class PurchaseInvoiceItem extends Equatable {
  final int id;
  final String? karat;
  final double weightGrams;
  final double goldPricePerGram;
  final double manufacturingFee;
  final double unitTotal;
  final int? shopItemId;
  final String? imageUrl;
  final String? imageThumbUrl;
  final String? barcode;
  final double? costPrice;

  const PurchaseInvoiceItem({
    required this.id,
    required this.weightGrams,
    required this.goldPricePerGram,
    required this.manufacturingFee,
    required this.unitTotal,
    this.karat,
    this.shopItemId,
    this.imageUrl,
    this.imageThumbUrl,
    this.barcode,
    this.costPrice,
  });

  factory PurchaseInvoiceItem.fake({int id = 1}) {
    return PurchaseInvoiceItem(
      id: id,
      karat: '21',
      weightGrams: 12.5,
      goldPricePerGram: 4000,
      manufacturingFee: 120,
      unitTotal: 12120,
      shopItemId: 7,
      imageThumbUrl: null,
      barcode: 'ARRAF-$id',
      costPrice: 12000,
    );
  }

  @override
  List<Object?> get props => [
    id,
    karat,
    weightGrams,
    goldPricePerGram,
    manufacturingFee,
    unitTotal,
    shopItemId,
    imageUrl,
    imageThumbUrl,
    barcode,
    costPrice,
  ];
}
