import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_item_picker_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Bottom sheet wrapping the [ShopItemPickerProvider]. Returns the
/// chosen [ShopItem] via Navigator.
class ShopItemPickerSheet extends StatefulWidget {
  const ShopItemPickerSheet({super.key});

  @override
  State<ShopItemPickerSheet> createState() => _ShopItemPickerSheetState();
}

class _ShopItemPickerSheetState extends State<ShopItemPickerSheet> {
  late final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopItemPickerProvider>().load();
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
              'purchase_invoice.pick_item'.tr(),
              style: context.theme.textTheme.titleMedium,
            ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _searchCtrl,
              hint: 'purchase_invoice.search_item'.tr(),
              onChanged:
                  (v) => context.read<ShopItemPickerProvider>().search(v),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: Consumer<ShopItemPickerProvider>(
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
                  if (provider.items.isEmpty) {
                    return Center(
                      child: Text('purchase_invoice.no_items'.tr()),
                    );
                  }
                  return ListView.separated(
                    itemCount: provider.items.length,
                    separatorBuilder: (_, _) => Divider(height: 1.h),
                    itemBuilder: (context, i) {
                      final item = provider.items[i];
                      return ListTile(
                        title: Text(item.displayLabel),
                        subtitle: Text(
                          'purchase_invoice.stock_label'.tr(
                            args: ['${item.stockOnHand}'],
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop<ShopItem>(item),
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
