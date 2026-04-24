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

/// Groups the flat list of pieces returned by the API back into the
/// ShopItem buckets the panel originally created. Stable order: groups
/// appear in the order their first piece appeared in the response.
List<_ItemGroup> _groupByShopItem(List<PurchaseInvoiceItem> pieces) {
  final byKey = <String, _ItemGroup>{};
  final order = <String>[];
  for (final p in pieces) {
    final key = p.shopItemId?.toString() ?? 'piece-${p.id}';
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = _ItemGroup(
        keyId: key,
        shopItemId: p.shopItemId,
        label: p.shopItemLabel,
        karat: p.karat,
        manufacturingFee: p.manufacturingFee,
        pieces: [p],
      );
      order.add(key);
    } else {
      existing.pieces.add(p);
    }
  }
  return [for (final k in order) byKey[k]!];
}

class _ItemGroup {
  _ItemGroup({
    required this.keyId,
    required this.shopItemId,
    required this.label,
    required this.karat,
    required this.manufacturingFee,
    required this.pieces,
  });
  final String keyId;
  final int? shopItemId;
  final String? label;
  final String? karat;
  final double manufacturingFee;
  final List<PurchaseInvoiceItem> pieces;

  double get totalWeight =>
      pieces.fold<double>(0, (a, p) => a + p.weightGrams);
  double get totalAmount =>
      pieces.fold<double>(0, (a, p) => a + p.unitTotal);
  int get quantity => pieces.length;
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
          for (final group in _groupByShopItem(invoice.items))
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ItemGroupCard(group: group),
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

String _money(BuildContext context, double v) {
  final n = intl.NumberFormat.decimalPattern().format(v);
  return '$n ${'gold_price.currency'.tr()}';
}

String _grams(double v) {
  final n = intl.NumberFormat.decimalPattern().format(v);
  return '$n ${'units.g'.tr()}';
}

class _ItemGroupCard extends StatelessWidget {
  const _ItemGroupCard({required this.group});

  final _ItemGroup group;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        // Remove ExpansionTile's default divider borders that look off
        // inside AppCard's rounded container.
        data: context.theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  group.label ?? '#${group.shopItemId ?? ''}',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (group.karat != null) ...[
                SizedBox(width: 8.w),
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
                    '${group.karat}K',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'purchase_invoice.pieces_label'.tr(args: ['${group.quantity}']),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  _grams(group.totalWeight),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  _money(context, group.totalAmount),
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          children: [
            _KeyValue(
              label: 'purchase_invoice.manufacturer_fee'.tr(),
              value: _money(context, group.manufacturingFee),
            ),
            Divider(height: AppSpacing.lg, color: cs.outlineVariant),
            for (var i = 0; i < group.pieces.length; i++) ...[
              _PieceRow(index: i + 1, piece: group.pieces[i]),
              if (i != group.pieces.length - 1)
                Divider(height: AppSpacing.lg, color: cs.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});
  final String label;
  final String value;

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
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.index, required this.piece});
  final int index;
  final PurchaseInvoiceItem piece;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    final thumb = piece.imageThumbUrl ?? piece.imageUrl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: thumb == null ? null : () => _openFullImage(context, thumb),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: thumb == null
                ? Container(
                    width: 56.w,
                    height: 56.w,
                    color: cs.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImage01,
                      size: 20.sp,
                      color: cs.onSurfaceVariant,
                    ),
                  )
                : AppCachedImage(
                    imageUrl: thumb,
                    width: 56.w,
                    height: 56.w,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'purchase_invoice.piece_n'.tr(args: ['$index']),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _grams(piece.weightGrams),
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _money(context, piece.unitTotal),
                    style: tt.bodyMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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
