import '../../../../utils/typedefs.dart';
import '../entities/purchase_invoice.dart';
import '../entities/purchase_invoice_draft.dart';

/// Top-level header fields for the wizard, kept separate from [DraftItem]
/// so the items list can be tested in isolation.
class PurchaseInvoiceDraftHeader {
  final int? shopCustomerId;
  final int? shopEmployeeId;
  final double? discount;
  final double? paidAmount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? saleDate;

  const PurchaseInvoiceDraftHeader({
    this.shopCustomerId,
    this.shopEmployeeId,
    this.discount,
    this.paidAmount,
    this.paymentMethod,
    this.notes,
    this.saleDate,
  });
}

/// Write-only repository for the create-purchase-invoice flow.
abstract class PurchaseInvoiceRepository {
  /// `POST /api/shops/my/purchase-invoices` (multipart). Returns the
  /// hydrated invoice on 201, or a [Failure] (typically [ValidationFailure]
  /// for 422) otherwise.
  FutureEither<PurchaseInvoice> create({
    required PurchaseInvoiceDraftHeader header,
    required List<DraftItem> items,
  });

  /// `GET /api/shops/my/purchase-invoices/{id}/share-url`. Returns a pre-signed
  /// PDF URL valid for 7 days. Used when re-sharing an existing invoice (the
  /// create response already carries a fresh URL).
  FutureEither<String> fetchShareUrl(int invoiceId);
}
