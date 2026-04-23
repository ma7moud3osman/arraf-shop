import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  /// Total animation runtime. Anything longer feels like a stall.
  static const Duration duration = Duration(milliseconds: 2400);

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master;
  late final AnimationController _aurora;
  bool _handedOff = false;

  late final AnimationController _orbit;

  // Carved out of [_master] so each element fires on its own window
  // without having to juggle multiple controllers.
  late final Animation<double> _ringsIn;
  late final Animation<double> _iconIn;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
      vsync: this,
      duration: AnimatedSplashScreen.duration,
    );

    _aurora = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    // Orbit runs on its own slow looping controller — decoupled from
    // [_master] so its speed isn't tied to the splash duration. One full
    // revolution every 5 s reads as a calm, steady sweep.
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _ringsIn = CurvedAnimation(
      parent: _master,
      curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
    );
    _iconIn = CurvedAnimation(
      parent: _master,
      curve: const Interval(0.20, 0.70, curve: Curves.easeOutBack),
    );

    _master
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_handedOff) {
          _handedOff = true;
          widget.onComplete();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _master.dispose();
    _aurora.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gold = cs.primary;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _aurora, _orbit]),
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _GradientBackdrop(gold: gold),
              Positioned.fill(
                child: CustomPaint(
                  painter: _AuroraPainter(gold: gold, progress: _aurora.value),
                ),
              ),
              Center(
                child: SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _Rings(gold: gold, progress: _ringsIn.value),
                      _ScanOrbit(gold: gold, progress: _orbit.value),
                      _CenterMark(progress: _iconIn.value),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Background
// -----------------------------------------------------------------------------

class _GradientBackdrop extends StatelessWidget {
  const _GradientBackdrop({required this.gold});
  final Color gold;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [
            Color.lerp(gold, Colors.black, 0.55)!,
            const Color(0xFF0B0B0E),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.gold, required this.progress});

  final Color gold;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = progress * 2 * math.pi;

    void blob(double angle, double radius, double intensity) {
      final dx = math.cos(angle) * radius;
      final dy = math.sin(angle) * radius;
      final rect = Rect.fromCircle(
        center: center + Offset(dx, dy),
        radius: size.shortestSide * 0.55,
      );
      final paint =
          Paint()
            ..shader = RadialGradient(
              colors: [gold.withValues(alpha: intensity), Colors.transparent],
            ).createShader(rect)
            ..blendMode = BlendMode.plus;
      canvas.drawRect(rect, paint);
    }

    blob(t, size.shortestSide * 0.18, 0.14);
    blob(t + math.pi * 0.7, size.shortestSide * 0.22, 0.10);
    blob(t + math.pi, size.shortestSide * 0.12, 0.12);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.progress != progress || old.gold != gold;
}

// -----------------------------------------------------------------------------
// Rings
// -----------------------------------------------------------------------------

class _Rings extends StatelessWidget {
  const _Rings({required this.gold, required this.progress});

  final Color gold;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(320, 320),
      painter: _RingsPainter(gold: gold, progress: progress),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.gold, required this.progress});

  final Color gold;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Radii are fractions of the 320 px container's half-width (160 px).
    // The logo is 180 px wide, so it extends ~90 px from centre. The
    // innermost ring needs to sit outside that — 0.64 → ~102 px clears
    // the logo with a small breathing gap.
    const rings = [0.95, 0.80, 0.64];
    for (var i = 0; i < rings.length; i++) {
      // Stagger: each ring starts a bit later than the previous one.
      final start = i * 0.15;
      final local = ((progress - start) / (1 - start)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final scale = Curves.easeOutCubic.transform(local);
      final radius = (size.width / 2) * rings[i] * scale;
      final strokePaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = gold.withValues(alpha: 0.35 + i * 0.15 * local);

      canvas.drawCircle(center, radius, strokePaint);

      // Soft inner glow on the innermost ring.
      if (i == rings.length - 1) {
        final glow =
            Paint()
              ..shader = RadialGradient(
                colors: [
                  gold.withValues(alpha: 0.35 * local),
                  Colors.transparent,
                ],
              ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) =>
      old.progress != progress || old.gold != gold;
}

// -----------------------------------------------------------------------------
// Orbiting scan arc — evokes the audit scanner from the rest of the app.
// -----------------------------------------------------------------------------

class _ScanOrbit extends StatelessWidget {
  const _ScanOrbit({required this.gold, required this.progress});

  final Color gold;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(320, 320),
      painter: _ScanOrbitPainter(gold: gold, progress: progress),
    );
  }
}

class _ScanOrbitPainter extends CustomPainter {
  _ScanOrbitPainter({required this.gold, required this.progress});

  final Color gold;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // Match the outermost ornamental ring's radius so the scanner dot
    // traces that ring exactly instead of floating on its own orbit.
    final radius = size.width / 2 * 0.95;

    // Two full rotations across the splash window.
    // Progress is 0→1 over one full loop of the orbit controller (5 s).
    // Map it to one full revolution.
    final sweepAngle = progress * math.pi * 2;

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: sweepAngle - math.pi / 6,
            endAngle: sweepAngle,
            colors: [Colors.transparent, gold, gold.withValues(alpha: 0)],
          ).createShader(arcRect);

    canvas.drawArc(
      arcRect,
      sweepAngle - math.pi / 6,
      math.pi / 6,
      false,
      paint,
    );

    // Leading dot at the head of the arc.
    final headDx = center.dx + math.cos(sweepAngle) * radius;
    final headDy = center.dy + math.sin(sweepAngle) * radius;
    final dotPaint = Paint()..color = gold;
    canvas.drawCircle(Offset(headDx, headDy), 5, dotPaint);
    canvas.drawCircle(
      Offset(headDx, headDy),
      11,
      Paint()
        ..color = gold.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOrbitPainter old) =>
      old.progress != progress || old.gold != gold;
}

// -----------------------------------------------------------------------------
// Centre: the white brand logo fades in and settles.
// -----------------------------------------------------------------------------

class _CenterMark extends StatelessWidget {
  const _CenterMark({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    // easeOutBack can overshoot past 1.0; clamp opacity separately so the
    // icon doesn't flicker when the curve settles back to its target.
    final opacity = progress.clamp(0.0, 1.0);
    // Scale lifts slightly above 1.0 mid-animation for a subtle "stamp"
    // feel before settling.
    final scale = 0.8 + 0.2 * progress;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Image.asset(
          'assets/icons/arraf.png',
          width: 180,
          height: 180,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
