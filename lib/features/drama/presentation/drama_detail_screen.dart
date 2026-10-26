import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_chip.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_sheet.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/zovv_loader.dart';
import '../../player/presentation/player_screen.dart';
import '../application/drama_library_controller.dart';
import '../domain/drama.dart';
import '../domain/episode_extras.dart';
import 'drama_details_page.dart';
import 'widgets/drama_poster.dart';

class DramaDetailScreen extends StatefulWidget {
  const DramaDetailScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.library,
  });
  final Drama drama;
  final DramaRepository repository;
  final DramaLibraryController library;
  @override
  State<DramaDetailScreen> createState() => _DramaDetailScreenState();
}

class _DramaDetailScreenState extends State<DramaDetailScreen> {
  bool _expanded = false;
  int _episodePage = 0;
  final _scroll = ScrollController();
  bool _pastCover = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateHeader);
  }

  void _updateHeader() {
    final pastCover = _scroll.offset > 220;
    if (pastCover != _pastCover) setState(() => _pastCover = pastCover);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Episode? get _currentEpisode {
    final drama = widget.drama;
    if (drama.episodes.isEmpty) return null;
    final index = widget.library.progressFor(drama.id)?.episodeIndex ?? 0;
    return drama.episodes[index.clamp(0, drama.episodes.length - 1)];
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? get _shareUrl {
    final drama = widget.drama;
    if (drama.isDemo) return null;
    final parts = drama.id.split(':');
    if (parts.length != 2 || parts.first != 'hongguo') return null;
    final episode = _currentEpisode;
    return episode == null
        ? 'https://hongguoduanju.com/detail?series_id=${parts.last}'
        : 'https://hongguoduanju.com/player/${parts.last}/${episode.id}';
  }

  Future<void> _copyShareLink() async {
    final url = _shareUrl;
    if (url == null) {
      _toast('演示剧目没有对应的来源页面');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    _toast('分享链接已复制');
  }

  void _openComments() {
    final repository = widget.repository;
    final episode = _currentEpisode;
    if (repository is! EpisodeCommentSource || episode == null) {
      _toast(repository is EpisodeCommentSource ? '还没有可查看的分集' : '当前来源没有公开评论');
      return;
    }
    // `EpisodeCommentSource` is a side interface, so promote through a pattern.
    final source = repository as EpisodeCommentSource;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        title: widget.drama.title,
        episodeLabel: '第 ${episode.number} 集',
        load: () => source.fetchComments(widget.drama.id, episode.id),
      ),
    );
  }

  void _openSequels() {
    final repository = widget.repository;
    if (repository is! SequelSource) {
      _toast('当前来源不支持查找续作');
      return;
    }
    final source = repository as SequelSource;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SequelSheet(
        load: () => source.findSequels(widget.drama.id),
        onOpen: (sequel) {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            CupertinoPageRoute<void>(
              builder: (_) => DramaDetailsPage(
                summary: sequel,
                repository: widget.repository,
                library: widget.library,
              ),
            ),
          );
        },
      ),
    );
  }

  void _play(int index) => Navigator.push(
    context,
    CupertinoPageRoute<void>(
      builder: (_) => PlayerScreen(
        drama: widget.drama,
        repository: widget.repository,
        library: widget.library,
        initialEpisode: index,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: widget.library,
      builder: (context, _) {
        final drama = widget.drama;
        final favorite = widget.library.favorites.contains(drama.id);
        final progress = widget.library.progressFor(drama.id);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: _pastCover && !palette.isDark
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: palette.canvas,
            systemNavigationBarIconBrightness: palette.isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: palette.canvas,
            body: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 300,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DramaPoster(drama: drama, showTitle: false),
                            Positioned(
                              left: 22,
                              bottom: 18,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .3),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: .18),
                                    width: .7,
                                  ),
                                ),
                                child: const Text(
                                  'ZOVV STORIES',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drama.title,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                height: 1.3,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              drama.subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: palette.muted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  '${drama.category}  /  ${drama.episodeCount} 集',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  key: const Key('detail-favorite'),
                                  tooltip: favorite ? '取消收藏' : '收藏短剧',
                                  onPressed: widget.library.ready
                                      ? () => widget.library.toggleFavorite(
                                          drama.id,
                                        )
                                      : null,
                                  icon: Icon(
                                    favorite
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    color: favorite
                                        ? palette.accent
                                        : palette.ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (drama.detailsNotice != null) ...[
                              GlassSurface(
                                radius: 12,
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  drama.detailsNotice!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: palette.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              '故事简介',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            AnimatedSize(
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              alignment: Alignment.topLeft,
                              child: Text(
                                drama.description,
                                maxLines: _expanded ? null : 3,
                                overflow: _expanded
                                    ? null
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.8,
                                  color: palette.muted,
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GlassButton(
                                compact: true,
                                icon: _expanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                label: _expanded ? '收起' : '展开',
                                onPressed: () =>
                                    setState(() => _expanded = !_expanded),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!drama.isDemo) ...[
                              Text(
                                '公开评论，只读。收藏仅保存在本机。',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: palette.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GlassButton(
                                          label: '查找下一季',
                                          icon: Icons.layers_outlined,
                                          onPressed: _openSequels,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GlassButton(
                                          label: '复制分享链接',
                                          icon: Icons.ios_share_rounded,
                                          onPressed: _copyShareLink,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GlassButton(
                                          label: favorite ? '已收藏到本机' : '收藏到本机',
                                          selected: favorite,
                                          icon: favorite
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_border_rounded,
                                          onPressed: () => widget.library
                                              .toggleFavorite(drama.id),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: GlassButton(
                                          label: '查看公开剧评',
                                          icon:
                                              Icons.chat_bubble_outline_rounded,
                                          onPressed: _openComments,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                            Row(
                              children: [
                                Text(
                                  '分集预览',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: palette.ink,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${drama.episodeCount} 集',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (drama.episodes.length > 100)
                              SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: (drama.episodes.length / 100)
                                      .ceil(),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, page) => GlassChip(
                                    label:
                                        '${page * 100 + 1}–${((page + 1) * 100).clamp(0, drama.episodes.length)}',
                                    selected: _episodePage == page,
                                    onTap: () =>
                                        setState(() => _episodePage = page),
                                  ),
                                ),
                              ),
                            if (drama.episodes.length > 100)
                              const SizedBox(height: 12),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  (drama.episodes.length - _episodePage * 100)
                                      .clamp(0, 100),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                              itemBuilder: (context, index) {
                                index += _episodePage * 100;
                                final episode = drama.episodes[index];
                                return GlassButton(
                                  compact: true,
                                  label: '${episode.number}',
                                  selected: progress?.episodeIndex == index,
                                  icon: episode.locked
                                      ? Icons.lock_outline_rounded
                                      : null,
                                  onPressed: episode.locked
                                      ? null
                                      : () => _play(index),
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: palette.isDark
                                    ? Colors.white.withValues(alpha: .04)
                                    : const Color(0xFFF0F2F7),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: palette.muted,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      drama.isDemo
                                          ? '演示剧目，视频为 Blender 开源短片。'
                                          : '片源：红果 · 播放与更新以来源为准。',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: palette.muted,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pastCover)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: MediaQuery.paddingOf(context).top + 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              palette.canvas,
                              palette.canvas.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 18,
                  right: 18,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          GlassSurface(
                            dark: !_pastCover,
                            radius: 13,
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: IconButton(
                                tooltip: '返回',
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: _pastCover
                                      ? palette.ink
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                      child: FilledButton.icon(
                        key: const Key('detail-play'),
                        onPressed: () => _play(progress?.episodeIndex ?? 0),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.ink,
                          foregroundColor: palette.canvas,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          progress == null
                              ? '开始观看'
                              : '继续第 ${progress.episodeIndex + 1} 集',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.title,
    required this.episodeLabel,
    required this.load,
  });
  final String title;
  final String episodeLabel;
  final Future<CommentDigest> Function() load;
  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late Future<CommentDigest> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassSheet(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .62,
        child: FutureBuilder<CommentDigest>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: ZovvLoader(size: 26));
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is PlaybackUnavailable
                            ? error.message
                            : '公开剧评暂时打不开，请稍后再试',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: palette.muted),
                      ),
                      const SizedBox(height: 16),
                      GlassButton(
                        label: '重试',
                        onPressed: () =>
                            setState(() => _future = widget.load()),
                      ),
                    ],
                  ),
                ),
              );
            }
            final digest = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '公开剧评',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.title} · ${widget.episodeLabel}'
                        '${digest.total != null ? ' · 共 ${digest.total} 条' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                      if (digest.notice != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          digest.notice!,
                          style: TextStyle(
                            fontSize: 10,
                            height: 1.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.line),
                Expanded(
                  child: digest.items.isEmpty
                      ? Center(
                          child: Text(
                            '官网暂未提供本集评论',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                          itemCount: digest.items.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 22,
                            color: palette.line.withValues(alpha: .7),
                          ),
                          itemBuilder: (context, index) {
                            final comment = digest.items[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        comment.author.isEmpty
                                            ? '匿名用户'
                                            : comment.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: palette.ink,
                                        ),
                                      ),
                                    ),
                                    if (comment.likes != null)
                                      Text(
                                        '♡ ${comment.likes}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: palette.muted,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  comment.content,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.65,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SequelSheet extends StatefulWidget {
  const _SequelSheet({required this.load, required this.onOpen});
  final Future<List<Drama>> Function() load;
  final ValueChanged<Drama> onOpen;
  @override
  State<_SequelSheet> createState() => _SequelSheetState();
}

class _SequelSheetState extends State<_SequelSheet> {
  late Future<List<Drama>> _future = widget.load();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GlassSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .6,
        ),
        child: FutureBuilder<List<Drama>>(
          future: _future,
          builder: (context, snapshot) {
            final Widget body;
            if (snapshot.connectionState != ConnectionState.done) {
              body = const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: ZovvLoader(size: 24)),
              );
            } else if (snapshot.hasError) {
              final error = snapshot.error;
              body = Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is PlaybackUnavailable
                          ? error.message
                          : '查找下一季未完成，请稍后再试',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: palette.muted),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: '重试',
                      onPressed: () => setState(() => _future = widget.load()),
                    ),
                  ],
                ),
              );
            } else if (snapshot.data!.isEmpty) {
              body = Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '下一季',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '暂未找到同名的后续季。续作由剧名季数推断，请核对后再播放。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              body = ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
                    child: Text(
                      '下一季（按剧名季数推断，请核对）',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  for (final sequel in snapshot.data!)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      leading: SizedBox(
                        width: 44,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: DramaPoster(drama: sequel, showTitle: false),
                        ),
                      ),
                      title: Text(
                        sequel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: palette.ink),
                      ),
                      subtitle: Text(
                        sequel.episodeCount > 0
                            ? '${sequel.episodeCount} 集'
                            : '续作',
                        style: TextStyle(fontSize: 11, color: palette.muted),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: palette.muted,
                      ),
                      onTap: () => widget.onOpen(sequel),
                    ),
                ],
              );
            }
            return body;
          },
        ),
      ),
    );
  }
}
