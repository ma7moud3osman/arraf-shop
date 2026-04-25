import 'package:arraf_shop/src/features/settings/presentation/providers/settings_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    Widget current = _buildMaterialApp(context);

    current = ScreenUtilWrapper(child: current);

    return current;
  }

  Widget _buildMaterialApp(BuildContext context) {
    final themeMode = context.select((SettingsProvider s) => s.themeMode);

    // Keep the Dio `Accept-Language` header in sync with the active locale
    // so every API call asks Laravel for translated error messages.
    AppConfig.currentLocale = context.locale.languageCode;

    return MaterialApp.router(
      // Keying the router on the active language code forces the entire
      // app tree (including any cached AppBar titles) to rebuild when the
      // user switches languages — otherwise the new locale only takes
      // effect after a full app reload.
      key: ValueKey(context.locale.languageCode),
      title: 'Arraf Shop',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(primaryColorHex: '#f59e0b'),
      darkTheme: buildDarkTheme(primaryColorHex: '#f59e0b'),
      themeMode: themeMode,
      routerConfig: appRouter,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) {
        Widget current = child!;
        current = SkeletonWrapper(child: current);
        current = SessionListenerWrapper(child: current);
        return current;
      },
    );
  }
}
