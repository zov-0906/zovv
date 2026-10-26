import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_chip.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/zovv_loader.dart';
import '../application/drama_library_controller.dart';
import '../domain/drama.dart';
import 'widgets/continue_watching.dart';
import 'widgets/drama_card.dart';
import 'widgets/drama_poster.dart';
import 'widgets/drama_skeleton.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
    required this.dramas,
    required this.onOpen,
    required this.onSearch,
    this.sourceControls,
    this.remoteGenres,
    this.selectedGenre = '',
    this.onGenre,
    this.resumeEntries = const <ResumeEntry>[],
    this.onResume,
    this.busyId,
    this.loading = false,
    this.catalogError,
    this.onRetry,
    this.onLoadMore,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreError,
  });
  final List<Drama> dramas;
  final ValueChanged<Drama> onOpen;
  final VoidCallback onSearch;
  final Widget? sourceControls;
  final Map<String, String>? remoteGenres;
  final String selectedGenre;
  final ValueChanged<String>? onGenre;
  final List<ResumeEntry> resumeEntries;
  final ValueChanged<Drama>? onResume;
  final String? busyId;

  /// Only the feed below the controls goes into a loading state; the page chrome
  /// and the source selector stay interactive.
  final bool loading;
  final String? catalogError;
  final VoidCallback? onRetry;

  /// Infinite feed: fired when the scroll position approaches the end.
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final bool loadingMore;
  final String? moreError;
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _category = '精选';
  late final ScrollController _scroll = ScrollController()
    ..addListener(_onScroll);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 600) widget.onLoadMore?.call();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final remoteGenres = widget.remoteGenres;
    final categories = remoteGenres != null
        ? ['精选', ...remoteGenres.values]
        : ['精选', ...widget.dramas.map((drama) => drama.category).toSet()];
    final selected = widget.dramas
        .where(
          (drama) =>
              remoteGenres != null ||
              _category == '精选' ||
              drama.category == _category,
        )
        .toList();
    return SingleChildScrollView(
      key: const PageStorageKey('discover'),
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 125),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '好故事，慢慢看。',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.8,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '把片刻，留给喜欢的故事',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '搜索短剧',
                color: palette.ink,
                onPressed: widget.onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 21),
          if (widget.sourceControls != null) ...[
            widget.sourceControls!,
            const SizedBox(height: 18),
          ],
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final active = remoteGenres != null
                    ? (index == 0
                          ? widget.selectedGenre.isEmpty
                          : remoteGenres.keys.elementAt(index - 1) ==
                                widget.selectedGenre)
                    : _category == category;
                return GlassChip(
                  label: category,
                  selected: active,
                  onTap: () {
                    if (remoteGenres != null) {
                      widget.onGenre?.call(
                        index == 0
                            ? ''
                            : remoteGenres.keys.elementAt(index - 1),
                      );
                    } else {
                      setState(() => _category = category);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          if (widget.loading)
            const DramaDiscoverSkeleton()
          else if (widget.catalogError != null)
            _FeedNotice(
              icon: Icons.cloud_off_rounded,
              title: widget.catalogError!,
              hint: '确认电脑端调试服务在运行后再试一次',
              action: '重试',
              onAction: widget.onRetry,
            )
          else if (widget.dramas.isEmpty)
            const _FeedNotice(
              icon: Icons.movie_filter_outlined,
              title: '还没有上架的故事',
              hint: '换个题材，或者稍后再来看看',
            )
          else ...[
            if (widget.resumeEntries.isNotEmpty && widget.onResume != null) ...[
              ContinueWatchingRail(
                entries: widget.resumeEntries,
                busyId: widget.busyId,
                onResume: widget.onResume!,
              ),
              const SizedBox(height: 24),
            ],
            // Poster carries the artwork; text lives outside it so source covers
            // that already print a title never collide with ours.
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(27),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DramaPoster(drama: selected.first, showTitle: false),
                    Positioned(
                      top: 15,
                      left: 15,
                      child: GlassSurface(
                        dark: true,
                        radius: 12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '今日精选 · ${selected.first.sourceName}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              selected.first.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                height: 1.3,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selected.first.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, height: 1.6, color: palette.muted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Flexible(
                  child: Text(
                    '${selected.first.category} · ${selected.first.episodeLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: .4,
                      color: palette.muted,
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('discover-hero-play'),
                  onPressed: () => widget.onOpen(selected.first),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.canvas,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 11,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 19),
                  label: const Text('看看这部', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Text(
                  _category == '精选' ? '值得停留' : '$_category故事',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '为你精选',
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selected.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 22,
                childAspectRatio: .61,
              ),
              itemBuilder: (context, index) => DramaCard(
                drama: selected[index],
                onTap: () => widget.onOpen(selected[index]),
              ),
            ),
            const SizedBox(height: 22),
            _FeedFooter(
              loadingMore: widget.loadingMore,
              error: widget.moreError,
              hasMore: widget.hasMore,
              onRetry: widget.onLoadMore,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.dramas.first.isDemo
                    ? '演示片单 · 开源短片体验'
                    : '片源：红果 · 已加载 ${widget.dramas.length} 部',
                style: TextStyle(fontSize: 10, color: palette.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Footer of the infinite feed: loading row, retry row, or the end marker.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.loadingMore,
    required this.error,
    required this.hasMore,
    required this.onRetry,
  });
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ZovvLoader(size: 18),
            const SizedBox(width: 10),
            Text(
              '正在加载更多…',
              style: TextStyle(fontSize: 11, color: palette.muted),
            ),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(error!, style: const TextStyle(fontSize: 11)),
        ),
      );
    }
    if (!hasMore) {
      return Text(
        '已经到底了',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10.5, color: palette.muted),
      );
    }
    return const SizedBox(height: 8);
  }
}

/// Compact inline state for the feed area: never takes over the whole screen.
class _FeedNotice extends StatelessWidget {
  const _FeedNotice({
    required this.icon,
    required this.title,
    required this.hint,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String hint;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: BoxDecoration(
        color: palette.isDark
            ? Colors.white.withValues(alpha: .04)
            : Colors.white.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: palette.muted),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: palette.muted),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.ink,
                side: BorderSide(color: palette.line),
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}
