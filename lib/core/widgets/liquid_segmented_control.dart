import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';
import 'iridescent_sheen.dart';

class LiquidSegment<T> {
  const LiquidSegment({required this.value, required this.label});
  final T value;
  final String label;
}

/// Flat segmented control: a shallow trough with a low tile that snaps between
/// equal segments, plus one pass of pastel light each time the selection moves.
class LiquidSegmentedControl<T> extends StatelessWidget {
  const LiquidSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 44,
    this.semanticLabel,
  });
  final List<LiquidSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final active = segments.indexWhere((segment) => segment.value == value);
    final index = active < 0 ? 0 : active;
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 340);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: GlassSurface(
        radius: 15,
        sheenToken: index,
        sheenOpacity: .3,
        breathe: true,
        tint: palette.isDark
            ? Colors.black.withValues(alpha: .28)
            : const Color(0x124B5A80),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth / segments.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    left: index * width + 3,
                    top: 3,
                    width: width - 6,
                    height: height - 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        color: palette.isDark
                            ? const Color(0xFF272C36)
                            : Colors.white,
                        border: Border.all(
                          color: palette.glassBorder,
                          width: .7,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.glassShadow.withValues(alpha: .06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: IridescentSheen(
                          token: index,
                          opacity: .55,
                          period: const Duration(milliseconds: 900),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < segments.length; i++)
                        Expanded(
                          child: Semantics(
                            selected: i == index,
                            button: true,
                            child: InkWell(
                              key: Key('liquid-segment-$i'),
                              borderRadius: BorderRadius.circular(11),
                              onTap: () {
                                if (i == index) return;
                                HapticFeedback.selectionClick();
                                onChanged(segments[i].value);
                              },
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: .2,
                                    fontWeight: i == index
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: i == index
                                        ? palette.ink
                                        : palette.muted,
                                  ),
                                  child: Text(segments[i].label),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
