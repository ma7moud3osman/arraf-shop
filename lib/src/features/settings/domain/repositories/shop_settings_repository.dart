import '../../../../utils/typedefs.dart';
import '../entities/shop_settings.dart';

/// Owner-only shop preferences API.
abstract class ShopSettingsRepository {
  /// `GET /api/shops/my/settings` — fetch the current settings.
  FutureEither<ShopSettings> fetch();

  /// `PUT /api/shops/my/settings` — update the weekly holiday list.
  /// Wire format: ISO weekday integers (1 = Monday … 7 = Sunday).
  FutureEither<ShopSettings> update(List<int> weeklyHolidays);
}
