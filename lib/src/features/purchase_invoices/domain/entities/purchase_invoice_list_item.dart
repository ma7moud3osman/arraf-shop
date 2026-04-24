import 'package:equatable/equatable.dart';

/// Slim invoice card for the owner-facing Invoices list. Mirrors
/// `PurchaseInvoiceListResource` on the backend — kept separate from
/// the rich [PurchaseInvoice] entity so the list view doesn't drag in
/// per-piece detail it never renders.
class PurchaseInvoiceListItem extends Equatable {
  final int id;
  final String? invoiceNumber;
  final DateTime? saleDate;
  final double total;
  final double paidAmount;
  final String? paymentMethod;
  final String? status;
  final String? customerName;
  final int? customerId;
  final int itemsCount;
  final String? firstImageThumbUrl;

  const PurchaseInvoiceListItem({
    required this.id,
    required this.total,
    required this.paidAmount,
    required this.itemsCount,
    this.invoiceNumber,
    this.saleDate,
    this.paymentMethod,
    this.status,
    this.customerName,
    this.customerId,
    this.firstImageThumbUrl,
  });

  factory PurchaseInvoiceListItem.fake({
    int id = 1,
    String invoiceNumber = 'P-001',
    String? customerName = 'Ahmed Mostafa',
    double total = 1500,
    int itemsCount = 3,
  }) {
    return PurchaseInvoiceListItem(
      id: id,
      invoiceNumber: invoiceNumber,
      saleDate: DateTime(2026, 4, 24),
      total: total,
      paidAmount: total,
      paymentMethod: 'cash',
      status: 'completed',
      customerName: customerName,
      customerId: customerName == null ? null : 1,
      itemsCount: itemsCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceNumber,
        saleDate,
        total,
        paidAmount,
        paymentMethod,
        status,
        customerName,
        customerId,
        itemsCount,
        firstImageThumbUrl,
      ];
}
