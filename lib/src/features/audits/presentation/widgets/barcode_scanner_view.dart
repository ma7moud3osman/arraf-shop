import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// A reusable camera viewfinder for audit barcode scanning.
///
/// Renders a live camera preview with a centred scan line and corner
/// brackets, exposes torch + camera-switch controls, and debounces
/// duplicate scans of the same barcode within an 800 ms window.
///
/// The app-level dedupe still catches network dupes; this only prevents
/// rapid-fire double-fires from the hardware.
class BarcodeScannerView extends StatefulWidget {
  const BarcodeScannerView({
    super.key,
    required this.onBarcode,
    this.paused = false,
  });

  final ValueChanged<String> onBarcode;

  /// When true, the camera is stopped and no callbacks fire.
  final bool paused;

  @visibleForTesting
  static const Duration debounceWindow = Duration(milliseconds: 800);

  @override
  State<BarcodeScannerView> createState() => BarcodeScannerViewState();
}

class BarcodeScannerViewState extends State<BarcodeScannerView> {
  late final MobileScannerController _controller;
  _PermissionState _permission = _PermissionState.checking;

  String? _lastBarcode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
    unawaited(_requestPermission());
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused == oldWidget.paused) return;
    if (widget.paused) {
      unawaited(_controller.stop());
    } else if (_permission == _PermissionState.granted) {
      unawaited(_controller.start());
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permission =
            status.isGranted
                ? _PermissionState.granted
                : status.isPermanentlyDenied
                ? _PermissionState.permanentlyDenied
                : _PermissionState.denied;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _permission = _PermissionState.denied);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (widget.paused) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _handleDetection(raw);
      return;
    }
  }

  /// Applies the debounce rule and forwards the scan to the host widget.
  ///
  /// Exposed for widget tests that simulate a scan without a real camera.
  @visibleForTesting
  void debugHandleScan(String barcode) => _handleDetection(barcode);

  void _handleDetection(String barcode) {
    final now = DateTime.now();
    final lastAt = _lastScanAt;
    if (_lastBarcode == barcode &&
        lastAt != null &&
        now.difference(lastAt) < BarcodeScannerView.debounceWindow) {
      return;
    }
    _lastBarcode = barcode;
    _lastScanAt = now;
    widget.onBarcode(barcode);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_permission) {
      _PermissionState.checking => const _Starting(),
      _PermissionState.denied => _PermissionDenied(
        permanent: false,
        onRetry: _requestPermission,
      ),
      _PermissionState.permanentlyDenied => _PermissionDenied(
        permanent: true,
        onRetry: () => openAppSettings(),
      ),
      _PermissionState.granted => _CameraSurface(
        controller: _controller,
        onDetect: _onDetect,
      ),
    };
  }
}

enum _PermissionState { checking, granted, denied, permanentlyDenied }

class _Starting extends StatelessWidget {
  const _Starting();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _PermissionDenied extends StatelessWidget {
  const _PermissionDenied({required this.permanent, required this.onRetry});

  final bool permanent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'audits.scanner.permission_denied_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'audits.scanner.permission_denied_body'.tr(),
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: Text(
                  permanent
                      ? 'audits.scanner.open_settings'.tr()
                      : 'audits.scanner.grant_permission'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraSurface extends StatelessWidget {
  const _CameraSurface({required this.controller, required this.onDetect});

  final MobileScannerController controller;
  final ValueChanged<BarcodeCapture> onDetect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: controller,
          onDetect: onDetect,
          errorBuilder: (context, error) => _CameraError(error: error),
        ),
        const IgnorePointer(child: _ScannerOverlay()),
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SafeArea(child: _ScannerControls(controller: controller)),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          Text(
            'audits.scanner.camera_error'.tr(),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ScannerControls extends StatelessWidget {
  const _ScannerControls({required this.controller});
  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: controller,
          builder: (context, state, _) {
            final on = state.torchState == TorchState.on;
            return _PillButton(
              icon: on ? Icons.flash_on : Icons.flash_off,
              tooltip:
                  (on ? 'audits.scanner.torch_off' : 'audits.scanner.torch_on')
                      .tr(),
              onPressed: () => controller.toggleTorch(),
            );
          },
        ),
        _PillButton(
          icon: Icons.cameraswitch_rounded,
          tooltip: 'audits.scanner.switch_camera'.tr(),
          onPressed: () => controller.switchCamera(),
        ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
      ),
    );
  }
}

class _ScannerOverlay extends StatefulWidget {
  const _ScannerOverlay();

  @override
  State<_ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<_ScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanLineController,
      builder:
          (context, _) => CustomPaint(
            painter: _ScannerFramePainter(progress: _scanLineController.value),
            size: Size.infinite,
          ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  _ScannerFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final boxSize = shortest * 0.7;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: boxSize,
      height: boxSize,
    );

    // Dim the area outside the box.
    final overlay =
        Path()
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
          ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Corner brackets.
    final bracketPaint =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    const cornerLength = 22.0;

    void drawCorner(Offset origin, Offset h, Offset v) {
      canvas.drawLine(origin, origin + h, bracketPaint);
      canvas.drawLine(origin, origin + v, bracketPaint);
    }

    drawCorner(
      rect.topLeft,
      const Offset(cornerLength, 0),
      const Offset(0, cornerLength),
    );
    drawCorner(
      rect.topRight,
      const Offset(-cornerLength, 0),
      const Offset(0, cornerLength),
    );
    drawCorner(
      rect.bottomLeft,
      const Offset(cornerLength, 0),
      const Offset(0, -cornerLength),
    );
    drawCorner(
      rect.bottomRight,
      const Offset(-cornerLength, 0),
      const Offset(0, -cornerLength),
    );

    // Animated scan line.
    final lineY = rect.top + rect.height * progress;
    final linePaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [Colors.transparent, Colors.white, Colors.transparent],
          ).createShader(Rect.fromLTWH(rect.left, lineY - 1, rect.width, 2));
    canvas.drawRect(
      Rect.fromLTWH(rect.left + 4, lineY - 1, rect.width - 8, 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
