import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/services/supplier_share_service.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/share_invoice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingShareService implements SupplierShareService {
  final List<Uri> opened = [];
  final List<({String text, String? subject})> shared = [];
  bool openResult = true;

  @override
  Future<bool> openUrl(Uri uri) async {
    opened.add(uri);
    return openResult;
  }

  @override
  Future<void> shareText(String text, {String? subject}) async {
    shared.add((text: text, subject: subject));
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final invoice = PurchaseInvoice.fake(id: 42);
  final supplier = ShopCustomer.fake(phone: '01012345678');
  final viewUrl = Uri.parse('https://shop.example/shop-owner/purchase-invoices/42');

  group('ShareInvoiceSheet', () {
    testWidgets('renders the three share options', (tester) async {
      final svc = _RecordingShareService();
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: viewUrl,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('share_option_whatsapp')), findsOneWidget);
      expect(find.byKey(const Key('share_option_native')), findsOneWidget);
      expect(find.byKey(const Key('share_option_pdf')), findsOneWidget);
    });

    testWidgets('tapping WhatsApp opens wa.me with normalized phone + message', (
      tester,
    ) async {
      final svc = _RecordingShareService();
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: viewUrl,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('share_option_whatsapp')));
      await tester.pump();

      expect(svc.opened, hasLength(1));
      final uri = svc.opened.single;
      // Local Egyptian number `01012345678` → wa.me strips leading 0 and
      // prepends the default `20` country code.
      expect(uri.host, 'wa.me');
      expect(uri.pathSegments.first, '201012345678');
      // EasyLocalization isn't initialised in tests so .tr() returns the
      // raw key — we just confirm the text param made it through.
      expect(uri.queryParameters['text'], isNotEmpty);
    });

    testWidgets('share URL is forwarded into "view PDF" launch', (
      tester,
    ) async {
      final svc = _RecordingShareService();
      final preSigned = Uri.parse(
        'https://share.example/inv/42?signature=abc',
      );
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: preSigned,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('share_option_pdf')));
      await tester.pump();

      expect(svc.opened.single, preSigned);
    });

    testWidgets('tapping native share calls shareText', (tester) async {
      final svc = _RecordingShareService();
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: viewUrl,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('share_option_native')));
      await tester.pump();

      expect(svc.shared, hasLength(1));
      expect(svc.shared.single.text, isNotEmpty);
    });

    testWidgets('tapping View opens the view URL', (tester) async {
      final svc = _RecordingShareService();
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: supplier,
            viewUrl: viewUrl,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('share_option_pdf')));
      await tester.pump();

      expect(svc.opened, hasLength(1));
      expect(svc.opened.single, viewUrl);
    });

    testWidgets('WhatsApp option is disabled when supplier has no phone', (
      tester,
    ) async {
      final svc = _RecordingShareService();
      await tester.pumpWidget(
        _wrap(
          ShareInvoiceSheet(
            invoice: invoice,
            supplier: const ShopCustomer(id: 1, name: 'Walk-in', phone: null),
            viewUrl: viewUrl,
            shareService: svc,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('share_option_whatsapp')));
      await tester.pump();

      expect(svc.opened, isEmpty);
    });
  });

  group('normalizeWhatsAppPhone', () {
    test('prepends default country code for local Egyptian number', () {
      expect(normalizeWhatsAppPhone('01012345678'), '201012345678');
    });

    test('strips a leading + while keeping country code', () {
      expect(normalizeWhatsAppPhone('+201012345678'), '201012345678');
    });

    test('handles 00-prefixed international format', () {
      expect(normalizeWhatsAppPhone('00201012345678'), '201012345678');
    });

    test('returns null for empty / digit-less input', () {
      expect(normalizeWhatsAppPhone(null), isNull);
      expect(normalizeWhatsAppPhone(''), isNull);
      expect(normalizeWhatsAppPhone('   '), isNull);
      expect(normalizeWhatsAppPhone('---'), isNull);
    });

    test('strips spaces and punctuation', () {
      expect(normalizeWhatsAppPhone('+20 (10) 1234-5678'), '201012345678');
    });
  });

  group('buildWhatsAppUri', () {
    test('builds canonical wa.me url with url-encoded text', () {
      final uri = buildWhatsAppUri(
        phoneDigits: '201012345678',
        message: 'Hello supplier https://x.test/inv/1',
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'wa.me');
      expect(uri.pathSegments, ['201012345678']);
      expect(
        uri.queryParameters['text'],
        'Hello supplier https://x.test/inv/1',
      );
    });
  });
}
