import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Original vector mark, reusable outside the startup animation.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ZOVV',
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color ?? context.palette.ink),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(14, 16)
        ..lineTo(89, 16)
        ..lineTo(77, 34)
        ..lineTo(2, 34)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(70, 30)
        ..lineTo(91, 30)
        ..lineTo(30, 84)
        ..lineTo(9, 84)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 66)
        ..lineTo(98, 66)
        ..lineTo(86, 84)
        ..lineTo(12, 84)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
