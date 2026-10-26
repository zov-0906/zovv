import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Light capsule used for genre filters. Selected state stays white-on-white —
/// the clip never paints a dark pill — and is marked by weight, a hairline and a
/// small accent bead so the choice still reads at a glance.
class GlassChip extends StatefulWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<GlassChip> createState() => _GlassChipState();
}

class _GlassChipState extends State<GlassChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 220);
    final selected = widget.selected;
    return AnimatedScale(
      scale: _pressed && !reduce ? .96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (palette.isDark ? const Color(0xFF272C36) : Colors.white)
              : (palette.isDark
                    ? Colors.white.withValues(alpha: .05)
                    : Colors.white.withValues(alpha: .5)),
          border: Border.all(
            color: selected
                ? palette.glassBorder
                : (palette.isDark
                      ? Colors.white.withValues(alpha: .08)
                      : Colors.white.withValues(alpha: .72)),
            width: .7,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.glassShadow.withValues(alpha: .06),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 14, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: selected ? 4.5 : 0,
                    height: 4.5,
                    margin: EdgeInsets.only(right: selected ? 7 : 0),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: .2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? palette.ink : palette.muted,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
