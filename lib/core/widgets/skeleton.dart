import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet placeholder with a sweeping highlight, used while a list loads.
///
/// The sweep loops, so only mount it for content that will be replaced by real
/// data or an error state.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
    this.base,
  });
  final double? width;
  final double height;
  final double radius;
  final Color? base;
  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    if (_reduce) {
      _controller
        ..stop()
        ..value = .35;
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
    final base =
        widget.base ??
        (context.palette.isDark
            ? const Color(0xFF1B1F27)
            : const Color(0xFFE3E7F0));
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _SkeletonPainter(
                progress: reduce ? .35 : _controller.value,
                base: base,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({required this.progress, required this.base});
  final double progress;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = base);
    final travel = progress * 2.4 - .7;
    final band = Rect.fromCenter(
      center: Offset(size.width * travel, size.height / 2),
      width: size.width * .8,
      height: size.height * 2.4,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: .55),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, .5, 1],
      ).createShader(band);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SkeletonPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.base != base;
}
