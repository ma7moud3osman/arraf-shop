import 'package:arraf_shop/src/features/settings/domain/entities/shop_settings.dart';
import 'package:arraf_shop/src/features/settings/domain/repositories/shop_settings_repository.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:arraf_shop/src/utils/typedefs.dart';
import 'package:fpdart/fpdart.dart';

/// In-memory fake of [ShopSettingsRepository] for provider tests. Each
/// method delegates to its `*Handler` callback when set; otherwise it
/// returns a sensible default. Counters expose how often each method ran.
class FakeShopSettingsRepository implements ShopSettingsRepository {
  FakeShopSettingsRepository({this.initial = const ShopSettings()});

  ShopSettings initial;

  FutureEither<ShopSettings> Function()? fetchHandler;
  FutureEither<ShopSettings> Function(List<int> weeklyHolidays)? updateHandler;

  int fetchCalls = 0;
  int updateCalls = 0;
  List<int>? lastUpdate;

  @override
  FutureEither<ShopSettings> fetch() {
    fetchCalls += 1;
    final h = fetchHandler;
    if (h != null) return h();
    return Future.value(Right(initial));
  }

  @override
  FutureEither<ShopSettings> update(List<int> weeklyHolidays) {
    updateCalls += 1;
    lastUpdate = weeklyHolidays;
    final h = updateHandler;
    if (h != null) return h(weeklyHolidays);
    initial = ShopSettings(weeklyHolidays: weeklyHolidays);
    return Future.value(Right(initial));
  }
}

class FailingShopSettingsRepository implements ShopSettingsRepository {
  FailingShopSettingsRepository({this.failure = const ServerFailure('boom')});
  final Failure failure;

  @override
  FutureEither<ShopSettings> fetch() => Future.value(Left(failure));

  @override
  FutureEither<ShopSettings> update(List<int> weeklyHolidays) =>
      Future.value(Left(failure));
}
