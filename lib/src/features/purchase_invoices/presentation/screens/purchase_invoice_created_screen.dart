import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/services/supplier_share_service.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/share_invoice_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Post-create confirmation screen. Shows the new invoice ID + the first
/// piece's thumbnail (when the backend returns one) and a "Share" action
/// that opens a sheet with three paths: WhatsApp the supplier, native
/// share sheet, or open the invoice's view URL.
class PurchaseInvoiceCreatedScreen extends StatelessWidget {
  const PurchaseInvoiceCreatedScreen({
    super.key,
    required this.invoice,
    this.supplier,
    this.shareService = const DefaultSupplierShareService(),
    this.viewUrl,
  });

  final PurchaseInvoice invoice;

  /// The supplier the invoice was issued against. Used to pre-fill the
  /// WhatsApp share. May be `null` when the invoice was created with a
  /// free-text supplier name only.
  final ShopCustomer? supplier;

  /// Injected for tests; defaults to the real launcher + share_plus.
  final SupplierShareService shareService;

  /// Override for tests. In production we derive a Filament panel URL
  /// from the API base URL since no public PDF endpoint exists yet (see
  /// task #5 follow-up).
  final Uri? viewUrl;

  Uri _resolveViewUrl() {
    if (viewUrl != null) return viewUrl!;
    final base = AppConfig.baseUrl;
    final apiUri = Uri.parse(base);
    final root = apiUri.replace(path: '');
    return root.replace(path: '/shop-owner/purchase-invoices/${invoice.id}');
  }

  Future<void> _openShareSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (_) => ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: _resolveViewUrl(),
            shareService: shareService,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final firstThumb =
        invoice.items.isEmpty
            ? null
            : invoice.items.first.imageThumbUrl ?? invoice.items.first.imageUrl;

    return Scaffold(
      appBar: AppBar(title: Text('purchase_invoice.created.title'.tr())),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: context.theme.colorScheme.primary,
              size: 72.r,
            ),
            SizedBox(height: 12.h),
            Text(
              'purchase_invoice.created.heading'.tr(
                args: [invoice.invoiceNumber ?? '#${invoice.id}'],
              ),
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'purchase_invoice.created.subtitle'.tr(
                args: ['${invoice.items.length}'],
              ),
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            if (firstThumb != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: AppCachedImage(
                  imageUrl: firstThumb,
                  width: 160.w,
                  height: 160.w,
                  fit: BoxFit.cover,
                ),
              ),
            const Spacer(),
            AppButton(
              key: const Key('share_with_supplier_button'),
              label: 'purchase_invoice.created.share'.tr(),
              variant: ButtonVariant.primary,
              isFullWidth: true,
              onPressed: () => _openShareSheet(context),
            ),
            SizedBox(height: 8.h),
            AppButton(
              label: 'purchase_invoice.created.done'.tr(),
              variant: ButtonVariant.outline,
              isFullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
