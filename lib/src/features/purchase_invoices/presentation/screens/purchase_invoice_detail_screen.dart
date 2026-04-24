import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoice_detail_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/services/supplier_share_service.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/share_invoice_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';
import 'package:intl/intl.dart' as intl;

/// Detail view for a single purchase invoice — handles both `is_draft = true`
/// (showing the placeholder draft items + a "Complete invoice" CTA) and
/// completed invoices (full piece list with thumbnails + share action).
class PurchaseInvoiceDetailScreen extends StatefulWidget {
  const PurchaseInvoiceDetailScreen({
    super.key,
    required this.invoiceId,
    this.shareService = const DefaultSupplierShareService(),
  });

  final int invoiceId;

  /// Injected for tests; defaults to the real launcher + share_plus.
  final SupplierShareService shareService;

  @override
  State<PurchaseInvoiceDetailScreen> createState() =>
      _PurchaseInvoiceDetailScreenState();
}

class _PurchaseInvoiceDetailScreenState
    extends State<PurchaseInvoiceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PurchaseInvoiceDetailProvider>();
      if (provider.loadStatus.isInitial) {
        provider.load();
      }
    });
  }

  Future<void> _openShareSheet(PurchaseInvoice invoice) async {
    final pdfUrl = invoice.pdfShareUrl;
    if (pdfUrl == null || pdfUrl.isEmpty) return;
    final supplier = invoice.shopCustomerId == null
        ? null
        : ShopCustomer(
            id: invoice.shopCustomerId!,
            name: invoice.customerName ?? '',
            phone: invoice.customerPhone,
          );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ShareInvoiceSheet(
        invoice: invoice,
        supplier: supplier,
        viewUrl: Uri.parse(pdfUrl),
        shareService: widget.shareService,
      ),
    );
  }

  Future<void> _openCompleteFlow(PurchaseInvoice invoice) async {
    await context.push(
      '${AppRoutes.createPurchaseInvoice}?draftId=${invoice.id}',
    );
    if (!mounted) return;
    await context.read<PurchaseInvoiceDetailProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseInvoiceDetailProvider>();
    final cs = context.theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(
        title: 'purchase_invoice.detail.title'.tr(),
        actions: [
          if (provider.invoice != null && !provider.invoice!.isDraft)
            IconButton(
              key: const Key('share_action'),
              tooltip: 'purchase_invoice.detail.share_cta'.tr(),
              onPressed: () => _openShareSheet(provider.invoice!),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedShare05,
                color: cs.onSurface,
                size: 20.sp,
              ),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(provider)),
    );
  }

  Widget _buildBody(PurchaseInvoiceDetailProvider provider) {
    switch (provider.loadStatus) {
      case AppStatus.initial:
      case AppStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AppStatus.failure:
        return Center(
          child: AppErrorWidget(
            title: 'errors.generic'.tr(),
            message: provider.errorMessage,
            onRetry: provider.refresh,
          ),
        );
      case AppStatus.success:
        final invoice = provider.invoice;
        if (invoice == null) {
          return const SizedBox.shrink();
        }
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: _DetailContent(
            invoice: invoice,
            onComplete: () => _openCompleteFlow(invoice),
          ),
        );
    }
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({required this.invoice, required this.onComplete});

  final PurchaseInvoice invoice;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        _HeaderCard(invoice: invoice),
        if (invoice.isDraft) ...[
          SizedBox(height: AppSpacing.md),
          AppButton(
            key: const Key('complete_invoice_cta'),
            label: 'purchase_invoice.detail.complete_cta'.tr(),
            isFullWidth: true,
            onPressed: onComplete,
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'purchase_invoice.detail.draft_items'.tr(),
            style: context.theme.textTheme.titleMedium,
          ),
          SizedBox(height: AppSpacing.sm),
          for (final draftItem in invoice.draftItems)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DraftItemTile(item: draftItem),
            ),
          if (invoice.draftItems.isEmpty)
            AppEmptyState(title: 'purchase_invoice.detail.no_items'.tr()),
        ] else ...[
          SizedBox(height: AppSpacing.lg),
          Text(
            'purchase_invoice.detail.items'.tr(),
            style: context.theme.textTheme.titleMedium,
          ),
          SizedBox(height: AppSpacing.sm),
          for (final item in invoice.items)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ItemTile(item: item),
            ),
          if (invoice.items.isEmpty)
            AppEmptyState(title: 'purchase_invoice.detail.no_items'.tr()),
        ],
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.invoice});

  final PurchaseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    final dateLabel = invoice.saleDate != null
        ? intl.DateFormat.yMMMd(
            Localizations.localeOf(context).languageCode,
          ).format(invoice.saleDate!)
        : '—';

    return AppCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.invoiceNumber ?? '#${invoice.id}',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                _StatusBadge(isDraft: invoice.isDraft),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 14.sp,
                  color: cs.onSurfaceVariant,
                ),
                SizedBox(width: 4.w),
                Text(
                  dateLabel,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            _Row(
              label: 'purchase_invoice.detail.customer'.tr(),
              value: invoice.customerName ?? '—',
            ),
            _Row(
              label: 'purchase_invoice.detail.total'.tr(),
              value: _money(invoice.total),
              emphasize: true,
            ),
            _Row(
              label: 'purchase_invoice.detail.paid'.tr(),
              value: _money(invoice.paidAmount),
            ),
            if (invoice.paymentMethod != null)
              _Row(
                label: 'purchase_invoice.payment_method'.tr(),
                value:
                    'purchase_invoice.payment_methods.${invoice.paymentMethod}'
                        .tr(),
              ),
          ],
        ),
    );
  }

  String _money(double v) {
    final n = intl.NumberFormat.decimalPattern().format(v);
    return '$n ${'gold_price.currency'.tr()}';
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: emphasize
                ? tt.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  )
                : tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isDraft});

  final bool isDraft;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final bg = isDraft ? cs.tertiaryContainer : cs.primaryContainer;
    final fg = isDraft ? cs.onTertiaryContainer : cs.onPrimaryContainer;
    final label = isDraft
        ? 'purchase_invoice.list.draft_badge'.tr()
        : 'purchase_invoice.list.completed_badge'.tr();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DraftItemTile extends StatelessWidget {
  const _DraftItemTile({required this.item});

  final PurchaseInvoiceDraftItem item;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    return AppCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.shopItemLabel ?? '#${item.shopItemId}',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              'purchase_invoice.pieces_label'.tr(args: ['${item.quantity}']),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'purchase_invoice.weight_total'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Text(
                  '${item.weightGramsTotal.toStringAsFixed(2)} g',
                  style: tt.bodyMedium,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'purchase_invoice.manufacturer_fee'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Text(
                  item.manufacturerFee.toStringAsFixed(2),
                  style: tt.bodyMedium,
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final PurchaseInvoiceItem item;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    final thumb = item.imageThumbUrl ?? item.imageUrl;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            GestureDetector(
              onTap: thumb == null ? null : () => _openFullImage(context, thumb),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: thumb == null
                    ? Container(
                        width: 64.w,
                        height: 64.w,
                        color: cs.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedImage01,
                          size: 22.sp,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : AppCachedImage(
                        imageUrl: thumb,
                        width: 64.w,
                        height: 64.w,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.karat != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${item.karat}K',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '${item.weightGrams.toStringAsFixed(2)} g',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'purchase_invoice.manufacturer_fee'.tr(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        item.manufacturingFee.toStringAsFixed(2),
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'purchase_invoice.detail.total'.tr(),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        item.unitTotal.toStringAsFixed(2),
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  if (item.barcode != null) ...[
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      item.barcode!,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _openFullImage(BuildContext context, String url) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: AppCachedImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}
