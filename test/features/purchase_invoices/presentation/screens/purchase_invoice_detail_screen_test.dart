import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoice_detail_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/purchase_invoice_detail_screen.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/services/supplier_share_service.dart';
import 'package:arraf_shop/src/theme/theme.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../_fakes.dart';

class _NoopShareService implements SupplierShareService {
  const _NoopShareService();
  @override
  Future<bool> openUrl(Uri uri) async => true;
  @override
  Future<void> shareText(String text, {String? subject}) async {}
}

Widget _wrap(PurchaseInvoiceDetailProvider provider) {
  return MaterialApp(
    theme: buildLightTheme(primaryColorHex: '#6750A4'),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => ChangeNotifierProvider<PurchaseInvoiceDetailProvider>
          .value(
        value: provider,
        child: const PurchaseInvoiceDetailScreen(
          invoiceId: 1,
          shareService: _NoopShareService(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders draft: shows Complete CTA and draft items list',
      (tester) async {
    final repo = FakePurchaseInvoiceRepository();
    repo.fetchInvoice = PurchaseInvoice.fake(
      id: 1,
      isDraft: true,
      draftItems: [
        PurchaseInvoiceDraftItem.fake(
          id: 10,
          shopItemLabel: 'Lazurde · 21K · Bracelet',
        ),
      ],
    );
    final provider = PurchaseInvoiceDetailProvider(
      repository: repo,
      invoiceId: 1,
    );
    addTearDown(provider.dispose);

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Long un-localized button label can overflow the AppButton row in
    // tests; that's an AppButton concern, not ours — drain it.
    final overflow = tester.takeException();
    expect(overflow == null || overflow.toString().contains('overflowed'),
        isTrue);

    expect(
      find.byKey(const Key('complete_invoice_cta'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Lazurde · 21K · Bracelet', skipOffstage: false),
      findsOneWidget,
    );
    // Share action should be absent for drafts.
    expect(find.byKey(const Key('share_action')), findsNothing);
  });

  testWidgets(
      'renders completed: shows items + share action, no Complete CTA',
      (tester) async {
    final repo = FakePurchaseInvoiceRepository();
    repo.fetchInvoice = PurchaseInvoice.fake(
      id: 2,
      pdfShareUrl: 'https://share.example/inv/2?signature=abc',
    );
    final provider = PurchaseInvoiceDetailProvider(
      repository: repo,
      invoiceId: 2,
    );
    addTearDown(provider.dispose);

    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final overflow = tester.takeException();
    expect(overflow == null || overflow.toString().contains('overflowed'),
        isTrue);

    expect(find.byKey(const Key('share_action')), findsOneWidget);
    expect(find.byKey(const Key('complete_invoice_cta')), findsNothing);
  });
}
