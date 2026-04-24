import '../../../../utils/typedefs.dart';
import '../entities/shop_item.dart';

/// Read-only catalog listing for the item picker on Step 2 of the wizard.
/// Backed by `GET /api/shops/my/shop-items` (added alongside this feature).
abstract class ShopItemRepository {
  FutureEither<List<ShopItem>> list({String? search, int perPage = 30});
}
