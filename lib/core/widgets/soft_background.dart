import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Static diffuse lighting: color stays behind the content, never behind text alone.
class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glows = palette.isDark
        ? const [
            (Alignment.topRight, Color(0xFF1B2A52), 560.0),
            (Alignment.centerLeft, Color(0xFF2A1E45), 500.0),
            (Alignment.bottomRight, Color(0xFF33261A), 520.0),
          ]
        : const [
            (Alignment.topRight, Color(0xFFC5D7FC), 540.0),
            (Alignment.centerLeft, Color(0xFFE6DDF9), 480.0),
            (Alignment.bottomRight, Color(0xFFF4E7DC), 500.0),
          ];
    return ColoredBox(
      color: palette.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final (alignment, color, size) in glows)
            Positioned.fill(
              child: Align(
                alignment: alignment,
                child: Transform.translate(
                  offset: Offset(
                    alignment.x * size * .28,
                    alignment.y * size * .34,
                  ),
                  child: _Glow(
                    color: color,
                    size: size,
                    opacity: palette.isDark ? .5 : .55,
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, this.opacity = .55});
  final Color color;
  final double size;
  final double opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );
}
