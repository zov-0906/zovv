import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/drama.dart';
import 'drama_poster.dart';

class DramaCard extends StatelessWidget {
  const DramaCard({super.key, required this.drama, required this.onTap});
  final Drama drama;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      key: Key('drama-card-${drama.id}'),
      button: true,
      label: '查看${drama.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DramaPoster(drama: drama, showTitle: false),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          drama.sourceName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              drama.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              drama.episodeCount > 0
                  ? '${drama.category} · ${drama.episodeLabel}'
                  : drama.category,
              style: TextStyle(color: palette.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
