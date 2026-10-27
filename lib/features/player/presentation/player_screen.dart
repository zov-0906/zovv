import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/glass_sheet.dart';
import '../../../core/widgets/glass_chip.dart';
import '../../../core/widgets/playback_scrubber.dart';
import '../../../core/widgets/zovv_loader.dart';
import '../../drama/application/drama_library_controller.dart';
import '../../drama/domain/drama.dart';
import '../../drama/domain/episode_extras.dart';
import '../../drama/domain/danmaku.dart';
import '../../drama/domain/watch_progress.dart';
import '../application/next_episode_buffer.dart';
import '../application/playback_preferences.dart';
import '../application/preload_budget.dart';
import 'widgets/episode_picker.dart';
import 'widgets/danmaku_overlay.dart';
import '../../drama/presentation/widgets/drama_comment_sheet.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.drama,
    required this.repository,
    required this.library,
    this.initialEpisode = 0,
    this.createPlayer,
    this.preferences,
  });
  final Drama drama;
  final DramaRepository repository;
  final DramaLibraryController library;
  final int initialEpisode;
  final VideoPlayerController Function(PlaybackSource)? createPlayer;
  final PlaybackPreferences? preferences;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  PlaybackSource? _source;
  late int _episode;
  int _generation = 0;
  int _preloadEpoch = 0;
  String _session = List.generate(
    12,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  int _lastSaved = -1;
  bool _loading = true;
  bool _autoNext = true;
  bool _advancing = false;
  bool _landscape = false;
  String? _error;

  VideoPlayerController? _opening;
  Future<void> _retiringPlayers = Future.value();
  late final NextEpisodeBuffer _buffer;
  late final PlaybackPreferences _preferences;
  NextEpisodeState _nextState = NextEpisodeState.idle;
  Timer? _prefetchTimer;
  Timer? _hideTimer;
  Timer? _bufferingPreloadTimer;
  bool _controlsVisible = true;
  bool _userPaused = false;
  bool _switching = false;
  bool _dragging = false;
  bool _resetSlidePosition = false;
  double _drag = 0;
  double _pageHeight = 1;
  final _videoKey = GlobalKey();
  bool _descriptionExpanded = false;
  bool _resumeAfterSeek = false;
  bool _foreground = true;
  bool _sheetOpen = false;
  bool _qualityBusy = false;
  String _quality = 'auto';
  Duration? _seekPreview;
  bool _seeking = false;
  bool _retriedNext = false;
  int? _attemptedNext;
  String _loadingMessage = '正在连接故事…';
  final _timing = Stopwatch();
  DateTime? _bufferingStarted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _episode = widget.initialEpisode.clamp(0, widget.drama.episodes.length - 1);
    _buffer = NextEpisodeBuffer(
      resolve: (index) => _resolveEpisode(index, preload: true),
      create: _createPlayer,
      onChanged: (state) {
        if (mounted) setState(() => _nextState = state);
      },
    );
    _preferences = widget.preferences ?? PlaybackPreferences();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await _preferences.load();
    if (!mounted) return;
    _autoNext = _preferences.autoNext;
    _quality = _preferences.quality;
    await _load(_episode, resume: true);
  }

  Future<PlaybackSource> _resolveEpisode(
    int index, {
    bool preload = false,
    bool waitComplete = false,
  }) async {
    final session = _session, sequence = _generation;
    final preloadEpoch = _preloadEpoch;
    final quality = _preferences.quality;
    if (preload) await _retiringPlayers;
    if (preload &&
        (!mounted ||
            !_foreground ||
            !_autoNext ||
            _qualityBusy ||
            preloadEpoch != _preloadEpoch ||
            sequence != _generation ||
            session != _session)) {
      throw const PlaybackUnavailable('预加载已取消', code: 'PLAYBACK_CANCELLED');
    }
    final repository = widget.repository;
    final episode = widget.drama.episodes[index];
    if (repository is ScheduledPlaybackRepository) {
      final scheduled = repository as ScheduledPlaybackRepository;
      try {
        return await scheduled.resolveScheduledEpisode(
          widget.drama.id,
          episode.id,
          session: session,
          sequence: sequence,
          preload: preload,
          quality: quality,
          waitComplete: waitComplete,
        );
      } on PlaybackUnavailable catch (error) {
        if (quality == 'auto' || error.code != 'QUALITY_UNAVAILABLE') rethrow;
        return scheduled.resolveScheduledEpisode(
          widget.drama.id,
          episode.id,
          session: session,
          sequence: sequence,
          preload: preload,
          quality: 'auto',
          waitComplete: waitComplete,
        );
      }
    }
    return repository.resolveEpisode(widget.drama.id, episode.id);
  }

  Future<void> _changeQuality(
    String quality, {
    Duration? position,
    bool? resume,
    bool force = false,
  }) async {
    if (_qualityBusy ||
        (!force && quality == _quality && quality == _preferences.quality)) {
      return;
    }
    final repository = widget.repository;
    if (repository is! ScheduledPlaybackRepository) return;
    final scheduled = repository as ScheduledPlaybackRepository;
    final previous = _player;
    if (previous == null) {
      _quality = quality;
      if (!force) {
        unawaited(
          _preferences.save(quality: quality).catchError((Object _) {}),
        );
      }
      await _load(_episode, resume: true);
      return;
    }
    final generation = _generation;
    _reportTiming('replacement-start-$quality');
    final nextSession = List.generate(
      12,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final oldSession = _session;
    var handoffWasPlaying = resume ?? previous.value.isPlaying;
    var pausedForHandoff = false;
    VideoPlayerController? candidate;
    bool committed = false;
    setState(() {
      _qualityBusy = true;
      _nextState = NextEpisodeState.idle;
      _attemptedNext = null;
    });
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    try {
      await _buffer.clear();
      await _retiringPlayers;
      final source = await scheduled.resolveScheduledEpisode(
        widget.drama.id,
        widget.drama.episodes[_episode].id,
        session: nextSession,
        sequence: generation,
        quality: quality,
        waitComplete: true,
      );
      if (!_current(generation)) return;
      candidate = _createPlayer(source);
      _opening = candidate;
      await candidate.initialize().timeout(const Duration(seconds: 25));
      if (!_current(generation)) return;
      final target = int.tryParse(quality.replaceAll('p', ''));
      final size = candidate.value.size;
      if (target != null && min(size.width, size.height).round() != target) {
        throw const PlaybackUnavailable('片源实际分辨率与所选档位不符，继续原画质');
      }
      final duration = source.duration;
      if (duration != null && duration > candidate.value.duration) {
        candidate.value = candidate.value.copyWith(duration: duration);
      }
      await candidate.setPlaybackSpeed(_preferences.speed);
      await candidate.seekTo(position ?? previous.value.position);
      if (!_current(generation)) return;
      handoffWasPlaying = resume ?? previous.value.isPlaying;
      pausedForHandoff = true;
      await previous.pause();
      if (handoffWasPlaying && !_userPaused && _foreground) {
        await candidate.play();
      }
      previous.removeListener(_onVideo);
      _player = candidate;
      _opening = null;
      _source = source;
      _session = nextSession;
      _quality = quality;
      committed = true;
      _reportTiming(
        'replacement-ready-${size.width.round()}x${size.height.round()}-position-${candidate.value.position.inMilliseconds}',
      );
      candidate.addListener(_onVideo);
      _attemptedNext = null;
      _retriedNext = false;
      final retiring = _retiringPlayers;
      _retiringPlayers = () async {
        await retiring;
        await previous.dispose();
      }();
      if (!force) {
        unawaited(
          _preferences.save(quality: quality).catchError((Object _) {}),
        );
      }
      unawaited(scheduled.releasePlaybackSession(oldSession));
      if (mounted) setState(() {});
    } catch (_) {
      if (_current(generation)) {
        if (!_userPaused &&
            _foreground &&
            (pausedForHandoff
                ? handoffWasPlaying
                : (resume ?? previous.value.isPlaying))) {
          await previous.play();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(force ? '目标位置暂未就绪，继续原进度' : '画质切换未完成，继续原画质')),
          );
        }
      }
    } finally {
      if (!committed) {
        if (identical(_opening, candidate)) _opening = null;
        await candidate?.dispose();
        await scheduled.releasePlaybackSession(nextSession);
      }
      if (mounted) {
        setState(() => _qualityBusy = false);
        _armControls();
        _scheduleNext();
      }
    }
  }

  VideoPlayerController _createPlayer(PlaybackSource source) =>
      widget.createPlayer?.call(source) ??
      VideoPlayerController.networkUrl(source.uri, httpHeaders: source.headers);

  bool _current(int generation) => mounted && generation == _generation;
  void _reportTiming(String phase) {
    assert(() {
      debugPrint(
        'ZOVV playback episode=${_episode + 1} phase=$phase elapsedMs=${_timing.elapsedMilliseconds}',
      );
      return true;
    }());
  }

  Future<void> _load(
    int index, {
    bool resume = false,
    bool automatic = false,
  }) async {
    if (index < 0 || index >= widget.drama.episodes.length) return;
    if (widget.drama.episodes[index].locked) return;
    final generation = ++_generation;
    _bufferingPreloadTimer?.cancel();
    _bufferingPreloadTimer = null;
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
      _controlsVisible = !automatic;
      _userPaused = false;
      _seekPreview = null;
      _seeking = false;
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
      _reportTiming('retiring-players');
      await _retiringPlayers;
      _reportTiming('players-retired');
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
        final saved = widget.library.progressFor(widget.drama.id);
        source = await _resolveEpisode(
          index,
          waitComplete:
              resume &&
              saved?.episodeIndex == index &&
              (saved?.positionSeconds ?? 0) > 0,
        ).timeout(const Duration(seconds: 90));
        if (!_current(generation)) return;
        _reportTiming('source-resolved');
        if (source.expiresAt?.isBefore(DateTime.now()) ?? false) {
          throw const PlaybackUnavailable('播放地址已过期，请重新连接');
        }
        setState(() => _loadingMessage = '正在缓冲画面…');
        candidate = _createPlayer(source);
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
      await candidate.setPlaybackSpeed(_preferences.speed);
      final fullDuration = source.duration;
      if (fullDuration != null && fullDuration > candidate.value.duration) {
        // The plugin clamps positions to its initial duration. An EVENT HLS
        // window is shorter than the movie, so use the validated MP4 timeline.
        candidate.value = candidate.value.copyWith(duration: fullDuration);
      }
      _reportTiming(
        'timeline-${candidate.value.duration.inMilliseconds}-speed-${_preferences.speed}',
      );
      if (source.uri.path.endsWith('.m3u8')) {
        await candidate.seekTo(Duration.zero);
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
      _opening = null;
      _player = candidate;
      _source = source;
      _quality = source.selection;
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
      _reportTiming('failed-${error.runtimeType}');
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
    final stalled = player.value.isBuffering && player.value.isPlaying;
    if (stalled && _bufferingStarted == null) {
      _bufferingStarted = DateTime.now();
      debugPrint(
        'ZOVV buffer start episode=${_episode + 1} '
        'positionMs=${player.value.position.inMilliseconds} '
        'aheadMs=${bufferedAhead(player.value).inMilliseconds}',
      );
    } else if (!stalled && _bufferingStarted != null) {
      debugPrint(
        'ZOVV buffer end episode=${_episode + 1} '
        'waitMs=${DateTime.now().difference(_bufferingStarted!).inMilliseconds} '
        'aheadMs=${bufferedAhead(player.value).inMilliseconds}',
      );
      _bufferingStarted = null;
    }
    if ((player.value.isBuffering ||
            bufferedAhead(player.value) < const Duration(seconds: 3)) &&
        _nextState == NextEpisodeState.preparing) {
      _bufferingPreloadTimer ??= Timer(const Duration(seconds: 2), () {
        _bufferingPreloadTimer = null;
        if (mounted &&
            _player != null &&
            (_player!.value.isBuffering ||
                bufferedAhead(_player!.value) < const Duration(seconds: 3))) {
          _stopPreload();
        }
      });
    } else {
      _bufferingPreloadTimer?.cancel();
      _bufferingPreloadTimer = null;
    }
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
        !_dragging &&
        !_switching &&
        !_advancing &&
        _autoNext &&
        _foreground &&
        _episode + 1 < widget.drama.episodes.length &&
        !widget.drama.episodes[_episode + 1].locked) {
      _advancing = true;
      unawaited(_load(_episode + 1, automatic: true));
    }
  }

  void _scheduleNext() {
    final next = _episode + 1;
    if (!_autoNext ||
        _qualityBusy ||
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
          _player == null ||
          !canWarmNext(_player!.value)) {
        return;
      }
      _attemptedNext = next;
      _buffer.prepare(next);
    });
  }

  void _setAutoNext(bool value) {
    unawaited(_preferences.save(autoNext: value).catchError((Object _) {}));
    setState(() {
      _autoNext = value;
      _attemptedNext = null;
      _retriedNext = false;
    });
    if (value) {
      _scheduleNext();
    } else {
      _stopPreload();
    }
  }

  void _stopPreload() {
    ++_preloadEpoch;
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _bufferingPreloadTimer?.cancel();
    _bufferingPreloadTimer = null;
    unawaited(_buffer.clear());
    _attemptedNext = null;
    final repository = widget.repository;
    if (repository is PreloadCancellationRepository) {
      unawaited(
        (repository as PreloadCancellationRepository)
            .cancelPreload(_session, _generation)
            .catchError((Object _) {}),
      );
    }
    if (mounted) setState(() => _nextState = NextEpisodeState.idle);
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
      _userPaused = true;
      player.pause();
      _save();
    } else {
      _userPaused = false;
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
                  child: EpisodePicker(
                    episodes: widget.drama.episodes,
                    current: _episode,
                    onSelected: (index) {
                      Navigator.pop(context);
                      unawaited(_load(index));
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
    await SystemChrome.setEnabledSystemUIMode(
      _landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) {
      setState(() => _controlsVisible = false);
      _armControls();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _player?.pause();
      _save();
      _stopPreload();
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
    _bufferingPreloadTimer?.cancel();
    _hideTimer?.cancel();
    _save();
    _player?.removeListener(_onVideo);
    unawaited(_opening?.dispose());
    unawaited(_player?.dispose());
    unawaited(_buffer.dispose());
    final repository = widget.repository;
    if (repository is ScheduledPlaybackRepository) {
      unawaited(
        (repository as ScheduledPlaybackRepository).releasePlaybackSession(
          _session,
        ),
      );
    }
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, updateSheet) {
          final palette = context.palette;
          return GlassSheet(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .8,
              ),
              child: SingleChildScrollView(
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
                      Text(
                        '播放倍速',
                        style: TextStyle(color: palette.ink, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final speed in PlaybackPreferences.speeds)
                            GlassChip(
                              label:
                                  '${speed == speed.roundToDouble() ? speed.toInt() : speed}×',
                              selected: _preferences.speed == speed,
                              onTap: () async {
                                try {
                                  final player = _player;
                                  await player?.setPlaybackSpeed(speed);
                                  await _preferences.save(speed: speed);
                                  if (mounted) setState(() {});
                                  if (context.mounted) updateSheet(() {});
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                          const SnackBar(
                                            content: Text('暂时无法切换倍速，请重试'),
                                          ),
                                        );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.repository is ScheduledPlaybackRepository) ...[
                        Text(
                          _qualityBusy ? '正在准备所选画质…' : '清晰度',
                          style: TextStyle(color: palette.ink, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final quality in {
                              'auto',
                              ...?_source?.availableQualities,
                            })
                              GlassChip(
                                label: quality == 'auto' ? '自动' : quality,
                                selected: _quality == quality,
                                onTap: () async {
                                  final work = _changeQuality(quality);
                                  updateSheet(() {});
                                  await work;
                                  if (context.mounted) updateSheet(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '自动使用默认画质。',
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (widget.repository is EpisodeDanmakuSource) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '弹幕',
                                style: TextStyle(
                                  color: palette.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: _preferences.danmaku,
                              activeTrackColor: palette.accent,
                              onChanged: (value) {
                                unawaited(
                                  _preferences
                                      .save(danmaku: value)
                                      .catchError((Object _) {}),
                                );
                                setState(() {});
                                updateSheet(() {});
                              },
                            ),
                          ],
                        ),
                        Text(
                          '与播放进度同步显示，关闭后隐藏。',
                          style: TextStyle(color: palette.muted, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                      ],
                      GlassSurface(
                        radius: 16,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.playlist_play_rounded,
                              color: palette.ink,
                            ),
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
                        '关闭后，播完本集将停止播放。',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
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
        TextButton(
          onPressed: _more,
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          child: Text(
            '${_preferences.speed == _preferences.speed.roundToDouble() ? _preferences.speed.toInt() : _preferences.speed}×',
            style: const TextStyle(fontSize: 12),
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
          final visible = _controlsVisible || _userPaused;
          return Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
              if (_preferences.danmaku &&
                  widget.repository is EpisodeDanmakuSource)
                Positioned.fill(
                  child: DanmakuOverlay(
                    key: ValueKey(
                      '${widget.drama.id}:${widget.drama.episodes[_episode].id}',
                    ),
                    player: player,
                    source: widget.repository as EpisodeDanmakuSource,
                    dramaId: widget.drama.id,
                    episodeId: widget.drama.episodes[_episode].id,
                  ),
                ),
              IgnorePointer(
                ignoring: !visible || _seeking,
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
              if (value.isBuffering || _seeking)
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
                if (!_loading && _nextLabel.isNotEmpty)
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

  Future<void> _finishSeek(VideoPlayerController player) async {
    if (_qualityBusy || _seekPreview == null) return;
    final target = _seekPreview!;
    final generation = _generation;
    try {
      if (_source?.complete == false) {
        setState(() => _seeking = true);
        await _changeQuality(
          _quality,
          position: target,
          resume: _resumeAfterSeek,
          force: true,
        );
      } else {
        await player.seekTo(target);
        if (_current(generation) &&
            identical(_player, player) &&
            _resumeAfterSeek &&
            _foreground &&
            target < player.value.duration) {
          await player.play();
        }
      }
    } catch (_) {
      if (_current(generation)) {
        if (_resumeAfterSeek && _foreground) {
          try {
            await _player?.play();
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('暂时无法跳转，请重试')));
        }
      }
    } finally {
      if (_current(generation)) {
        setState(() {
          _seekPreview = null;
          _seeking = false;
        });
        _save();
        _armControls();
      }
    }
  }

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
              _time(_seekPreview ?? value.position),
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PlaybackScrubber(
                key: ObjectKey(player),
                position: _seekPreview ?? value.position,
                duration: value.duration,
                onInteractionStart: () => _hideTimer?.cancel(),
                onInteractionCancel: _armControls,
                onSeekStart: () {
                  if (_qualityBusy) return;
                  _resumeAfterSeek = value.isPlaying;
                  setState(() => _seekPreview = value.position);
                  player.pause();
                  _hideTimer?.cancel();
                },
                onSeek: (target) {
                  if (!_qualityBusy) setState(() => _seekPreview = target);
                },
                onSeekEnd: () => unawaited(_finishSeek(player)),
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

  bool get _fullscreen =>
      _landscape || MediaQuery.sizeOf(context).aspectRatio > 1;

  Widget _chrome(Widget child) => IgnorePointer(
    ignoring: _fullscreen && !_controlsVisible && !_userPaused,
    child: AnimatedOpacity(
      opacity: !_fullscreen || _controlsVisible || _userPaused ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: child,
    ),
  );

  Future<void> _finishDrag(double velocity) async {
    if (_switching || _loading || _sheetOpen) return;
    _dragging = false;
    final direction = _drag.abs() > _pageHeight * .18
        ? (_drag < 0 ? 1 : -1)
        : velocity.abs() > 500
        ? (velocity < 0 ? 1 : -1)
        : 0;
    final target = _episode + direction;
    if (direction == 0 ||
        target < 0 ||
        target >= widget.drama.episodes.length ||
        widget.drama.episodes[target].locked) {
      setState(() => _drag = 0);
      _armControls();
      _onVideo();
      return;
    }
    _switching = true;
    final dragGeneration = _generation;
    final reduced = MediaQuery.disableAnimationsOf(context);
    setState(() => _drag = -direction * _pageHeight);
    if (!reduced) await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (dragGeneration != _generation) {
      setState(() {
        _switching = false;
        _drag = 0;
      });
      return;
    }
    // Enter from the corresponding edge without creating a third video player.
    setState(() {
      _resetSlidePosition = true;
      _drag = direction * _pageHeight;
    });
    final loading = _load(target, automatic: true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _resetSlidePosition = false;
      _drag = 0;
    });
    await loading;
    _switching = false;
  }

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
            _pageHeight = constraints.maxHeight;
            return GestureDetector(
              onTap: _toggleControls,
              onVerticalDragStart: wide
                  ? null
                  : (details) {
                      if (_loading || _switching || _sheetOpen) return;
                      final box =
                          _videoKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (box == null ||
                          !(Offset.zero & box.size).contains(
                            box.globalToLocal(details.globalPosition),
                          )) {
                        return;
                      }
                      _hideTimer?.cancel();
                      _dragging = true;
                    },
              onVerticalDragUpdate: wide
                  ? null
                  : (details) {
                      if (!_dragging || _loading || _switching || _sheetOpen) {
                        return;
                      }
                      setState(
                        () => _drag = (_drag + details.delta.dy).clamp(
                          -_pageHeight,
                          _pageHeight,
                        ),
                      );
                    },
              onVerticalDragCancel: () {
                setState(() {
                  _drag = 0;
                  _dragging = false;
                });
                _armControls();
              },
              onVerticalDragEnd: wide
                  ? null
                  : (details) => _dragging
                        ? unawaited(_finishDrag(details.primaryVelocity ?? 0))
                        : null,
              child: AnimatedSlide(
                offset: Offset(0, _drag / _pageHeight),
                duration:
                    _dragging ||
                        _resetSlidePosition ||
                        MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: wide
                    ? Stack(
                        children: [
                          Positioned.fill(child: _videoArea()),
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: _chrome(_header()),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: _chrome(
                              GlassSurface(
                                dark: true,
                                radius: 16,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [_progress(), _bottomBar()],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _chrome(_header()),
                          Expanded(
                            child: SizedBox(
                              key: _videoKey,
                              child: _videoArea(),
                            ),
                          ),
                          _information(constraints.maxHeight * .27),
                          _chrome(_progress()),
                          _chrome(_bottomBar()),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
