import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_draft.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_customer.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/shop_item.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/repositories/purchase_invoice_repository.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/repositories/shop_customer_repository.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/repositories/shop_item_repository.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

class FakeShopCustomerRepository implements ShopCustomerRepository {
  List<ShopCustomer> seed = [ShopCustomer.fake()];
  Failure? failure;
  int listCalls = 0;

  @override
  FutureEither<List<ShopCustomer>> list({String? search, int perPage = 30}) {
    listCalls += 1;
    if (failure != null) return Future.value(Left(failure!));
    return Future.value(Right(seed));
  }
}

class FakeShopItemRepository implements ShopItemRepository {
  List<ShopItem> seed = [ShopItem.fake(), ShopItem.fake(id: 2)];
  Failure? failure;
  int listCalls = 0;

  @override
  FutureEither<List<ShopItem>> list({String? search, int perPage = 30}) {
    listCalls += 1;
    if (failure != null) return Future.value(Left(failure!));
    return Future.value(Right(seed));
  }
}

class FakePurchaseInvoiceRepository implements PurchaseInvoiceRepository {
  PurchaseInvoiceDraftHeader? lastHeader;
  List<DraftItem>? lastItems;
  int createCalls = 0;

  /// When non-null, [create] returns this failure instead of success.
  Failure? failure;

  /// Custom invoice to return; defaults to [PurchaseInvoice.fake].
  PurchaseInvoice? invoice;

  @override
  FutureEither<PurchaseInvoice> create({
    required PurchaseInvoiceDraftHeader header,
    required List<DraftItem> items,
  }) {
    createCalls += 1;
    lastHeader = header;
    lastItems = items;
    if (failure != null) return Future.value(Left(failure!));
    return Future.value(Right(invoice ?? PurchaseInvoice.fake()));
  }
}
