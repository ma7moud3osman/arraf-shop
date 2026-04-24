import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoice_detail_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_fakes.dart';

void main() {
  late FakePurchaseInvoiceRepository repo;

  setUp(() {
    repo = FakePurchaseInvoiceRepository();
  });

  test('load() fetches the right id and populates invoice on success', () async {
    repo.fetchInvoice = PurchaseInvoice.fake(id: 42);
    final provider = PurchaseInvoiceDetailProvider(
      repository: repo,
      invoiceId: 42,
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(repo.fetchCalls, 1);
    expect(repo.lastFetchId, 42);
    expect(provider.loadStatus, AppStatus.success);
    expect(provider.invoice?.id, 42);
  });

  test('load() surfaces failure message on error', () async {
    repo.fetchFailure = const ServerFailure('boom');
    final provider = PurchaseInvoiceDetailProvider(
      repository: repo,
      invoiceId: 7,
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.loadStatus, AppStatus.failure);
    expect(provider.errorMessage, 'boom');
    expect(provider.invoice, isNull);
  });

  test('refresh() simply re-runs load()', () async {
    final provider = PurchaseInvoiceDetailProvider(
      repository: repo,
      invoiceId: 1,
    );
    addTearDown(provider.dispose);

    await provider.load();
    await provider.refresh();

    expect(repo.fetchCalls, 2);
  });
}
