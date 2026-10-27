import 'package:flutter/material.dart';

import '../../../core/widgets/zovv_refresh.dart';

import '../../../core/theme/app_theme.dart';
import '../application/drama_library_controller.dart';
import '../domain/drama.dart';
import 'widgets/drama_poster.dart';
import 'widgets/drama_skeleton.dart';

class DramaLibraryScreen extends StatefulWidget {
  const DramaLibraryScreen({
    super.key,
    required this.dramas,
    required this.library,
    required this.onOpen,
    required this.onExplore,
    this.onResume,
    this.sourceFilter,
  });
  final List<Drama> dramas;
  final DramaLibraryController library;
  final ValueChanged<Drama> onOpen;

  /// Plays the saved episode directly; falls back to [onOpen] when absent.
  final ValueChanged<Drama>? onResume;
  final VoidCallback onExplore;
  final String? sourceFilter;
  @override
  State<DramaLibraryScreen> createState() => _DramaLibraryScreenState();
}

class _DramaLibraryScreenState extends State<DramaLibraryScreen> {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: widget.library,
      builder: (context, _) {
        final library = widget.library;
        final ids = library.favorites.toList();
        final available = {
          for (final drama in library.knownDramas) drama.id: drama,
          for (final drama in widget.dramas) drama.id: drama,
        };
        final items = ids
            .map((id) => available[id])
            .whereType<Drama>()
            .where(
              (drama) =>
                  widget.sourceFilter == null ||
                  drama.sourceName == widget.sourceFilter,
            )
            .toList();
        return ZovvRefresh(
          onRefresh: widget.library.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 125),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '我的片单',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '喜欢的故事，随时接着看',
                  style: TextStyle(fontSize: 12, color: palette.muted),
                ),
                const SizedBox(height: 24),
                if (library.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextButton(
                      onPressed: library.persist,
                      child: Text(
                        library.error!,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                if (!library.ready)
                  const DramaRowListSkeleton()
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 65),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bookmark_border_rounded,
                          color: palette.muted,
                          size: 38,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '把喜欢的故事留在这里',
                          style: TextStyle(fontSize: 17, color: palette.ink),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '在剧集详情中轻点收藏，就不会错过',
                          style: TextStyle(fontSize: 12, color: palette.muted),
                        ),
                        const SizedBox(height: 22),
                        OutlinedButton(
                          onPressed: widget.onExplore,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.ink,
                            side: BorderSide(color: palette.line),
                          ),
                          child: const Text('去发现'),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map((drama) {
                    final progress = library.progressFor(drama.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => widget.onOpen(drama),
                        child: Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: palette.isDark
                                ? Colors.white.withValues(alpha: .04)
                                : Colors.white.withValues(alpha: .62),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.line),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 69,
                                height: 94,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: DramaPoster(
                                    drama: drama,
                                    showTitle: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drama.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: palette.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      progress == null
                                          ? '${drama.category} · ${drama.episodeLabel}'
                                          : '第 ${progress.episodeIndex + 1} 集 · ${progress.positionSeconds ~/ 60}:${(progress.positionSeconds % 60).toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '取消收藏',
                                color: palette.ink,
                                onPressed: () =>
                                    library.toggleFavorite(drama.id),
                                icon: const Icon(
                                  Icons.bookmark_rounded,
                                  size: 21,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
