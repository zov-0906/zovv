import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/zovv_loader.dart';
import '../../application/drama_library_controller.dart';
import '../../domain/drama.dart';
import 'drama_poster.dart';

/// Home-page shortcut back into the exact episode and position a viewer left.
///
/// The rail only renders what the library actually stored: no placeholder
/// progress bars, because episode duration is not persisted yet.
class ContinueWatchingRail extends StatelessWidget {
  const ContinueWatchingRail({
    super.key,
    required this.entries,
    required this.onResume,
    this.busyId,
    this.maxEntries = 8,
  });
  final List<ResumeEntry> entries;
  final ValueChanged<Drama> onResume;

  /// Drama whose episode is currently being prepared, if any.
  final String? busyId;
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = entries.take(maxEntries).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '继续观看',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: palette.ink,
              ),
            ),
            const Spacer(),
            Text(
              '进度已自动保存',
              style: TextStyle(fontSize: 10, color: palette.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 141,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (context, index) => _ResumeCard(
              entry: items[index],
              busy: items[index].drama.id == busyId,
              onTap: () => onResume(items[index].drama),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.entry,
    required this.onTap,
    this.busy = false,
  });
  final ResumeEntry entry;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: '继续观看${entry.drama.title}${entry.episodeLabel}',
      child: InkWell(
        key: Key('resume-${entry.drama.id}'),
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 172,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 97,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DramaPoster(drama: entry.drama, showTitle: false),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 25,
                          height: 25,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .24),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .35),
                            ),
                          ),
                          child: busy
                              ? const ZovvLoader(size: 13, color: Colors.white)
                              : const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.drama.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                entry.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9.5, color: palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
