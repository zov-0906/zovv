import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/drama/presentation/drama_shell.dart';
import '../features/drama/domain/drama.dart';
import '../features/drama/domain/watch_progress.dart';
import '../features/startup/data/startup_history.dart';
import '../features/startup/domain/startup_config.dart';
import '../features/startup/presentation/startup_screen.dart';

/// Composition root. Features communicate through callbacks, not global state.
class ZovvApp extends StatefulWidget {
  const ZovvApp({
    super.key,
    required this.history,
    required this.hasCompletedStartup,
    this.dramaRepository,
    this.libraryStorage,
    this.themeController,
  });
  final StartupHistory history;
  final bool hasCompletedStartup;
  final DramaRepository? dramaRepository;
  final LibraryStorage? libraryStorage;
  final ThemeController? themeController;
  @override
  State<ZovvApp> createState() => _ZovvAppState();
}

class _ZovvAppState extends State<ZovvApp> {
  bool _showStartup = true;
  final _startupReady = ValueNotifier(false);
  late bool _fullSequence = !widget.hasCompletedStartup;
  int _playback = 0;
  late final ThemeController _theme =
      widget.themeController ?? ThemeController();
  void _complete() {
    if (!_showStartup) return;
    setState(() => _showStartup = false);
    unawaited(widget.history.markCompleted());
  }

  void _replay() => setState(() {
    _fullSequence = true;
    _showStartup = true;
    _playback++;
  });

  @override
  void dispose() {
    _startupReady.dispose();
    if (widget.themeController == null) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _theme,
    builder: (context, _) => MaterialApp(
      title: 'ZOVV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _theme.mode,
      home: Stack(
        children: [
          ExcludeSemantics(
            excluding: _showStartup,
            child: DramaShell(
              onPrepared: () => _startupReady.value = true,
              onReplayStartup: _replay,
              repository: widget.dramaRepository,
              storage: widget.libraryStorage,
              themeMode: _theme.mode,
              onThemeMode: _theme.setMode,
            ),
          ),
          if (_showStartup)
            StartupScreen(
              ready: _startupReady,
              key: ValueKey(_playback),
              config: StartupConfig(fullSequence: _fullSequence),
              onComplete: _complete,
            ),
        ],
      ),
    ),
  );
}
