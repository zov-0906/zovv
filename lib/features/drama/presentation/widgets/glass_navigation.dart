import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_surface.dart';

/// Flat floating tab bar: a shallow trough and a low-elevation selected tile.
class GlassNavigation extends StatelessWidget {
  const GlassNavigation({
    super.key,
    required this.index,
    required this.onChanged,
    this.showTop = false,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final bool showTop;

  static const _icons = [
    Icons.explore_rounded,
    Icons.search_rounded,
    Icons.bookmark_rounded,
    Icons.person_outline_rounded,
  ];
  static const _labels = ['发现', '搜索', '片单', '我的'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 300);
    return GlassSurface(
      radius: 18,
      padding: const EdgeInsets.all(5),
      breathe: true,
      child: SizedBox(
        height: 46,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth / _labels.length;
            return Stack(
              children: [
                AnimatedAlign(
                  alignment: Alignment(2 * index / (_labels.length - 1) - 1, 0),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: width,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: palette.isDark
                          ? const Color(0xFF272C36)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: palette.glassBorder, width: .7),
                      boxShadow: [
                        BoxShadow(
                          color: palette.glassShadow.withValues(alpha: .06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_labels.length, (item) {
                    final active = index == item;
                    return Expanded(
                      child: Semantics(
                        selected: active,
                        child: InkWell(
                          key: Key('nav-$item'),
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => onChanged(item),
                          child: AnimatedSwitcher(
                            duration: duration,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, .15),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: Column(
                              key: ValueKey('$item-${item == 0 && showTop}'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item == 0 && showTop
                                      ? Icons.vertical_align_top_rounded
                                      : _icons[item],
                                  size: 19,
                                  color: active
                                      ? palette.accent
                                      : palette.muted,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item == 0 && showTop ? '回顶部' : _labels[item],
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: active ? palette.ink : palette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
