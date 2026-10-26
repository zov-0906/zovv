import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Floating sheet frame shared by secondary flows, including their error states.
class GlassSheet extends StatelessWidget {
  const GlassSheet({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
    child: GlassSurface(
      radius: 26,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Container(
                width: 30,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.muted.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    ),
  );
}
