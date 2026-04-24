import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_customer_picker_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/item_row_card.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/supplier_picker_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Two-phase wizard mirroring the Filament panel's Create Purchase Invoice
/// flow.
///
/// * **Phase 1 (Items)**: header (supplier / employee / payment / notes /
///   sale date) + items. Two CTAs: "Save as draft" or "Continue → Pieces".
/// * **Phase 2 (Pieces)**: per-piece weight + image entry, then
///   "Create invoice".
///
/// When opened with a [draftId] (resume mode), Phase 1 is bypassed: the
/// header + items are loaded from the server-side draft and locked, and the
/// final CTA calls `completeDraft` instead of `create`.
class CreatePurchaseInvoiceScreen extends StatefulWidget {
  const CreatePurchaseInvoiceScreen({super.key, this.draftId});

  /// When non-null, the wizard loads that draft and starts in Phase 2 with
  /// the items pre-filled and locked.
  final int? draftId;

  @override
  State<CreatePurchaseInvoiceScreen> createState() =>
      _CreatePurchaseInvoiceScreenState();
}

class _CreatePurchaseInvoiceScreenState
    extends State<CreatePurchaseInvoiceScreen> {
  /// Phase index: 0 = header + items, 1 = pieces.
  int _phase = 0;

  // Header text controllers (values flow into the provider on change).
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();

  bool _initializedFromDraft = false;

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null) {
      // Skip directly to Phase 2 once the draft loads.
      _phase = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = context.read<CreatePurchaseInvoiceProvider>();
        await provider.loadDraft(widget.draftId!);
        if (!mounted) return;
        setState(() {
          _discount.text = provider.discount?.toString() ?? '';
          _paid.text = provider.paidAmount?.toString() ?? '';
          _notes.text = provider.notes ?? '';
          _initializedFromDraft = true;
        });
      });
    } else {
      _initializedFromDraft = true;
    }
  }

  @override
  void dispose() {
    _discount.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final picked = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => ChangeNotifierProvider.value(
        value: context.read<ShopCustomerPickerProvider>(),
        child: const SupplierPickerSheet(),
      ),
    );
    if (picked != null && mounted) {
      context.read<CreatePurchaseInvoiceProvider>().setSupplier(picked);
    }
  }

  Future<void> _pickSaleDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          context.read<CreatePurchaseInvoiceProvider>().saleDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null && mounted) {
      context.read<CreatePurchaseInvoiceProvider>().setSaleDate(picked);
    }
  }

  Future<void> _saveDraft() async {
    final provider = context.read<CreatePurchaseInvoiceProvider>();
    final ok = await provider.saveDraft();
    if (!mounted) return;
    if (ok && provider.created != null) {
      // Pop the create screen and push the detail of the new draft so the
      // user can pick up later (or hit "Complete invoice" right away).
      final id = provider.created!.id;
      Navigator.of(context).pop();
      await context.push('${AppRoutes.purchaseInvoices}/$id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'errors.generic'.tr())),
      );
    }
  }

  Future<void> _complete() async {
    final provider = context.read<CreatePurchaseInvoiceProvider>();
    final ok = await provider.complete();
    if (!mounted) return;
    if (ok && provider.created != null) {
      // For resume mode, just pop back so the detail screen refreshes.
      // For fresh create, the detail screen also picks it up after refresh
      // on the list — but we still pop and let the caller refresh.
      final id = provider.created!.id;
      if (provider.isEditingDraft) {
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pop();
        await context.push('${AppRoutes.purchaseInvoices}/$id');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'errors.generic'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();

    if (!_initializedFromDraft || provider.draftLoadStatus.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('purchase_invoice.title'.tr())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.draftId != null && provider.draftLoadStatus.isFailure) {
      return Scaffold(
        appBar: AppBar(title: Text('purchase_invoice.title'.tr())),
        body: Center(
          child: AppErrorWidget(
            title: 'errors.generic'.tr(),
            message: provider.errorMessage,
            onRetry: () => provider.loadDraft(widget.draftId!),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          provider.isEditingDraft
              ? 'purchase_invoice.create.complete_invoice'.tr()
              : 'purchase_invoice.title'.tr(),
        ),
      ),
      body: _phase == 0
          ? _PhaseOne(
              discount: _discount,
              paid: _paid,
              notes: _notes,
              onPickSupplier: _pickSupplier,
              onPickSaleDate: _pickSaleDate,
              onSaveDraft: _saveDraft,
              onContinue: () => setState(() => _phase = 1),
            )
          : _PhaseTwo(
              onBack: provider.isEditingDraft
                  ? null
                  : () => setState(() => _phase = 0),
              onComplete: _complete,
            ),
    );
  }
}

class _PhaseOne extends StatelessWidget {
  const _PhaseOne({
    required this.discount,
    required this.paid,
    required this.notes,
    required this.onPickSupplier,
    required this.onPickSaleDate,
    required this.onSaveDraft,
    required this.onContinue,
  });

  final TextEditingController discount;
  final TextEditingController paid;
  final TextEditingController notes;
  final VoidCallback onPickSupplier;
  final VoidCallback onPickSaleDate;
  final Future<void> Function() onSaveDraft;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();
    final saving = provider.saveDraftStatus.isLoading;

    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        _HeaderSection(
          discount: discount,
          paid: paid,
          notes: notes,
          onPickSupplier: onPickSupplier,
          onPickSaleDate: onPickSaleDate,
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          'purchase_invoice.step_items'.tr(),
          style: context.theme.textTheme.titleMedium,
        ),
        SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < provider.items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: ItemRowCard(
              key: ValueKey('item_$i'),
              index: i,
              draft: provider.items[i],
              canRemove: provider.items.length > 1,
            ),
          ),
        AppButton(
          label: 'purchase_invoice.add_item'.tr(),
          variant: ButtonVariant.outline,
          onPressed: provider.addItem,
        ),
        SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('save_draft_cta'),
          label: 'purchase_invoice.create.save_draft'.tr(),
          variant: ButtonVariant.outline,
          isFullWidth: true,
          isLoading: saving,
          onPressed: (saving || !provider.phaseOneIsValid) ? null : onSaveDraft,
        ),
        SizedBox(height: AppSpacing.sm),
        AppButton(
          key: const Key('continue_to_pieces_cta'),
          label: 'purchase_invoice.create.continue_to_pieces'.tr(),
          isFullWidth: true,
          onPressed: provider.phaseOneIsValid ? onContinue : null,
        ),
      ],
    );
  }
}

