import 'widgets/glass_navigation.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/liquid_segmented_control.dart';
import '../../../core/widgets/soft_background.dart';
import '../../../core/widgets/zovv_loader.dart';
import '../../player/presentation/player_screen.dart';
import '../application/drama_catalog_controller.dart';
import '../application/drama_library_controller.dart';

import '../data/demo_drama_repository.dart';
import '../data/hongguo_drama_repository.dart';
import '../data/local_library_storage.dart';
import '../domain/drama.dart';
import '../domain/watch_progress.dart';
import 'discover_screen.dart';
import 'my_screen.dart';
import 'drama_details_page.dart';
import 'drama_library_screen.dart';
import 'drama_search_screen.dart';

class DramaShell extends StatefulWidget {
  const DramaShell({
    super.key,
    required this.onReplayStartup,
    this.repository,
    this.storage,
    this.themeMode = ThemeMode.system,
    this.onThemeMode,
    this.onPrepared,
  });
  final VoidCallback onReplayStartup;
  final DramaRepository? repository;
  final LibraryStorage? storage;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeMode;
  final VoidCallback? onPrepared;
  @override
  State<DramaShell> createState() => _DramaShellState();
}

class _DramaShellState extends State<DramaShell> {
  /// Debug builds can swap in the bundled demo catalog with
  /// `--dart-define=ZOVV_DEMO_SOURCE=true` to inspect UI without the gateway.
  static const _demoSource = bool.fromEnvironment('ZOVV_DEMO_SOURCE');
  late final DramaCatalogController _catalog;
  late final DramaLibraryController _library;
  int _tab = 0;
  final _topSignal = ValueNotifier(0);
  bool _showTop = false;
  Timer? _startupDeadline;
  bool _prepared = false;
  bool _localReady = false;
  String? _resumingId;
  @override
  void initState() {
    super.initState();
    _catalog = DramaCatalogController(
      widget.repository ??
          (_demoSource ? DemoDramaRepository() : HongguoDramaRepository()),
      cache: widget.repository == null && !_demoSource
          ? LocalCatalogStorage()
          : null,
      cacheKey: () {
        final source = _catalog.repository;
        return source is HongguoDramaRepository
            ? 'hongguo:${source.contentType}:${source.genre}'
            : 'demo';
      },
    );
    _catalog.addListener(_checkPrepared);
    unawaited(_catalog.load());
    _library = DramaLibraryController(widget.storage ?? LocalLibraryStorage());
    unawaited(_prepareLocal());
    _startupDeadline = Timer(
      const Duration(milliseconds: 2200),
      _completePrepared,
    );
  }

