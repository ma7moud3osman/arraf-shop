import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/services/supplier_share_service.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Three-option share sheet shown after a purchase invoice is created.
/// Options: WhatsApp the supplier, native share sheet, open the invoice
/// view URL.
///
/// The [shareService] is injected so widget tests can record the launches
/// without touching the platform channels.
class ShareInvoiceSheet extends StatelessWidget {
  const ShareInvoiceSheet({
    super.key,
    required this.invoice,
    required this.supplier,
    required this.viewUrl,
    required this.shareService,
  });

  final PurchaseInvoice invoice;
  final ShopCustomer? supplier;
  final Uri viewUrl;
  final SupplierShareService shareService;

  String _composeMessage() {
    final ref = invoice.invoiceNumber ?? '#${invoice.id}';
    return 'purchase_invoice.share.message'.tr(args: [ref, viewUrl.toString()]);
  }

  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final phone = normalizeWhatsAppPhone(supplier?.phone);
    if (phone == null) return;
    final uri = buildWhatsAppUri(phoneDigits: phone, message: _composeMessage());
    final ok = await shareService.openUrl(uri);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('purchase_invoice.share.launch_failed'.tr())),
      );
    }
  }

  Future<void> _shareViaSheet(BuildContext context) async {
    await shareService.shareText(
      _composeMessage(),
      subject: 'purchase_invoice.share.subject'.tr(),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openInvoiceUrl(BuildContext context) async {
    final ok = await shareService.openUrl(viewUrl);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('purchase_invoice.share.launch_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final hasPhone = normalizeWhatsAppPhone(supplier?.phone) != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'purchase_invoice.share.title'.tr(),
                style: tt.titleMedium,
              ),
            ),
            _ShareOptionTile(
              key: const Key('share_option_whatsapp'),
              icon: HugeIcons.strokeRoundedWhatsapp,
              label: 'purchase_invoice.share.whatsapp'.tr(),
              tooltip:
                  hasPhone
                      ? null
                      : 'purchase_invoice.share.no_phone_tooltip'.tr(),
              onTap: hasPhone ? () => _shareViaWhatsApp(context) : null,
            ),
            _ShareOptionTile(
              key: const Key('share_option_native'),
              icon: HugeIcons.strokeRoundedShare05,
              label: 'purchase_invoice.share.native'.tr(),
              onTap: () => _shareViaSheet(context),
            ),
            _ShareOptionTile(
              key: const Key('share_option_pdf'),
              icon: HugeIcons.strokeRoundedFile02,
              label: 'purchase_invoice.share.view_pdf'.tr(),
              onTap: () => _openInvoiceUrl(context),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: HugeIcon(icon: icon, color: context.theme.colorScheme.onSurface),
      title: Text(label),
      enabled: onTap != null,
      onTap: onTap,
    );
    if (tooltip == null) return tile;
    return Tooltip(message: tooltip!, child: tile);
  }
}
