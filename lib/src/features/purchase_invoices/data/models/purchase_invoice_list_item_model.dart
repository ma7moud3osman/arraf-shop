import '../../../audits/data/models/json_parsing.dart';
import '../../domain/entities/purchase_invoice_list_item.dart';

class PurchaseInvoiceListItemModel extends PurchaseInvoiceListItem {
  const PurchaseInvoiceListItemModel({
    required super.id,
    required super.total,
    required super.paidAmount,
    required super.itemsCount,
    super.invoiceNumber,
    super.saleDate,
    super.paymentMethod,
    super.status,
    super.customerName,
    super.customerId,
    super.firstImageThumbUrl,
    super.isDraft,
  });

  factory PurchaseInvoiceListItemModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final customerMap =
        customer is Map ? Map<String, dynamic>.from(customer) : null;

    return PurchaseInvoiceListItemModel(
      id: parseInt(json['id']),
      invoiceNumber: json['invoice_number'] as String?,
      saleDate: parseDateTime(json['sale_date']),
      total: parseDouble(json['total']),
      paidAmount: parseDouble(json['paid_amount']),
      paymentMethod: json['payment_method'] as String?,
      status: json['status'] as String?,
      customerName: customerMap?['name'] as String?,
      customerId: parseIntOrNull(customerMap?['id']),
      itemsCount: parseInt(json['items_count']),
      firstImageThumbUrl: json['first_image_thumb_url'] as String?,
      isDraft: json['is_draft'] == true,
    );
  }
}
