import 'package:equatable/equatable.dart';

/// Slim representation of a purchase invoice. Used by both the post-create
/// success screen and the detail screen — the backend response is much
/// richer; we only model fields the UI renders.
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
  final bool isDraft;
  final String? status;
  final int? shopCustomerId;
  final String? customerName;
  final String? customerPhone;
  final List<PurchaseInvoiceItem> items;
  final List<PurchaseInvoiceDraftItem> draftItems;

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
    this.isDraft = false,
    this.status,
    this.shopCustomerId,
    this.customerName,
    this.customerPhone,
    this.draftItems = const [],
  });

  factory PurchaseInvoice.fake({
    int id = 99,
    String? pdfShareUrl,
    bool isDraft = false,
    List<PurchaseInvoiceItem>? items,
    List<PurchaseInvoiceDraftItem>? draftItems,
    String? customerName = 'El-Sayed Gold Trading',
  }) {
    return PurchaseInvoice(
      id: id,
      invoiceNumber: 'INV-$id',
      total: 12500,
      subtotal: 12000,
      discount: 0,
      paidAmount: 5000,
      paymentMethod: 'cash',
      pdfShareUrl: pdfShareUrl,
      isDraft: isDraft,
      status: isDraft ? 'draft' : 'completed',
      customerName: customerName,
      shopCustomerId: customerName == null ? null : 1,
      items: items ?? (isDraft ? const [] : [PurchaseInvoiceItem.fake()]),
      draftItems:
          draftItems ?? (isDraft ? [PurchaseInvoiceDraftItem.fake()] : const []),
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
    isDraft,
    status,
    shopCustomerId,
    customerName,
    customerPhone,
    items,
    draftItems,
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
  final String? shopItemLabel;
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
    this.shopItemLabel,
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

/// Pending line on a draft invoice — no per-piece weights/images yet.
/// Mirrors the backend's `draft_items[]` payload.
class PurchaseInvoiceDraftItem extends Equatable {
  final int id;
  final int shopItemId;
  final String? shopItemLabel;
  final String? karat;
  final int quantity;
  final double weightGramsTotal;
  final double manufacturerFee;

  const PurchaseInvoiceDraftItem({
    required this.id,
    required this.shopItemId,
    required this.quantity,
    required this.weightGramsTotal,
    required this.manufacturerFee,
    this.shopItemLabel,
    this.karat,
  });

  factory PurchaseInvoiceDraftItem.fake({
    int id = 1,
    int shopItemId = 7,
    String? shopItemLabel = 'Bracelets · Lazurde · 21K',
    String? karat = '21',
    int quantity = 2,
    double weightGramsTotal = 25,
    double manufacturerFee = 120,
  }) {
    return PurchaseInvoiceDraftItem(
      id: id,
      shopItemId: shopItemId,
      shopItemLabel: shopItemLabel,
      karat: karat,
      quantity: quantity,
      weightGramsTotal: weightGramsTotal,
      manufacturerFee: manufacturerFee,
    );
  }

  @override
  List<Object?> get props => [
    id,
    shopItemId,
    shopItemLabel,
    karat,
    quantity,
    weightGramsTotal,
    manufacturerFee,
  ];
}
