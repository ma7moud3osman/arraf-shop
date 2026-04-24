import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_customer_picker_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Bottom sheet wrapping the [ShopCustomerPickerProvider]. Returns the
/// chosen [ShopCustomer] (or null on dismiss) via Navigator.
class SupplierPickerSheet extends StatefulWidget {
  const SupplierPickerSheet({super.key});

  @override
  State<SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<SupplierPickerSheet> {
  late final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopCustomerPickerProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'purchase_invoice.pick_supplier'.tr(),
              style: context.theme.textTheme.titleMedium,
            ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _searchCtrl,
              hint: 'purchase_invoice.search_supplier'.tr(),
              onChanged:
                  (v) => context.read<ShopCustomerPickerProvider>().search(v),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: Consumer<ShopCustomerPickerProvider>(
                builder: (context, provider, _) {
                  if (provider.status.isLoading) {
                    return const Center(child: AppLoading());
                  }
                  if (provider.status.isFailure) {
                    return Center(
                      child: Text(
                        provider.errorMessage ?? 'errors.generic'.tr(),
                      ),
                    );
                  }
                  if (provider.customers.isEmpty) {
                    return Center(
                      child: Text('purchase_invoice.no_suppliers'.tr()),
                    );
                  }
                  return ListView.separated(
                    itemCount: provider.customers.length,
                    separatorBuilder: (_, _) => Divider(height: 1.h),
                    itemBuilder: (context, i) {
                      final c = provider.customers[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: c.phone == null ? null : Text(c.phone!),
                        onTap: () => Navigator.of(context).pop<ShopCustomer>(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