  Future<void> _prepareLocal() async {
    try {
      await _library.load().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _localReady = true;
    _checkPrepared();
  }

  void _checkPrepared() {
    if (_localReady && (_catalog.dramas.isNotEmpty || !_catalog.loading)) {
      _completePrepared();
    }
  }

  void _completePrepared() {
    if (!mounted || _prepared) return;
    _prepared = true;
    _startupDeadline?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPrepared?.call();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    _startupDeadline?.cancel();
    _catalog.removeListener(_checkPrepared);
    _topSignal.dispose();
    _catalog.dispose();
    _library.dispose();
    super.dispose();
  }

  void _open(Drama drama) {
    _library.remember(drama);
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => DramaDetailsPage(
          summary: drama,
          repository: _catalog.repository,
          library: _library,
        ),
      ),
    );
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the saved episode directly, without the details page in between.
  /// Catalog entries carry no episode list, so remote sources resolve details
  /// first; the player then restores the stored position for that episode.
  Future<void> _resume(Drama drama) async {
    if (_resumingId != null) return;
    final source = _catalog.repository;
    final index = _library.progressFor(drama.id)?.episodeIndex ?? 0;
    var target = drama;
    if (target.episodes.isEmpty) {
      // Saved summaries never store episodes; prefer the live catalog entry.
      for (final item in _catalog.dramas) {
        if (item.id == drama.id && item.episodes.isNotEmpty) {
          target = item;
          break;
        }
      }
    }
    if (target.episodes.isEmpty) {
      // `DetailedDramaRepository` is a side interface rather than a subtype of
      // `DramaRepository`, so match on it instead of relying on promotion.
      if (source case final DetailedDramaRepository detailed) {
        setState(() => _resumingId = drama.id);
        try {
          target = await detailed.fetchDetails(drama);
          if (!mounted) return;
          _library.remember(target);
        } on PlaybackUnavailable catch (error) {
          _notify(error.message);
          return;
        } catch (_) {
          _notify('暂时打不开这一集，请稍后重试');
          return;
        } finally {
          if (mounted) setState(() => _resumingId = null);
        }
      } else {
        _open(drama);
        return;
      }
    }
    if (!mounted || target.episodes.isEmpty) return;
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => PlayerScreen(
          drama: target,
          repository: source,
          library: _library,
          initialEpisode: index.clamp(0, target.episodes.length - 1),
        ),
      ),
    );
  }

  Widget _hongguoControls() {
    final palette = context.palette;
    final repository = _catalog.repository as HongguoDramaRepository;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '来源 · 红果 App 快速',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: .4,
                color: palette.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        LiquidSegmentedControl<String>(
          semanticLabel: '内容类型',
          value: repository.contentType,
          segments: [
            for (final item in HongguoDramaRepository.contentTypes.entries)
              LiquidSegment(value: item.key, label: item.value),
          ],
          onChanged: (value) {
            repository.contentType = value;
            repository.genre = '';
            _catalog.load();
          },
        ),
      ],
    );
  }

  /// Resume cards from other sources cannot be played by the active repository,
  /// so the home rail only shows entries that belong to the current source.
  List<ResumeEntry> get _visibleResumeEntries {
    final repository = _catalog.repository;
    final source = repository is HongguoDramaRepository
        ? '红果'
        : repository is DemoDramaRepository
        ? '演示'
        : null;
    final entries = _library.resumeEntries;
    if (source == null) return entries;
    return entries.where((entry) => entry.drama.sourceName == source).toList();
  }

  void _select(int tab) {
    FocusScope.of(context).unfocus();
    if (tab == 0 && _tab == 0 && _showTop) {
      _topSignal.value++;
      return;
    }
    setState(() => _tab = tab);
  }

  void _about() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Transparent sheet so the surface can repaint when the mode changes while
    // the sheet is still open; the handle is drawn inside our own container.
    backgroundColor: Colors.transparent,
    builder: (context) => _AboutSheet(
      themeMode: widget.themeMode,
      onThemeMode: widget.onThemeMode,
      onReplayStartup: widget.onReplayStartup,
      onSettings: () {
        Navigator.pop(context);
        _select(3);
      },
    ),
  );
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: palette.canvas,
        systemNavigationBarIconBrightness: palette.isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: SoftBackground(
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(23, 9, 17, 4),
                      child: Row(
                        children: [
                          const BrandMark(size: 23),
                          const SizedBox(width: 9),
                          Text(
                            'ZOVV',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'STORIES',
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 1.5,
                              color: palette.muted,
                            ),
                          ),
                          const Spacer(),
                          GlassSurface(
                            radius: 11,
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                tooltip: '关于 ZOVV',
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                color: palette.ink,
                                onPressed: _about,
                                icon: const Icon(Icons.more_horiz_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_catalog, _library]),
                        builder: (context, _) {
                          return Stack(
                            children: [
                              IndexedStack(
                                index: _tab,
                                children: [
                                  DiscoverScreen(
                                    scrollToTop: _topSignal,
                                    onScrollState: (value) {
                                      if (mounted && _showTop != value) {
                                        setState(() => _showTop = value);
                                      }
                                    },
                                    loading: _catalog.loading,
                                    catalogError: _catalog.error,
                                    onRetry: _catalog.load,
                                    onRefresh: _catalog.load,
                                    onLoadMore: _catalog.loadMore,
                                    hasMore: _catalog.hasMore,
                                    loadingMore: _catalog.loadingMore,
                                    moreError: _catalog.moreError,
                                    sourceControls:
                                        _catalog.repository
                                            is HongguoDramaRepository
                                        ? _hongguoControls()
                                        : null,
                                    remoteGenres:
                                        _catalog.repository
                                            is HongguoDramaRepository
                                        ? (_catalog.repository
                                                  as HongguoDramaRepository)
                                              .genres
                                        : null,
                                    selectedGenre:
                                        _catalog.repository
                                            is HongguoDramaRepository
                                        ? (_catalog.repository
                                                  as HongguoDramaRepository)
                                              .genre
                                        : '',
                                    onGenre: (genre) {
                                      final repository = _catalog.repository;
                                      if (repository
                                          is HongguoDramaRepository) {
                                        repository.genre = genre;
                                        _catalog.load();
                                      }
                                    },
                                    dramas: _catalog.dramas,
                                    onOpen: _open,
                                    onSearch: () => _select(1),
                                    resumeEntries: _visibleResumeEntries,
                                    onResume: _resume,
                                    busyId: _resumingId,
                                  ),
                                  DramaSearchScreen(
                                    onRefreshCatalog: _catalog.load,
                                    repository: _catalog.repository,
                                    dramas: _catalog.dramas,
                                    onOpen: _open,
                                  ),
                                  DramaLibraryScreen(
                                    sourceFilter:
                                        _catalog.repository
                                            is HongguoDramaRepository
                                        ? '红果'
                                        : null,
                                    dramas: _catalog.dramas,
                                    library: _library,
                                    onOpen: _open,
                                    onResume: _resume,
                                    onExplore: () => _select(0),
                                  ),
                                  MyScreen(
                                    library: _library,
                                    onResume: _resume,
                                    themeMode: widget.themeMode,
                                    onThemeMode: widget.onThemeMode,
                                    onReplay: widget.onReplayStartup,
                                    active: _tab == 3,
                                  ),
                                ],
                              ),
                              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                                Positioned(
                                  left: 30,
                                  right: 30,
                                  bottom: 17,
                                  child: SafeArea(
                                    top: false,
                                    child: GlassNavigation(
                                      showTop: _tab == 0 && _showTop,
                                      index: _tab,
                                      onChanged: _select,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (_resumingId != null)
                const Positioned.fill(
                  key: Key('resume-preparing'),
                  child: _PreparingOverlay(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blocks the shell while a remote source resolves the resumed episode.
class _PreparingOverlay extends StatelessWidget {
  const _PreparingOverlay();
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.canvas.withValues(alpha: .58),
      child: Center(
        child: GlassSurface(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZovvLoader(size: 18),
              SizedBox(width: 12),
              Text('正在准备这一集…', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact information sheet; persistent preferences live in My.
class _AboutSheet extends StatelessWidget {
  const _AboutSheet({
    required this.themeMode,
    required this.onThemeMode,
    required this.onReplayStartup,
    required this.onSettings,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeMode;
  final VoidCallback onReplayStartup, onSettings;
  @override
  Widget build(BuildContext context) => GlassSurface(
    radius: 26,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '关于 ZOVV',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: context.palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '好故事，慢慢看。',
              style: TextStyle(fontSize: 13, color: context.palette.muted),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded),
              title: const Text('偏好与缓存管理'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onSettings,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('重播开屏演示'),
              onTap: () {
                Navigator.pop(context);
                onReplayStartup();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
