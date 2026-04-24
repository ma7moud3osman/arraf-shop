import '../../../../utils/typedefs.dart';
import '../../../employees/domain/entities/paginated.dart';
import '../entities/purchase_invoice.dart';
import '../entities/purchase_invoice_draft.dart';
import '../entities/purchase_invoice_list_item.dart';

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

/// Repository for the purchase-invoice feature (create flow + owner list).
abstract class PurchaseInvoiceRepository {
  /// `POST /api/shops/my/purchase-invoices` (multipart). Returns the
  /// hydrated invoice on 201, or a [Failure] (typically [ValidationFailure]
  /// for 422) otherwise.
  FutureEither<PurchaseInvoice> create({
    required PurchaseInvoiceDraftHeader header,
    required List<DraftItem> items,
  });

  /// `GET /api/shops/my/purchase-invoices` — paginated list for the
  /// owner-facing Invoices screen. Supports an optional fuzzy [search]
  /// across invoice number / customer name.
  FutureEither<Paginated<PurchaseInvoiceListItem>> list({
    int page = 1,
    int perPage = 20,
    String? search,
  });

  /// `GET /api/shops/my/purchase-invoices/{id}/share-url`. Returns a pre-signed
  /// PDF URL valid for 7 days. Used when re-sharing an existing invoice (the
  /// create response already carries a fresh URL).
  FutureEither<String> fetchShareUrl(int invoiceId);

  /// `GET /api/shops/my/purchase-invoices/{id}` — single invoice detail.
  /// Returns the full hydrated invoice (with items for completed, draft_items
  /// for drafts).
  FutureEither<PurchaseInvoice> fetch(int invoiceId);

  /// `POST /api/shops/my/purchase-invoices/draft` — create a draft (Phase 1
  /// only, no per-piece data). Body mirrors [create] minus the `pieces[]`.
  FutureEither<PurchaseInvoice> createDraft({
    required PurchaseInvoiceDraftHeader header,
    required List<DraftItem> items,
  });

  /// `POST /api/shops/my/purchase-invoices/{id}/pieces` — complete a draft
  /// (multipart) with the per-piece weights + images. Server validates that
  /// items match the draft.
  FutureEither<PurchaseInvoice> completeDraft({
    required int invoiceId,
    required List<DraftItem> items,
  });
}
