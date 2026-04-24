import '../../../../utils/typedefs.dart';
import '../entities/shop_customer.dart';

/// Read-only listing for the supplier picker on Step 1 of the wizard.
/// Backed by `GET /api/shops/my/customers`.
abstract class ShopCustomerRepository {
  FutureEither<List<ShopCustomer>> list({String? search, int perPage = 30});
}
