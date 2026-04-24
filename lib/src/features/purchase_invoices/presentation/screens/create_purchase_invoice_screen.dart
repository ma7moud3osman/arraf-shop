import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_customer_picker_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/purchase_invoice_created_screen.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/item_row_card.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/supplier_picker_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Three-step wizard mirroring the Filament panel's Create Purchase
/// Invoice flow. Steps:
///  1. Header (supplier / employee / payment / notes / sale date)
///  2. Items + pieces (each piece carries an intake photo)
///  3. Review + submit
class CreatePurchaseInvoiceScreen extends StatefulWidget {
  const CreatePurchaseInvoiceScreen({super.key});

  @override
  State<CreatePurchaseInvoiceScreen> createState() =>
      _CreatePurchaseInvoiceScreenState();
}

class _CreatePurchaseInvoiceScreenState
    extends State<CreatePurchaseInvoiceScreen> {
  int _step = 0;

  // Header text controllers (values flow into the provider on change).
  final _supplierName = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _supplierName.dispose();
    _discount.dispose();
    _paid.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final picked = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetCtx) => ChangeNotifierProvider.value(
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

  Future<void> _submit() async {
    final provider = context.read<CreatePurchaseInvoiceProvider>();
    final ok = await provider.submit();
    if (!mounted) return;
    if (ok && provider.created != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder:
              (_) => PurchaseInvoiceCreatedScreen(
                invoice: provider.created!,
                supplier: provider.supplier,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage ?? 'errors.generic'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();
    final isLast = _step == 2;

    return Scaffold(
      appBar: AppBar(title: Text('purchase_invoice.title'.tr())),
      body: Stepper(
        currentStep: _step,
        onStepContinue: () {
          if (isLast) {
            _submit();
          } else {
            setState(() => _step += 1);
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step -= 1);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                AppButton(
                  label:
                      isLast
                          ? 'purchase_invoice.submit'.tr()
                          : 'shared.next'.tr(),
                  onPressed:
                      (provider.status.isLoading ||
                              (isLast && !provider.itemsAreValid))
                          ? null
                          : details.onStepContinue,
                  isLoading: isLast && provider.status.isLoading,
                ),
                SizedBox(width: 8.w),
                if (_step > 0)
                  AppButton(
                    label: 'shared.back'.tr(),
                    variant: ButtonVariant.outline,
                    onPressed: details.onStepCancel,
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text('purchase_invoice.step_header'.tr()),
            isActive: _step >= 0,
            content: _HeaderStep(
              supplierName: _supplierName,
              discount: _discount,
              paid: _paid,
              notes: _notes,
              onPickSupplier: _pickSupplier,
              onPickSaleDate: _pickSaleDate,
            ),
          ),
          Step(
            title: Text('purchase_invoice.step_items'.tr()),
            isActive: _step >= 1,
            content: _ItemsStep(),
          ),
          Step(
            title: Text('purchase_invoice.step_review'.tr()),
            isActive: _step >= 2,
            content: _ReviewStep(),
          ),
        ],
      ),
    );
  }
}

class _HeaderStep extends StatelessWidget {
  const _HeaderStep({
    required this.supplierName,
    required this.discount,
    required this.paid,
    required this.notes,
    required this.onPickSupplier,
    required this.onPickSaleDate,
  });

  final TextEditingController supplierName;
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
        AppTextField(
          controller: supplierName,
          label: 'purchase_invoice.supplier_name_fallback'.tr(),
          onChanged: provider.setSupplierName,
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
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('cash')),
            DropdownMenuItem(value: 'card', child: Text('card')),
            DropdownMenuItem(value: 'installment', child: Text('installment')),
            DropdownMenuItem(value: 'mixed', child: Text('mixed')),
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
                onChanged:
                    (v) => provider.setDiscount(
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
                onChanged:
                    (v) => provider.setPaidAmount(
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

class _ItemsStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < provider.items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
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
      ],
    );
  }
}

class _ReviewStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CreatePurchaseInvoiceProvider>();
    final tt = context.theme.textTheme;

    final feeTotal = provider.items.fold<double>(
      0,
      (sum, it) => sum + it.manufacturerFeeTotal,
    );
    final pieceCount = provider.items.fold<int>(
      0,
      (sum, it) => sum + it.pieces.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('purchase_invoice.review_intro'.tr(), style: tt.bodyMedium),
        SizedBox(height: 12.h),
        _SummaryRow(
          label: 'purchase_invoice.supplier'.tr(),
          value: provider.supplier?.name ?? provider.supplierName ?? '—',
        ),
        _SummaryRow(
          label: 'purchase_invoice.item_count'.tr(),
          value: '${provider.items.length}',
        ),
        _SummaryRow(
          label: 'purchase_invoice.piece_count'.tr(),
          value: '$pieceCount',
        ),
        _SummaryRow(
          label: 'purchase_invoice.manufacturer_fee_total'.tr(),
          value: feeTotal.toStringAsFixed(2),
        ),
        if (provider.submitBlockers.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Text(
            'purchase_invoice.review_warning'.tr(),
            style: tt.bodySmall?.copyWith(
              color: context.theme.colorScheme.error,
            ),
          ),
          SizedBox(height: 4.h),
          for (final b in provider.submitBlockers)
            Text(
              '• ${'purchase_invoice.blocker.${b.key}'.tr(args: ['${b.count}'])}',
              style: tt.bodySmall?.copyWith(
                color: context.theme.colorScheme.error,
              ),
            ),
        ],
        if (provider.errorMessage != null) ...[
          SizedBox(height: 12.h),
          Text(
            provider.errorMessage!,
            style: tt.bodySmall?.copyWith(
              color: context.theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(child: Text(label, style: tt.bodyMedium)),
          Text(value, style: tt.bodyMedium),
        ],
      ),
    );
  }
}
