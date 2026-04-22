import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:arraf_shop/src/app.dart';
import 'package:arraf_shop/src/services/storage_service.dart';
import 'package:arraf_shop/src/shared/wrappers/state_wrapper.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    // SettingsProvider reads prefs synchronously on construction — the
    // storage service must be initialised before pumping the widget tree.
    await StorageService.instance.init();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: const StateWrapper(child: App()),
      ),
    );

    // Verify that our base app builds successfully.
    expect(find.byType(App), findsOneWidget);
  });
}
