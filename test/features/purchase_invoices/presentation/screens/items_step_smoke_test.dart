import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_item_picker_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/item_row_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ItemRowCard renders catalog placeholder + photo cell', (
    tester,
  ) async {
    final repo = FakePurchaseInvoiceRepository();
    final create = CreatePurchaseInvoiceProvider(repository: repo);
    final picker = ShopItemPickerProvider(repository: FakeShopItemRepository());
    addTearDown(create.dispose);
    addTearDown(picker.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder:
              (_, _) => MultiProvider(
                providers: [
                  ChangeNotifierProvider<CreatePurchaseInvoiceProvider>.value(
                    value: create,
                  ),
                  ChangeNotifierProvider<ShopItemPickerProvider>.value(
                    value: picker,
                  ),
                ],
                child: Builder(
                  builder:
                      (ctx) => Scaffold(
                        body: SingleChildScrollView(
                          child: ItemRowCard(
                            index: 0,
                            draft:
                                ctx
                                    .watch<CreatePurchaseInvoiceProvider>()
                                    .items[0],
                            canRemove: false,
                          ),
                        ),
                      ),
                ),
              ),
        ),
      ),
    );
    await tester.pump();

    // Initially the picker placeholder shows the localized "tap to pick" key.
    expect(find.text('purchase_invoice.tap_to_pick'), findsWidgets);

    // After picking a shop item the display label appears.
    create.setItemShopItem(0, ShopItem.fake(displayLabel: 'Bracelet · 21K'));
    await tester.pump();
    expect(find.text('Bracelet · 21K'), findsOneWidget);
  });
}
