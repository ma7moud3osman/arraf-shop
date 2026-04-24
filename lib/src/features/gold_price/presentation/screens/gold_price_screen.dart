import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../shared/helpers/show_toast.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/gold_price_item.dart';
import '../providers/gold_price_provider.dart';
import '../widgets/edit_gold_price_dialog.dart';

/// Read-only by default; admin owners get a FAB that opens the edit dialog.
///
/// All clients (including non-admins) subscribe to the public `gold-price`
/// Pusher channel via [GoldPriceProvider] — display refreshes in place
/// whenever an admin pushes a new price.
class GoldPriceScreen extends StatefulWidget {
  const GoldPriceScreen({super.key});

  @override
  State<GoldPriceScreen> createState() => _GoldPriceScreenState();
}

class _GoldPriceScreenState extends State<GoldPriceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GoldPriceProvider>();
      if (provider.status == AppStatus.initial) {
        provider.load();
      }
    });
  }

  Future<void> _openEditDialog() async {
    final provider = context.read<GoldPriceProvider>();
    final snapshot = provider.snapshot;
    if (snapshot == null) return;

    final updates = await EditGoldPriceDialog.show(context, snapshot);
    if (!mounted || updates == null || updates.isEmpty) return;

    final error = await provider.update(updates);
    if (!mounted) return;

    if (error != null) {
      showToast(context, message: error, status: 'error');
    } else {
      showToast(
        context,
        message: 'gold_price.updated_successfully'.tr(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<GoldPriceProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(title: 'gold_price.title'.tr()),
      floatingActionButton: auth.isAdmin && provider.snapshot != null
          ? FloatingActionButton.extended(
              key: const ValueKey('gold-price-edit-fab'),
              onPressed: _openEditDialog,
              icon: const Icon(Icons.edit_outlined),
              label: Text('gold_price.edit_action'.tr()),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: provider.refresh,
          child: _buildBody(provider),
        ),
      ),
    );
  }

  Widget _buildBody(GoldPriceProvider provider) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        if (provider.snapshot == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildList(_visibleItems(provider.snapshot!.items));
      case AppStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              provider.errorMessage ?? 'errors.generic'.tr(),
              textAlign: TextAlign.center,
            ),
          ),
        );
      case AppStatus.success:
        final items = _visibleItems(
          provider.snapshot?.items ?? const <GoldPriceItem>[],
        );
        if (items.isEmpty) {
          return Center(child: Text('gold_price.empty'.tr()));
        }
        return _buildList(items);
    }
  }

  // Hide unit rows that aren't relevant to the shop's day-to-day —
  // ounce / pound / ounce-in-USD aren't part of the 21K-anchored flow.
  static const _hiddenKeys = {'ounce', 'pound', 'ounce_dollar'};

  List<GoldPriceItem> _visibleItems(List<GoldPriceItem> items) =>
      items.where((i) => !_hiddenKeys.contains(i.key)).toList();

  Widget _buildList(List<GoldPriceItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _GoldPriceTile(item: item);
      },
    );
  }
}

class _GoldPriceTile extends StatelessWidget {
  const _GoldPriceTile({required this.item});

  final GoldPriceItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final positive = item.diffType == 'positive';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.sale.toStringAsFixed(2),
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${positive ? '+' : ''}${item.diff.toStringAsFixed(2)}',
                  style: tt.bodySmall?.copyWith(
                    color: positive ? Colors.green : cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
