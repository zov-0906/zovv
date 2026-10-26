import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'iridescent_sheen.dart';

/// Flat glass: a tight translucent fill, one hairline highlight and an almost
/// invisible shadow. Blur is kept low so surfaces read as printed layers rather
/// than bubbles.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = EdgeInsets.zero,
    this.dark = false,
    this.sheen = false,
    this.sheenToken = 0,
    this.sheenOpacity = .5,
    this.tint,
    this.breathe = false,
  });
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Locks the surface to the dark scrim used over media and in the player.
  final bool dark;

  /// Optional neutral wash under the fill, for recessed troughs.
  final Color? tint;

  /// Plays one pass of the pastel highlight across the surface.
  final bool sheen;

  /// Bump to replay [sheen], for example when a capsule moves.
  final int sheenToken;
  final double sheenOpacity;

  /// Lets the highlight drift by on a slow interval (see [IridescentSheen]).
  final bool breathe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final opaque = MediaQuery.highContrastOf(context);
    final top = dark
        ? const Color(0xFF1A1D23).withValues(alpha: .58)
        : palette.glassTop;
    final bottom = dark
        ? const Color(0xFF101216).withValues(alpha: .5)
        : palette.glassBottom;
    final border = dark
        ? Colors.white.withValues(alpha: .14)
        : palette.glassBorder;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : palette.glassShadow).withValues(
              alpha: dark ? .22 : .05,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: opaque ? 0 : 12,
            sigmaY: opaque ? 0 : 12,
          ),
          child: Stack(
            children: [
              if (tint != null)
                Positioned.fill(child: ColoredBox(color: tint!)),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: opaque
                          ? [
                              top.withValues(alpha: 1),
                              bottom.withValues(alpha: 1),
                            ]
                          : [top, bottom],
                    ),
                    border: Border.all(color: border, width: .7),
                  ),
                ),
              ),
              if (sheen || breathe)
                Positioned.fill(
                  child: IridescentSheen(
                    token: sheenToken,
                    opacity: sheenOpacity,
                    breathe: breathe,
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
