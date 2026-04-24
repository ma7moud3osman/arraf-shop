import 'package:arraf_shop/src/features/employees/domain/entities/paginated.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_list_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoices_list_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('PurchaseInvoicesListProvider', () {
    late FakePurchaseInvoiceRepository repo;
    late PurchaseInvoicesListProvider provider;

    setUp(() {
      repo = FakePurchaseInvoiceRepository();
      provider = PurchaseInvoicesListProvider(
        repository: repo,
        searchDebounce: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => provider.dispose());

    test('load() flips status and stores the page', () async {
      expect(provider.status, AppStatus.initial);

      await provider.load();

      expect(provider.status, AppStatus.success);
      expect(provider.invoices, hasLength(2));
      expect(repo.listCalls, 1);
      expect(repo.lastListPage, 1);
    });

    test('load() failure exposes errorMessage', () async {
      repo.listFailure = const ServerFailure('boom');

      await provider.load();

      expect(provider.status, AppStatus.failure);
      expect(provider.errorMessage, 'boom');
      expect(provider.invoices, isEmpty);
    });

    test('setSearch debounces and triggers load with the search arg', () async {
      provider.setSearch('A');
      provider.setSearch('Ab');
      provider.setSearch('Abc');

      // Before debounce expires no call should have run.
      expect(repo.listCalls, 0);

      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(repo.listCalls, 1);
      expect(repo.lastListSearch, 'Abc');
    });

    test('setSearch with the same query is a no-op', () async {
      provider.setSearch('foo');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final firstCalls = repo.listCalls;

      provider.setSearch('foo');
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(repo.listCalls, firstCalls);
    });

    test('loadMore appends the next page and flips hasMore', () async {
      repo.listHandler = (page, perPage, search) async {
        return Right(
          Paginated<PurchaseInvoiceListItem>(
            items: [
              PurchaseInvoiceListItem.fake(
                id: page * 10,
                invoiceNumber: 'P-$page-A',
              ),
              PurchaseInvoiceListItem.fake(
                id: page * 10 + 1,
                invoiceNumber: 'P-$page-B',
              ),
            ],
            currentPage: page,
            perPage: perPage,
            total: 4,
            lastPage: 2,
          ),
        );
      };

      await provider.load();
      expect(provider.invoices, hasLength(2));
      expect(provider.hasMore, isTrue);

      await provider.loadMore();
      expect(provider.invoices, hasLength(4));
      expect(provider.hasMore, isFalse);
    });

    test('loadMore is a no-op when hasMore is false', () async {
      // Default fake returns lastPage == currentPage, so hasMore is false.
      await provider.load();
      final before = repo.listCalls;

      await provider.loadMore();

      expect(repo.listCalls, before);
    });

    test('refresh() re-fetches page 1', () async {
      await provider.load();
      final before = repo.listCalls;

      await provider.refresh();

      expect(repo.listCalls, before + 1);
      expect(repo.lastListPage, 1);
    });
  });
}
