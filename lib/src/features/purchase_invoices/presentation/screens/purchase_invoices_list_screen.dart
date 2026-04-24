import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_list_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoices_list_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';
import 'package:intl/intl.dart' as intl;

/// Owner-only Invoices tab. Lists the shop's purchase invoices with a
/// debounced search bar, pull-to-refresh, infinite-scroll pagination,
/// and a FAB to launch the existing create-invoice wizard.
class PurchaseInvoicesListScreen extends StatefulWidget {
  const PurchaseInvoicesListScreen({super.key});

  @override
  State<PurchaseInvoicesListScreen> createState() =>
      _PurchaseInvoicesListScreenState();
}

class _PurchaseInvoicesListScreenState
    extends State<PurchaseInvoicesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PurchaseInvoicesListProvider>();
      if (provider.status == AppStatus.initial) {
        provider.load();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      final provider = context.read<PurchaseInvoicesListProvider>();
      if (provider.status == AppStatus.success && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    await context.push(AppRoutes.createPurchaseInvoice);
    if (!mounted) return;
    // The create wizard returns nothing; refresh to surface any newly
    // posted invoice without making the user pull-to-refresh.
    await context.read<PurchaseInvoicesListProvider>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseInvoicesListProvider>();
    final cs = context.theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(title: 'purchase_invoice.list.title'.tr()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: cs.onPrimary,
          size: 20.sp,
        ),
        label: Text('purchase_invoice.title'.tr()),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _SearchField(
                controller: _searchController,
                onChanged: provider.setSearch,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: _buildBody(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(PurchaseInvoicesListProvider provider) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        if (provider.invoices.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildList(provider);
      case AppStatus.failure:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppErrorWidget(
              title: 'errors.generic'.tr(),
              message: provider.errorMessage,
              onRetry: provider.refresh,
            ),
          ],
        );
      case AppStatus.success:
        if (provider.invoices.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              AppEmptyState(
                title: 'purchase_invoice.list.empty'.tr(),
              ),
            ],
          );
        }
        return _buildList(provider);
    }
  }

  Widget _buildList(PurchaseInvoicesListProvider provider) {
    final items = provider.invoices;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        // extra bottom padding so the FAB doesn't overlap the last row
        AppSpacing.xl + 56.h,
      ),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _PagingFooter(
            status: provider.moreStatus,
            hasMore: provider.hasMore,
          );
        }
        return _InvoiceTile(
          invoice: items[index],
          onTap: () => showToast(
            context,
            message: 'purchase_invoice.list.coming_soon'.tr(),
            status: 'info',
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'purchase_invoice.list.search_hint'.tr(),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: cs.onSurfaceVariant,
            size: 18.sp,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'common.clear'.tr(),
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.onTap});

  final PurchaseInvoiceListItem invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final dateLabel = invoice.saleDate != null
        ? intl.DateFormat.yMMMd(
            Localizations.localeOf(context).languageCode,
          ).format(invoice.saleDate!)
        : '—';

    final totalLabel = _formatCurrency(invoice.total);

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(url: invoice.firstImageThumbUrl),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invoice.invoiceNumber ?? '#${invoice.id}',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _CountBadge(count: invoice.itemsCount),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      invoice.customerName ?? '—',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
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
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          totalLabel,
                          style: tt.titleSmall?.copyWith(
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
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    final number = intl.NumberFormat.decimalPattern().format(value);
    return '$number ${'gold_price.currency'.tr()}';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final size = 48.w;

    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedInvoice03,
          size: 22.sp,
          color: cs.onSurfaceVariant,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          width: size,
          height: size,
          color: cs.surfaceContainerHighest,
        ),
        errorWidget: (_, _, _) => Container(
          width: size,
          height: size,
          color: cs.surfaceContainerHighest,
          alignment: Alignment.center,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedInvoice03,
            size: 22.sp,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'purchase_invoice.list.items_count_badge'.tr(args: ['$count']),
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PagingFooter extends StatelessWidget {
  const _PagingFooter({required this.status, required this.hasMore});

  final AppStatus status;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore && status != AppStatus.loading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: status == AppStatus.failure
            ? Text(
                'errors.generic'.tr(),
                style: TextStyle(color: context.theme.colorScheme.error),
              )
            : const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