class _PhaseTwo extends StatelessWidget {
  const _PhaseTwo({required this.onBack, required this.onComplete});

  final VoidCallback? onBack;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;

    return ListView(
      padding: EdgeInsets.all(AppSpacing.md),
      children: [
        if (provider.isEditingDraft)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'purchase_invoice.create.resume_mode_hint'.tr(),
                style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
              ),
            ),
          ),
        Text(
          'purchase_invoice.step_items'.tr(),
          style: tt.titleMedium,
        ),
        SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < provider.items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: ItemRowCard(
              key: ValueKey('item_$i'),
              index: i,
              draft: provider.items[i],
              canRemove: false,
            ),
          ),
        if (provider.submitBlockers.isNotEmpty) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            'purchase_invoice.review_warning'.tr(),
            style: tt.bodySmall?.copyWith(color: cs.error),
          ),
          for (final b in provider.submitBlockers)
            Text(
              '• ${'purchase_invoice.blocker.${b.key}'.tr(args: ['${b.count}'])}',
              style: tt.bodySmall?.copyWith(color: cs.error),
            ),
        ],
        if (provider.errorMessage != null) ...[
          SizedBox(height: AppSpacing.sm),
          Text(
            provider.errorMessage!,
            style: tt.bodySmall?.copyWith(color: cs.error),
          ),
        ],
        SizedBox(height: AppSpacing.lg),
        AppButton(
          key: const Key('complete_cta'),
          label: 'purchase_invoice.create.complete_invoice'.tr(),
          isFullWidth: true,
          isLoading: provider.status.isLoading,
          onPressed: (provider.status.isLoading || !provider.itemsAreValid)
              ? null
              : onComplete,
        ),
        if (onBack != null) ...[
          SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'shared.back'.tr(),
            variant: ButtonVariant.outline,
            isFullWidth: true,
            onPressed: onBack,
          ),
        ],
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.discount,
    required this.paid,
    required this.notes,
    required this.onPickSupplier,
    required this.onPickSaleDate,
  });

  final TextEditingController discount;
  final TextEditingController paid;
  final TextEditingController notes;
  final VoidCallback onPickSupplier;
  final VoidCallback onPickSaleDate;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();
    final supplier = provider.supplier;
    final saleDate = provider.saleDate;
    final fmt = DateFormat('yyyy-MM-dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPickSupplier,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              labelText: 'purchase_invoice.supplier'.tr(),
            ),
            child: Text(supplier?.name ?? 'purchase_invoice.tap_to_pick'.tr()),
          ),
        ),
        SizedBox(height: 12.h),
        InkWell(
          onTap: onPickSaleDate,
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              labelText: 'purchase_invoice.sale_date'.tr(),
            ),
            child: Text(
              saleDate == null
                  ? 'purchase_invoice.tap_to_pick'.tr()
                  : fmt.format(saleDate),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        DropdownButtonFormField<String>(
          initialValue: provider.paymentMethod,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'purchase_invoice.payment_method'.tr(),
          ),
          items: [
            DropdownMenuItem(
              value: 'cash',
              child: Text('purchase_invoice.payment_methods.cash'.tr()),
            ),
            DropdownMenuItem(
              value: 'card',
              child: Text('purchase_invoice.payment_methods.card'.tr()),
            ),
            DropdownMenuItem(
              value: 'installment',
              child: Text(
                'purchase_invoice.payment_methods.installment'.tr(),
              ),
            ),
            DropdownMenuItem(
              value: 'mixed',
              child: Text('purchase_invoice.payment_methods.mixed'.tr()),
            ),
          ],
          onChanged: provider.setPaymentMethod,
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: discount,
                label: 'purchase_invoice.discount'.tr(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => provider.setDiscount(
                  v.isEmpty ? null : double.tryParse(v),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: AppTextField(
                controller: paid,
                label: 'purchase_invoice.paid_amount'.tr(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => provider.setPaidAmount(
                  v.isEmpty ? null : double.tryParse(v),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        AppTextField(
          controller: notes,
          label: 'purchase_invoice.notes'.tr(),
          maxLines: 3,
          onChanged: provider.setNotes,
        ),
      ],
    );
  }
}
