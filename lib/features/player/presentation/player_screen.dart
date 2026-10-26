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
import '../application/next_episode_buffer.dart';
import '../../drama/presentation/widgets/drama_comment_sheet.dart';

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

  VideoPlayerController? _opening;
  Future<void> _retiringPlayers = Future.value();
  late final NextEpisodeBuffer _buffer;
  NextEpisodeState _nextState = NextEpisodeState.idle;
  Timer? _prefetchTimer;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _descriptionExpanded = false;
  bool _resumeAfterSeek = false;
  bool _foreground = true;
  bool _sheetOpen = false;
  bool _retriedNext = false;
  int? _attemptedNext;
  String _loadingMessage = '正在连接故事…';
  final _timing = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episode = widget.initialEpisode.clamp(0, widget.drama.episodes.length - 1);
    _buffer = NextEpisodeBuffer(
      resolve: (index) => widget.repository.resolveEpisode(
        widget.drama.id,
        widget.drama.episodes[index].id,
      ),
      create: (source) => VideoPlayerController.networkUrl(
        source.uri,
        httpHeaders: source.headers,
      ),
      onChanged: (state) {
        if (mounted) setState(() => _nextState = state);
      },
    );
    unawaited(_load(_episode, resume: true));
  }

  bool _current(int generation) => mounted && generation == _generation;
  void _reportTiming(String phase) {
    assert(() {
      debugPrint(
        'ZOVV playback episode=${_episode + 1} phase=$phase elapsedMs=${_timing.elapsedMilliseconds}',
      );
      return true;
    }());
  }

  Future<void> _load(int index, {bool resume = false}) async {
    if (index < 0 || index >= widget.drama.episodes.length) return;
    if (widget.drama.episodes[index].locked) return;
    final generation = ++_generation;
    _save();
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _hideTimer?.cancel();
    final previous = _player;
    final abandoned = _opening;
    _opening = null;
    _player = null;
    previous?.removeListener(_onVideo);
    _timing
      ..reset()
      ..start();
    setState(() {
      _episode = index;
      _loading = true;
      _error = null;
      _source = null;
      _lastSaved = -1;
      _advancing = false;
      _controlsVisible = true;
      _attemptedNext = null;
      _retriedNext = false;
      _loadingMessage = '正在连接故事…';
    });
    VideoPlayerController? candidate;
    try {
      final retiring = _retiringPlayers;
      _retiringPlayers = () async {
        await retiring;
        await previous?.dispose();
        await abandoned?.dispose();
      }();
      await _retiringPlayers;
      await _buffer.cancelHandoff();
      if (!_current(generation)) return;
      final prepared = await _buffer.take(index);
      if (!_current(generation)) {
        await prepared?.controller.dispose();
        return;
      }
      late PlaybackSource source;
      if (prepared != null) {
        candidate = prepared.controller;
        source = prepared.source;
        _reportTiming('warm-player');
      } else {
        _nextState = NextEpisodeState.idle;
        source = await widget.repository
            .resolveEpisode(widget.drama.id, widget.drama.episodes[index].id)
            .timeout(const Duration(seconds: 90));
        if (!_current(generation)) return;
        _reportTiming('source-resolved');
        if (source.expiresAt?.isBefore(DateTime.now()) ?? false) {
          throw const PlaybackUnavailable('播放地址已过期，请重新连接');
        }
        setState(() => _loadingMessage = '正在缓冲画面…');
        candidate = VideoPlayerController.networkUrl(
          source.uri,
          httpHeaders: source.headers,
        );
        _opening = candidate;
        await candidate.initialize().timeout(const Duration(seconds: 25));
        _reportTiming('player-initialized');
      }
      if (!_current(generation)) {
        await candidate.dispose();
        return;
      }
      _opening = candidate;
      await candidate.setVolume(1);
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
      _opening = null;
      _player = candidate;
      _source = source;
      candidate.addListener(_onVideo);
      setState(() {
        _loading = false;
        _nextState = NextEpisodeState.idle;
      });
      _save();
      if (_foreground &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await candidate.play();
      }
      _armControls();
    } catch (error) {
      if (identical(_opening, candidate)) _opening = null;
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
    if (_timing.isRunning && player.value.position > Duration.zero) {
      _reportTiming('first-progress');
      _timing.stop();
    }
    if ((seconds - _lastSaved).abs() >= 5) _save();
    // Let the current player establish playback before warming the next item.
    if (_autoNext &&
        _foreground &&
        player.value.isPlaying &&
        !player.value.isBuffering &&
        _error == null) {
      _scheduleNext();
      if (_nextState == NextEpisodeState.failed &&
          !_retriedNext &&
          player.value.duration.inSeconds - seconds <= 20) {
        _retriedNext = true;
        _attemptedNext = null;
        _scheduleNext();
      }
    }
    if (player.value.isCompleted &&
        !_advancing &&
        _autoNext &&
        _foreground &&
        _episode + 1 < widget.drama.episodes.length &&
        !widget.drama.episodes[_episode + 1].locked) {
      _advancing = true;
      unawaited(_load(_episode + 1));
    }
  }

  void _scheduleNext() {
    final next = _episode + 1;
    if (!_autoNext ||
        !_foreground ||
        _loading ||
        _attemptedNext == next ||
        _prefetchTimer != null ||
        next >= widget.drama.episodes.length ||
        widget.drama.episodes[next].locked) {
      return;
    }
    final generation = _generation;
    _prefetchTimer = Timer(const Duration(seconds: 2), () {
      _prefetchTimer = null;
      if (!_current(generation) ||
          !_foreground ||
          !_autoNext ||
          (_player?.value.isBuffering ?? true) ||
          !(_player?.value.isPlaying ?? false)) {
        return;
      }
      _attemptedNext = next;
      _buffer.prepare(next);
    });
  }

  void _setAutoNext(bool value) {
    setState(() {
      _autoNext = value;
      _attemptedNext = null;
      _retriedNext = false;
    });
    if (value) {
      _scheduleNext();
    } else {
      _prefetchTimer?.cancel();
      _prefetchTimer = null;
      unawaited(_buffer.clear());
      setState(() => _nextState = NextEpisodeState.idle);
    }
  }

  void _armControls() {
    _hideTimer?.cancel();
    if (!_foreground || _sheetOpen || !(_player?.value.isPlaying ?? false)) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_sheetOpen && (_player?.value.isPlaying ?? false)) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    _armControls();
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
    setState(() => _controlsVisible = true);
    _armControls();
  }

  Future<void> _selectEpisodes() async {
    final wasPlaying = _player?.value.isPlaying ?? false;
    final generation = _generation;
    _sheetOpen = true;
    _hideTimer?.cancel();
    _player?.pause();
    _save();
    await showModalBottomSheet<void>(
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
    _sheetOpen = false;
    if (_current(generation) && _foreground && wasPlaying) {
      await _player?.play();
    }
    if (mounted) _armControls();
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
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _player?.pause();
      _save();
      _prefetchTimer?.cancel();
      _prefetchTimer = null;
      _hideTimer?.cancel();
      unawaited(_buffer.clear());
      _attemptedNext = null;
      if (mounted) {
        setState(() {
          _nextState = NextEpisodeState.idle;
          _controlsVisible = true;
        });
      }
    } else if (_player?.value.isPlaying ?? false) {
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    _prefetchTimer?.cancel();
    _hideTimer?.cancel();
    _save();
    _player?.removeListener(_onVideo);
    unawaited(_opening?.dispose());
    unawaited(_player?.dispose());
    unawaited(_buffer.dispose());
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    super.dispose();
  }

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  String get _nextLabel => switch (_nextState) {
    NextEpisodeState.preparing => '下一集准备中',
    NextEpisodeState.ready => '下一集已就绪',
    NextEpisodeState.failed => '下一集将在切换时重试',
    NextEpisodeState.idle => '',
  };

  Future<void> _more() async {
    _sheetOpen = true;
    _hideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, updateSheet) {
          final palette = context.palette;
          return GlassSheet(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '播放设置',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GlassSurface(
                    radius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.playlist_play_rounded, color: palette.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '自动连播',
                                style: TextStyle(
                                  color: palette.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '播完本集后继续下一集',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _autoNext,
                          activeTrackColor: palette.accent,
                          onChanged: (value) {
                            _setAutoNext(value);
                            updateSheet(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '只提前准备下一集，关闭后停止预加载。',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    _sheetOpen = false;
    if (mounted) _armControls();
  }

  Future<void> _comments() async {
    final repository = widget.repository;
    if (repository is! EpisodeCommentSource) return;
    final source = repository as EpisodeCommentSource;
    final episode = widget.drama.episodes[_episode];
    _sheetOpen = true;
    _hideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DramaCommentSheet(
        title: widget.drama.title,
        episodeLabel: '第 ${episode.number} 集',
        load: () => source.fetchComments(widget.drama.id, episode.id),
      ),
    );
    _sheetOpen = false;
    if (mounted) _armControls();
  }

  Future<void> _share() async {
    final parts = widget.drama.id.split(':');
    if (parts.length != 2 || parts.first != 'hongguo') return;
    final episode = widget.drama.episodes[_episode];
    await Clipboard.setData(
      ClipboardData(
        text: 'https://hongguoduanju.com/player/${parts.last}/${episode.id}',
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('分享链接已复制')));
    }
  }

  Widget _icon(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    double size = 21,
  }) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(
      icon,
      size: size,
      color: onTap == null ? Colors.white24 : Colors.white,
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 4, 12, 4),
    child: Row(
      children: [
        GlassSurface(
          dark: true,
          radius: 13,
          child: _icon(
            Icons.arrow_back_ios_new_rounded,
            '返回详情',
            () => Navigator.pop(context),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '第 ${widget.drama.episodes[_episode].number} 集',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GlassSurface(
          dark: true,
          radius: 13,
          child: _icon(Icons.more_horiz_rounded, '更多播放设置', _more),
        ),
      ],
    ),
  );

  Widget _videoArea() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZovvLoader(size: 32, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              _loadingMessage,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white54,
                size: 30,
              ),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _load(_episode, resume: true),
                child: const Text(
                  '重新连接',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final player = _player;
    if (player == null) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (context, value, _) {
          final visible = _controlsVisible || !value.isPlaying;
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
              IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GlassSurface(
                        dark: true,
                        radius: 16,
                        child: _icon(
                          Icons.skip_previous_rounded,
                          '上一集',
                          _episode > 0 &&
                                  !widget.drama.episodes[_episode - 1].locked
                              ? () => _load(_episode - 1)
                              : null,
                        ),
                      ),
                      GlassSurface(
                        dark: true,
                        radius: 24,
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: _icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            value.isPlaying ? '暂停' : '播放',
                            _togglePlay,
                            size: 34,
                          ),
                        ),
                      ),
                      GlassSurface(
                        dark: true,
                        radius: 16,
                        child: _icon(
                          Icons.skip_next_rounded,
                          '下一集',
                          _episode + 1 < widget.drama.episodes.length &&
                                  !widget.drama.episodes[_episode + 1].locked
                              ? () => _load(_episode + 1)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (value.isBuffering)
                const Positioned(
                  bottom: 14,
                  child: ZovvLoader(size: 18, color: Colors.white),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _information(double maxHeight) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.drama.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _source?.attribution ?? widget.drama.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 9),
                ),
                const SizedBox(height: 5),
                AnimatedSize(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  alignment: Alignment.topLeft,
                  child: Text(
                    '第 ${widget.drama.episodes[_episode].number} 集 · ${widget.drama.description}',
                    maxLines: _descriptionExpanded ? null : 2,
                    overflow: _descriptionExpanded
                        ? null
                        : TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(
                      () => _descriptionExpanded = !_descriptionExpanded,
                    ),
                    child: Text(
                      _descriptionExpanded ? '收起' : '展开',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                if (_nextLabel.isNotEmpty)
                  Text(
                    _nextLabel,
                    style: TextStyle(
                      color: _nextState == NextEpisodeState.ready
                          ? const Color(0xFFB5C6F8)
                          : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              AnimatedBuilder(
                animation: widget.library,
                builder: (_, _) => _icon(
                  widget.library.favorites.contains(widget.drama.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  '收藏',
                  widget.library.ready
                      ? () => widget.library.toggleFavorite(widget.drama.id)
                      : null,
                ),
              ),
              if (widget.repository is EpisodeCommentSource)
                _icon(Icons.chat_bubble_outline_rounded, '公开剧评', _comments),
              if (widget.drama.id.startsWith('hongguo:'))
                _icon(Icons.ios_share_rounded, '复制分享链接', _share),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _progress() {
    final player = _player;
    if (player == null || _loading || _error != null) {
      return const SizedBox(height: 16);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: player,
        builder: (_, value, _) => Row(
          children: [
            Text(
              _time(value.position),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PlaybackScrubber(
                position: value.position,
                duration: value.duration,
                onSeekStart: () {
                  _resumeAfterSeek = value.isPlaying;
                  player.pause();
                  _hideTimer?.cancel();
                },
                onSeek: (target) => player.seekTo(target),
                onSeekEnd: () {
                  _save();
                  if (_resumeAfterSeek && _foreground) player.play();
                  _armControls();
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _time(value.duration),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
    child: Row(
      children: [
        Expanded(
          child: GlassSurface(
            dark: true,
            radius: 15,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: _selectEpisodes,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.playlist_play_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '选集 · 共 ${widget.drama.episodeCount} 集',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 19,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        GlassSurface(
          dark: true,
          radius: 15,
          child: _icon(
            _landscape
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            '横竖屏切换',
            _toggleOrientation,
          ),
        ),
      ],
    ),
  );

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight;
            return GestureDetector(
              onVerticalDragEnd: (details) {
                if (_loading || wide) return;
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -300) unawaited(_load(_episode + 1));
                if (velocity > 300) unawaited(_load(_episode - 1));
              },
              child: wide
                  ? Stack(
                      children: [
                        Positioned.fill(child: _videoArea()),
                        Positioned(top: 0, left: 0, right: 0, child: _header()),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: GlassSurface(
                            dark: true,
                            radius: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [_progress(), _bottomBar()],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _header(),
                        Expanded(child: _videoArea()),
                        _information(constraints.maxHeight * .27),
                        _progress(),
                        _bottomBar(),
                      ],
                    ),
            );
          },
        ),
      ),
    ),
  );
}
