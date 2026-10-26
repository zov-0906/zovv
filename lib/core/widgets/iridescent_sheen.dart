import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

/// A soft band of pastel light crossing a glass surface — the signature seen in
/// the reference clip, where a highlight drifts over otherwise quiet white pills.
///
/// Three modes:
/// * default — one short pass on mount and whenever [token] changes;
/// * [loop] — repeats continuously, only for temporary loading surfaces;
/// * [breathe] — one pass every [interval], used sparingly for ambient life.
///
/// Ambient modes stop while the app is paused and never start in widget tests.
class IridescentSheen extends StatefulWidget {
  const IridescentSheen({
    super.key,
    this.loop = false,
    this.breathe = false,
    this.token = 0,
    this.period = const Duration(milliseconds: 1150),
    this.interval = const Duration(milliseconds: 6400),
    this.opacity = .55,
    this.tilt = -.22,
  });

  /// Repeats the pass forever; use only on surfaces that disappear again.
  final bool loop;

  /// Plays a pass every [interval] while the app is in the foreground.
  final bool breathe;

  /// Change this value to replay the pass, e.g. when a selection moves.
  final int token;
  final Duration period;
  final Duration interval;
  final double opacity;

  /// Radians. Small negative values read as light coming from the upper left.
  final double tilt;

  @override
  State<IridescentSheen> createState() => _IridescentSheenState();
}

class _IridescentSheenState extends State<IridescentSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _reduce = false;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onPause: () {
        _paused = true;
        _stopTicker();
      },
      onResume: () {
        _paused = false;
        _start();
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && !_reduce) {
      _reduce = true;
      _controller
        ..stop()
        ..value = .42;
      _stopTicker();
      return;
    }
    _reduce = reduce;
    _start();
  }

  @override
  void didUpdateWidget(covariant IridescentSheen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _playOnce();
    if (oldWidget.breathe != widget.breathe ||
        oldWidget.interval != widget.interval) {
      _stopTicker();
      _start();
    }
  }

  void _start() {
    if (_reduce || _paused || !mounted) return;
    if (widget.loop) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    if (widget.breathe) {
      if (!ambientMotionEnabled) return;
      _playOnce();
      _timer ??= Timer.periodic(widget.interval, (_) => _playOnce());
      return;
    }
    _playOnce();
  }

  void _playOnce() {
    if (_reduce || !mounted) return;
    if (widget.loop) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    _controller.forward(from: 0);
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
    _controller.stop();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _stopTicker();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SheenPainter(
            progress: _controller.value,
            opacity: widget.opacity,
            tilt: widget.tilt,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _SheenPainter extends CustomPainter {
  _SheenPainter({
    required this.progress,
    required this.opacity,
    required this.tilt,
  });
  final double progress;
  final double opacity;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0 || progress >= 1) return;
    final intensity = (math.sin(progress * math.pi)).clamp(0.0, 1.0) * opacity;
    if (intensity <= 0) return;
    // Ease the band so it lingers in the middle instead of racing past.
    final travel = Curves.easeInOutCubic.transform(progress) * 2.4 - .7;
    final band = Rect.fromCenter(
      center: Offset(size.width * travel, size.height / 2),
      width: size.width * 1.15,
      height: math.max(size.height, 1) * 2.6,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          const Color(0xFFFFD9E8).withValues(alpha: intensity * .8),
          const Color(0xFFD9D6FF).withValues(alpha: intensity),
          const Color(0xFFD6F1FF).withValues(alpha: intensity * .8),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, .3, .5, .7, 1],
      ).createShader(band);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(band.center.dx, band.center.dy)
      ..rotate(tilt)
      ..translate(-band.center.dx, -band.center.dy)
      ..drawRect(band, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_SheenPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.opacity != opacity ||
      oldDelegate.tilt != tilt;
}
