import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/widgets/zovv_refresh.dart';

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
    this.onScrollState,
    this.scrollToTop,
    this.remoteGenres,
    this.selectedGenre = '',
    this.onGenre,
    this.resumeEntries = const <ResumeEntry>[],
    this.onResume,
    this.busyId,
    this.loading = false,
    this.catalogError,
    this.onRetry,
    this.onRefresh,
    this.onLoadMore,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreError,
  });
  final List<Drama> dramas;
  final ValueChanged<Drama> onOpen;
  final VoidCallback onSearch;
  final Widget? sourceControls;
  final ValueChanged<bool>? onScrollState;
  final Listenable? scrollToTop;
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
  final Future<void> Function()? onRefresh;

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
  bool _away = false;
  final _introKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    widget.scrollToTop?.addListener(_top);
  }

  @override
  void didUpdateWidget(covariant DiscoverScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollToTop != widget.scrollToTop) {
      oldWidget.scrollToTop?.removeListener(_top);
      widget.scrollToTop?.addListener(_top);
    }
  }

  void _top() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  late final ScrollController _scroll = ScrollController()
    ..addListener(_onScroll);

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final away =
        _scroll.offset >
        (_away ? 140 : _scroll.position.viewportDimension * .8);
    if (away != _away) {
      _away = away;
      widget.onScrollState?.call(away);
    }
    if (_scroll.position.extentAfter < 600) widget.onLoadMore?.call();
  }

  @override
  void dispose() {
    widget.scrollToTop?.removeListener(_top);
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
    final recentIds = widget.resumeEntries
        .map((entry) => entry.drama.id)
        .toSet();
    final candidates = selected.where((drama) => !recentIds.contains(drama.id));
    final featured = candidates.isEmpty ? null : candidates.first;
    return ZovvRefresh(
      onRefresh: widget.onRefresh ?? () async {},
      child: CustomScrollView(
        key: const PageStorageKey('discover'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                key: _introKey,
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
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.muted,
                              ),
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
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _GenreHeader(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                child: SizedBox(
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
                          final box = _introKey.currentContext
                              ?.findRenderObject();
                          final start = box is RenderBox
                              ? box.size.height + 12
                              : 200.0;
                          if (_scroll.hasClients && _scroll.offset > start) {
                            _scroll.jumpTo(start);
                          }
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 22),
                  if (widget.catalogError != null && widget.dramas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        '更新失败，当前显示已加载内容。下拉可重试。',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ),
                  if (widget.loading && widget.dramas.isEmpty)
                    const DramaDiscoverSkeleton()
                  else if (widget.catalogError != null && widget.dramas.isEmpty)
                    _FeedNotice(
                      icon: Icons.cloud_off_rounded,
                      title: widget.catalogError!,
                      hint: '请检查网络连接，稍后重试',
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
                    if (widget.resumeEntries.isNotEmpty &&
                        widget.onResume != null) ...[
                      ContinueWatchingRail(
                        entries: widget.resumeEntries,
                        busyId: widget.busyId,
                        onResume: widget.onResume!,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (featured != null) ...[
                      Text(
                        '今日精选',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FeaturedCard(
                        drama: featured,
                        onTap: () => widget.onOpen(featured),
                      ),
                    ],
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
                  ],
                ],
              ),
            ),
          ),
          if (selected.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              sliver: SliverGrid.builder(
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
            ),
          if (selected.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 125),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
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
                ),
              ),
            ),
          if (selected.isEmpty)
            const SliverToBoxAdapter(child: SizedBox(height: 125)),
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

class _GenreHeader extends SliverPersistentHeaderDelegate {
  _GenreHeader({required this.child});
  final Widget child;
  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: ColoredBox(
        color: context.palette.canvas.withValues(alpha: .92),
        child: child,
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant _GenreHeader oldDelegate) => true;
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.drama, required this.onTap});
  final Drama drama;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 22,
    padding: const EdgeInsets.all(12),
    child: InkWell(
      key: const Key('discover-hero-play'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 132,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DramaPoster(drama: drama, showTitle: false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.palette.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${drama.category} · ${drama.episodeLabel}',
                  style: TextStyle(fontSize: 11, color: context.palette.muted),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_fill_rounded,
                      size: 24,
                      color: context.palette.accent,
                    ),
                    const SizedBox(width: 6),
                    const Text('看看这部', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
