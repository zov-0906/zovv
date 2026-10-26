import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The app's own loading mark: a glass arc with a travelling highlight and two
/// slower satellites. Hand-drawn on purpose — no Material spinner anywhere.
class ZovvLoader extends StatefulWidget {
  const ZovvLoader({
    super.key,
    this.size = 30,
    this.color,
    this.period = const Duration(milliseconds: 1500),
  });
  final double size;

  /// Defaults to [AppColors.accent]-like violet; pass white on dark surfaces.
  final Color? color;
  final Duration period;
  @override
  State<ZovvLoader> createState() => _ZovvLoaderState();
}

class _ZovvLoaderState extends State<ZovvLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      _controller
        ..stop()
        ..value = .3;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduce;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _ZovvLoaderPainter(
              progress: reduce ? .3 : _controller.value,
              color: widget.color ?? context.palette.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ZovvLoaderPainter extends CustomPainter {
  _ZovvLoaderPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final stroke = math.max(1.4, size.shortestSide * .075);
    final breathe = 1 + math.sin(progress * math.pi * 2) * .03;
    final radius = (size.shortestSide - stroke * 2) / 2 * breathe;
    final ring = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius * 1.05,
      Paint()
        ..color = color.withValues(alpha: .07)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(2, size.shortestSide * .16),
        ),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * .8
        ..color = color.withValues(alpha: .14),
    );

    final start = progress * math.pi * 2 - math.pi / 2;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: .35),
          color,
        ],
        stops: const [0, .55, 1],
        transform: GradientRotation(start),
      ).createShader(ring);
    canvas.drawArc(ring, start, math.pi * .78, false, arc);

    final headAngle = start + math.pi * .78;
    final head =
        center +
        Offset(math.cos(headAngle) * radius, math.sin(headAngle) * radius);
    canvas.drawCircle(
      head,
      stroke * 1.5,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 2.2),
    );
    canvas.drawCircle(
      head,
      stroke * .58,
      Paint()..color = Colors.white.withValues(alpha: .92),
    );

    for (final (speed, phase, scale, alpha) in const [
      (1.6, 0.0, .52, .5),
      (-.9, 2.1, .34, .28),
    ]) {
      final angle = progress * math.pi * 2 * speed + phase;
      final orbit = radius * .62;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * orbit, math.sin(angle) * orbit),
        math.max(1, stroke * scale),
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ZovvLoaderPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
