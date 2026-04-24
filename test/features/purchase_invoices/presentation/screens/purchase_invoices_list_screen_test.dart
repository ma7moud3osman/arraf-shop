import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_list_item.dart';
import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoices_list_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/purchase_invoices_list_screen.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:provider/provider.dart';

import '../../_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders invoice tiles from the provider', (tester) async {
    final repo = FakePurchaseInvoiceRepository();
    repo.listHandler = (page, perPage, search) async {
      return Right(
        Paginated<PurchaseInvoiceListItem>(
          items: [
            PurchaseInvoiceListItem.fake(
              id: 1,
              invoiceNumber: 'P-001',
              customerName: 'Ahmed Mostafa',
              total: 1500,
              itemsCount: 3,
            ),
            PurchaseInvoiceListItem.fake(
              id: 2,
              invoiceNumber: 'P-002',
              customerName: 'Sara',
              total: 750,
              itemsCount: 1,
            ),
          ],
          currentPage: page,
          perPage: perPage,
          total: 2,
          lastPage: page,
        ),
      );
    };

    final provider = PurchaseInvoicesListProvider(repository: repo);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => ChangeNotifierProvider<
            PurchaseInvoicesListProvider
          >.value(
            value: provider,
            child: const PurchaseInvoicesListScreen(),
          ),
        ),
      ),
    );

    // Initial frame: provider hasn't loaded yet (kicked off via
    // postFrameCallback). Pump to flush the callback + the load future.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('P-001'), findsOneWidget);
    expect(find.text('P-002'), findsOneWidget);
    expect(find.text('Ahmed Mostafa'), findsOneWidget);
    expect(repo.listCalls, 1);
  });
}
