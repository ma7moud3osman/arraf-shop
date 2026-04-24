import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Post-create confirmation screen. Shows the new invoice ID + the first
/// piece's thumbnail (when the backend returns one) and the placeholder
/// "Share with supplier" action that task #5 will wire up.
class PurchaseInvoiceCreatedScreen extends StatelessWidget {
  const PurchaseInvoiceCreatedScreen({super.key, required this.invoice});

  final PurchaseInvoice invoice;

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
            // TODO(#5 share-with-supplier): wire to ShareService once the
            // share-link issuing endpoint lands. Disabled until then.
            AppButton(
              label: 'purchase_invoice.created.share'.tr(),
              variant: ButtonVariant.primary,
              isFullWidth: true,
              onPressed: null,
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
