import 'package:arraf_shop/src/features/audits/presentation/widgets/barcode_scanner_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Stub the permission_handler platform channel so initState's request
  // resolves synchronously with a denied status. That drives the widget into
  // the permission-denied render path, which does not try to open the camera.
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          (call) async {
            if (call.method == 'checkPermissionStatus' ||
                call.method == 'requestPermissions') {
              // 2 == denied in permission_handler's PermissionStatus enum.
              return <int, int>{17: 2}; // 17 == Permission.camera
            }
            return null;
          },
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter.baseflow.com/permissions/methods'),
          null,
        );
  });

  group('BarcodeScannerView', () {
    testWidgets('fires onBarcode when a scan is simulated', (tester) async {
      final scanned = <String>[];
      final key = GlobalKey<BarcodeScannerViewState>();

      await tester.pumpWidget(
        MaterialApp(home: BarcodeScannerView(key: key, onBarcode: scanned.add)),
      );
      await tester.pump();

      key.currentState!.debugHandleScan('7-A1B2C3D4');

      expect(scanned, ['7-A1B2C3D4']);
    });

    testWidgets(
      'debounces the same barcode within the sameBarcodeWindow',
      (tester) async {
        final scanned = <String>[];
        final key = GlobalKey<BarcodeScannerViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: BarcodeScannerView(key: key, onBarcode: scanned.add),
          ),
        );
        await tester.pump();

        final state = key.currentState!;
        state.debugHandleScan('7-A1B2C3D4');
        state.debugHandleScan('7-A1B2C3D4');
        state.debugHandleScan('7-A1B2C3D4');

        expect(scanned, ['7-A1B2C3D4']);
      },
    );

    testWidgets(
      're-fires the same barcode once the sameBarcodeWindow elapses',
      (tester) async {
        final scanned = <String>[];
        final key = GlobalKey<BarcodeScannerViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: BarcodeScannerView(key: key, onBarcode: scanned.add),
          ),
        );
        await tester.pump();

        key.currentState!.debugHandleScan('7-A1B2C3D4');
        await tester.runAsync(
          () => Future<void>.delayed(
            BarcodeScannerView.sameBarcodeWindow +
                const Duration(milliseconds: 50),
          ),
        );
        key.currentState!.debugHandleScan('7-A1B2C3D4');

        expect(scanned, ['7-A1B2C3D4', '7-A1B2C3D4']);
      },
    );

    testWidgets(
      'forwards distinct barcodes once the cooldown elapses',
      (tester) async {
        final scanned = <String>[];
        final key = GlobalKey<BarcodeScannerViewState>();

        await tester.pumpWidget(
          MaterialApp(
            home: BarcodeScannerView(key: key, onBarcode: scanned.add),
          ),
        );
        await tester.pump();

        key.currentState!.debugHandleScan('AAA');
        await tester.runAsync(
          () => Future<void>.delayed(
            BarcodeScannerView.cooldownWindow + const Duration(milliseconds: 50),
          ),
        );
        key.currentState!.debugHandleScan('BBB');

        expect(scanned, ['AAA', 'BBB']);
      },
    );

    testWidgets('drops a second distinct barcode within the cooldown', (
      tester,
    ) async {
      final scanned = <String>[];
      final key = GlobalKey<BarcodeScannerViewState>();

      await tester.pumpWidget(
        MaterialApp(home: BarcodeScannerView(key: key, onBarcode: scanned.add)),
      );
      await tester.pump();

      key.currentState!
        ..debugHandleScan('AAA')
        ..debugHandleScan('BBB');

      expect(scanned, ['AAA']);
    });

    testWidgets('swallows scans while paused', (tester) async {
      final scanned = <String>[];
      final key = GlobalKey<BarcodeScannerViewState>();

      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerView(
            key: key,
            onBarcode: scanned.add,
            paused: true,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: BarcodeScannerView(
            key: key,
            onBarcode: scanned.add,
            paused: false,
          ),
        ),
      );
      await tester.pump();

      key.currentState!.debugHandleScan('CCC');
      expect(scanned, ['CCC']);
    });
  });
}
