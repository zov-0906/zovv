import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_sheet.dart';
import '../../../core/widgets/playback_scrubber.dart';
import '../../../core/widgets/zovv_loader.dart';
import '../../drama/application/drama_library_controller.dart';
import '../../drama/domain/drama.dart';
import '../../drama/domain/episode_extras.dart';
import '../../drama/domain/watch_progress.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.library,
    this.initialEpisode = 0,
  });
  final Drama drama;
  final DramaRepository repository;
  final DramaLibraryController library;
  final int initialEpisode;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  PlaybackSource? _source;
  late int _episode;
  int _generation = 0;
  int _lastSaved = -1;
  bool _loading = true;
  bool _autoNext = true;
  bool _advancing = false;
  bool _landscape = false;
  String? _error;

  /// Playback handles already resolved in this session, keyed by episode id.
  /// Switching back and forth reuses them instead of asking the source again.
  final Map<String, PlaybackSource> _sources = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episode = widget.initialEpisode.clamp(0, widget.drama.episodes.length - 1);
    unawaited(_load(_episode, resume: true));
  }

  bool _current(int generation) => mounted && generation == _generation;
  Future<void> _load(int index, {bool resume = false}) async {
    if (index < 0 || index >= widget.drama.episodes.length) return;
    final generation = ++_generation;
    _save();
    final previous = _player;
    _player = null;
    previous?.removeListener(_onVideo);
    setState(() {
      _episode = index;
      _loading = true;
      _error = null;
      _source = null;
      _lastSaved = -1;
      _advancing = false;
    });
    VideoPlayerController? candidate;
    try {
      await previous?.dispose();
      final episode = widget.drama.episodes[index];
      final cached = _sources[episode.id];
      final source =
          cached != null && (cached.expiresAt?.isAfter(DateTime.now()) ?? true)
          ? cached
          : await widget.repository
                .resolveEpisode(widget.drama.id, episode.id)
                .timeout(const Duration(seconds: 90));
      if (!_current(generation)) return;
      if (source.expiresAt != null &&
          source.expiresAt!.isBefore(DateTime.now())) {
        throw StateError('Expired playback URL');
      }
      _sources[episode.id] = source;
      candidate = VideoPlayerController.networkUrl(
        source.uri,
        httpHeaders: source.headers,
      );
      await candidate.initialize().timeout(const Duration(seconds: 25));
      if (!_current(generation)) {
        await candidate.dispose();
        return;
      }
      final progress = widget.library.progressFor(widget.drama.id);
      if (resume &&
          progress != null &&
          progress.episodeIndex == index &&
          progress.positionSeconds < candidate.value.duration.inSeconds - 2) {
        await candidate.seekTo(Duration(seconds: progress.positionSeconds));
      }
      if (!_current(generation)) {
        await candidate.dispose();
        return;
      }
      _player = candidate;
      _source = source;
      candidate.addListener(_onVideo);
      setState(() => _loading = false);
      _save();
      _prefetchNext();
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await candidate.play();
      }
    } catch (error) {
      if (_player != candidate) await candidate?.dispose();
      if (!_current(generation)) return;
      setState(() {
        _loading = false;
        _error = error is PlaybackUnavailable
            ? error.message
            : '视频暂时无法播放，请检查网络后重试';
      });
    }
  }

  void _onVideo() {
    final player = _player;
    if (!mounted || player == null) return;
    if (player.value.hasError && _error == null) {
      setState(() => _error = '播放中断，请重试');
    }
    final seconds = player.value.position.inSeconds;
    if ((seconds - _lastSaved).abs() >= 5) _save();
    if (player.value.isCompleted &&
        !_advancing &&
        _autoNext &&
        _episode + 1 < widget.drama.episodes.length) {
      _advancing = true;
      unawaited(_load(_episode + 1));
    }
  }

  /// Warms the next episode while the current one plays. Sources that do not
  /// implement [PrefetchedPlayback] simply skip this.
  void _prefetchNext() {
    final index = _episode + 1;
    if (index >= widget.drama.episodes.length) return;
    if (widget.repository case final PrefetchedPlayback prefetcher) {
      final episode = widget.drama.episodes[index];
      if (_sources.containsKey(episode.id)) return;
      prefetcher.prefetchEpisode(widget.drama.id, episode.id);
    }
  }

  void _save() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    _lastSaved = player.value.position.inSeconds;
    widget.library.record(
      WatchProgress(
        dramaId: widget.drama.id,
        episodeIndex: _episode,
        positionSeconds: _lastSaved,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _togglePlay() {
    final player = _player;
    if (player == null) return;
    if (player.value.isPlaying) {
      player.pause();
      _save();
    } else {
      player.play();
    }
  }

  void _selectEpisodes() {
    _player?.pause();
    _save();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = context.palette;
        return GlassSheet(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选集',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.drama.title} · 共 ${widget.drama.episodes.length} 集',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.muted),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .5,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.55,
                        ),
                    itemCount: widget.drama.episodes.length,
                    itemBuilder: (context, index) {
                      final episode = widget.drama.episodes[index];
                      final current = _episode == index;
                      return GlassButton(
                        compact: true,
                        label: '${episode.number}',
                        selected: current,
                        icon: episode.locked
                            ? Icons.lock_outline_rounded
                            : null,
                        onPressed: episode.locked
                            ? null
                            : () {
                                Navigator.pop(context);
                                unawaited(_load(index));
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleOrientation() async {
    _landscape = !_landscape;
    await SystemChrome.setPreferredOrientations(
      _landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _player?.pause();
      _save();
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _save();
    _player?.removeListener(_onVideo);
    unawaited(_player?.dispose());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    super.dispose();
  }

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (_loading) return;
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -300) unawaited(_load(_episode + 1));
          if (velocity > 300) unawaited(_load(_episode - 1));
        },
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 5, 17, 5),
                child: Row(
                  children: [
                    GlassSurface(
                      dark: true,
                      radius: 13,
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: IconButton(
                          tooltip: '返回详情',
                          padding: EdgeInsets.zero,
                          iconSize: 19,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.drama.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '第 ${_episode + 1} 集 · ${widget.drama.sourceName}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: widget.library,
                      builder: (context, _) => IconButton(
                        tooltip: '收藏',
                        onPressed: widget.library.ready
                            ? () =>
                                  widget.library.toggleFavorite(widget.drama.id)
                            : null,
                        icon: Icon(
                          widget.library.favorites.contains(widget.drama.id)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: _loading
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ZovvLoader(size: 34, color: Colors.white),
                            SizedBox(height: 18),
                            Text(
                              '正在连接故事…',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : _error != null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                color: Colors.white54,
                                size: 35,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: () => _load(_episode, resume: true),
                                child: const Text(
                                  '重新连接',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _player == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: _togglePlay,
                          child: AspectRatio(
                            aspectRatio: _player!.value.aspectRatio,
                            child: VideoPlayer(_player!),
                          ),
                        ),
                ),
              ),
              if (_player != null && !_loading && _error == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: GlassSurface(
                    dark: true,
                    radius: 18,
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _player!,
                      builder: (context, value, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                _time(value.position),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: PlaybackScrubber(
                                  position: value.position,
                                  duration: value.duration,
                                  onSeekStart: () => _player?.pause(),
                                  onSeek: (target) => _player?.seekTo(target),
                                  onSeekEnd: () {
                                    _save();
                                    _player?.play();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _time(value.duration),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: '上一集',
                                onPressed: _episode > 0
                                    ? () => _load(_episode - 1)
                                    : null,
                                icon: Icon(
                                  Icons.skip_previous_rounded,
                                  color: _episode > 0
                                      ? Colors.white
                                      : Colors.white24,
                                ),
                              ),
                              IconButton(
                                tooltip: value.isPlaying ? '暂停' : '播放',
                                onPressed: _togglePlay,
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 33,
                                ),
                              ),
                              TextButton(
                                onPressed: _selectEpisodes,
                                child: const Text(
                                  '选集',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                tooltip: '横竖屏切换',
                                onPressed: _toggleOrientation,
                                icon: const Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                tooltip: '下一集',
                                onPressed:
                                    _episode + 1 < widget.drama.episodes.length
                                    ? () => _load(_episode + 1)
                                    : null,
                                icon: Icon(
                                  Icons.skip_next_rounded,
                                  color:
                                      _episode + 1 <
                                          widget.drama.episodes.length
                                      ? Colors.white
                                      : Colors.white24,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!_landscape)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '自动连播',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          Switch.adaptive(
                            value: _autoNext,
                            activeTrackColor: AppColors.accent,
                            onChanged: (value) =>
                                setState(() => _autoNext = value),
                          ),
                        ],
                      ),
                      Text(
                        _source?.attribution ?? '上下滑动切换剧集',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
