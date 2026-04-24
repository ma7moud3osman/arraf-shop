import 'package:arraf_shop/src/features/settings/domain/entities/shop_settings.dart';
import 'package:arraf_shop/src/features/settings/presentation/providers/working_week_provider.dart';
import 'package:arraf_shop/src/shared/enums/app_status.dart';
import 'package:arraf_shop/src/utils/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import '../../_fakes.dart';

void main() {
  group('WorkingWeekProvider', () {
    late FakeShopSettingsRepository repo;
    late WorkingWeekProvider provider;

    setUp(() {
      repo = FakeShopSettingsRepository(
        initial: const ShopSettings(weeklyHolidays: [5]),
      );
      provider = WorkingWeekProvider(repository: repo);
    });

    tearDown(() => provider.dispose());

    test('load() populates settings and seeds the draft', () async {
      await provider.load();

      expect(provider.loadStatus, AppStatus.success);
      expect(provider.settings?.weeklyHolidays, [5]);
      expect(provider.draftWeeklyHolidays, {5});
      expect(provider.isDirty, isFalse);
    });

    test('toggle() flips a day in the draft and marks the form dirty', () async {
      await provider.load();

      provider.toggle(7);

      expect(provider.draftWeeklyHolidays, {5, 7});
      expect(provider.isDirty, isTrue);

      provider.toggle(7);

      expect(provider.draftWeeklyHolidays, {5});
      expect(provider.isDirty, isFalse);
    });

    test('save() success: persists and clears dirty', () async {
      await provider.load();
      provider.toggle(7);

      final error = await provider.save();

      expect(error, isNull);
      expect(provider.saveStatus, AppStatus.success);
      expect(repo.lastUpdate, [5, 7]);
      expect(provider.settings?.weeklyHolidays, [5, 7]);
      expect(provider.isDirty, isFalse);
    });

    test('save() failure: surfaces error message and keeps draft dirty',
        () async {
      await provider.load();
      provider.toggle(1);

      repo.updateHandler = (_) async => const Left(ServerFailure('nope'));

      final error = await provider.save();

      expect(error, 'nope');
      expect(provider.saveStatus, AppStatus.failure);
      expect(provider.errorMessage, 'nope');
      expect(provider.isDirty, isTrue);
    });

    test('load() failure: surfaces error', () async {
      repo.fetchHandler = () async => const Left(ServerFailure('down'));

      await provider.load();

      expect(provider.loadStatus, AppStatus.failure);
      expect(provider.errorMessage, 'down');
      expect(provider.settings, isNull);
    });

    test('revert() restores the draft to the saved settings', () async {
      await provider.load();
      provider.toggle(2);
      provider.toggle(3);
      expect(provider.isDirty, isTrue);

      provider.revert();

      expect(provider.draftWeeklyHolidays, {5});
      expect(provider.isDirty, isFalse);
    });
  });
}
