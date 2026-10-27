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
          height: 106,
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
          width: 268,
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 96,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DramaPoster(drama: entry.drama, showTitle: false),
                      Align(
                        alignment: Alignment.center,
                        child: busy
                            ? const ZovvLoader(size: 18, color: Colors.white)
                            : const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.drama.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
