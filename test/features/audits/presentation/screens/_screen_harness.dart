import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Stubs the permission_handler platform channel so the BarcodeScannerView's
/// `Permission.camera.request()` resolves as `denied` during tests — the
/// widget then renders the denial view instead of trying to open the camera.
void stubCameraPermission() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async {
          if (call.method == 'checkPermissionStatus' ||
              call.method == 'requestPermissions') {
            return <int, int>{17: 2}; // 17 == camera, 2 == denied
          }
          return null;
        },
      );
}

void unstubCameraPermission() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        null,
      );
}

/// Wraps a screen with the minimum scaffolding for widget tests:
/// * `MaterialApp` so `Theme.of`, navigation, and localizations work
/// * `ScreenUtilInit` so `.w`/`.h`/`.sp` resolve
/// * `MultiProvider` carrying the supplied fakes
Widget harness({
  required Widget child,
  AuditsListProvider? list,
  AuditSessionProvider? session,
  AuditRepository? repository,
}) {
  return MaterialApp(
    home: ScreenUtilInit(
      designSize: const Size(375, 812),
      child: MultiProvider(
        providers: [
          if (list != null)
            ChangeNotifierProvider<AuditsListProvider>.value(value: list),
          if (session != null)
            ChangeNotifierProvider<AuditSessionProvider>.value(value: session),
          if (repository != null)
            Provider<AuditRepository>.value(value: repository),
        ],
        child: Builder(builder: (_) => child),
      ),
    ),
  );
}

/// Configure the test view to a realistic phone size so layouts with
/// multiple flex children (scanner, progress, feed) get enough room.
/// Call from testWidgets and pair with [resetTestView] in tearDown.
void setPhoneTestView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
}

void resetTestView(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}
