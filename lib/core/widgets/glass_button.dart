import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'glass_surface.dart';

/// Shared secondary action: neutral glass, quiet highlight and tactile press.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.selected = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool selected;
  final bool compact;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    final foreground = widget.selected ? palette.accent : palette.ink;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      child: AnimatedScale(
        scale: _pressed && !reduced ? .97 : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: GlassSurface(
            radius: widget.compact ? 12 : 16,
            tint: widget.selected
                ? palette.accent.withValues(alpha: .07)
                : null,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (value) => setState(() => _pressed = value),
                borderRadius: BorderRadius.circular(widget.compact ? 12 : 16),
                splashFactory: NoSplash.splashFactory,
                hoverColor: palette.accent.withValues(alpha: .05),
                highlightColor: palette.accent.withValues(alpha: .07),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.compact ? 12 : 14,
                      vertical: 11,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 17, color: foreground),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
