import '../../../../utils/typedefs.dart';
import '../entities/gold_price_snapshot.dart';

/// Read + admin-update API for the per-shop gold price feature.
///
/// All calls are scoped to the authenticated user's shop on the backend
/// (`/api/gold-price`). No country parameter — the price is per-shop.
abstract class GoldPriceRepository {
  /// Fetch the current snapshot for the caller's shop.
  FutureEither<GoldPriceSnapshot> today();

  /// Patch the 21K buy + sale anchor for the caller's shop. Other karats
  /// (18 / 22 / 24) are derived proportionally on the server.
  ///
  /// `updates` must contain `karat_21_buy` and `karat_21_sale`.
  /// Accessible to shop owners and admins (anyone with a shop on their
  /// authenticated user).
  FutureEither<GoldPriceSnapshot> update({
    required Map<String, double> updates,
  });
}
