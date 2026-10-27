import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../player/application/playback_preferences.dart';
import '../../player/data/android_video_cache.dart';
import '../../player/presentation/widgets/video_cache_tile.dart';
import '../application/drama_library_controller.dart';
import '../domain/drama.dart';
import 'widgets/drama_poster.dart';

class MyScreen extends StatefulWidget {
  const MyScreen({
    super.key,
    required this.library,
    required this.onResume,
    required this.themeMode,
    required this.onThemeMode,
    required this.onReplay,
    required this.active,
  });
  final DramaLibraryController library;
  final ValueChanged<Drama> onResume;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode>? onThemeMode;
  final VoidCallback onReplay;
  final bool active;
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _preferences = PlaybackPreferences();
  String _version = 'ZOVV';
  VideoCacheSnapshot? _cache;
  @override
  void initState() {
    super.initState();
    _load();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() => _version = '${info.version} (${info.buildNumber})');
          }
        })
        .catchError((Object _) {});
  }

  @override
  void didUpdateWidget(covariant MyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load();
  }

  Future<void> _load() async {
    await _preferences.load();
    _cache = await AndroidVideoCache.read();
    if (mounted) setState(() {});
  }

  Future<void> _save({
    double? speed,
    bool? autoNext,
    String? quality,
    bool? danmaku,
  }) async {
    try {
      await _preferences.save(
        speed: speed,
        autoNext: autoNext,
        quality: quality,
        danmaku: danmaku,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('设置保存失败，请重试')));
      }
    }
    if (mounted) setState(() {});
  }

  Widget _group(String title, List<Widget> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.palette.muted,
              letterSpacing: .6,
            ),
          ),
        ),
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index < rows.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Divider(
                height: 1,
                thickness: .5,
                color: context.palette.line,
              ),
            ),
        ],
      ],
    ),
  );
  Widget _row(
    IconData icon,
    String title, {
    String? value,
    VoidCallback? onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 19, color: context.palette.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: context.palette.ink),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: context.palette.muted,
              ),
            ],
          ],
        ),
      ),
    ),
  );
  Future<void> _choose<T>(
    String title,
    Map<T, String> values,
    T selected,
    Future<void> Function(T) save,
  ) async {
    final value = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => GlassSurface(
        radius: 24,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in values.entries)
                    InkWell(
                      onTap: () => Navigator.pop(sheetContext, item.key),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.value,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (item.key == selected)
                              Icon(
                                Icons.check_rounded,
                                size: 19,
                                color: context.palette.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (value != null) await save(value);
  }

  Future<void> _storage() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GlassSurface(
        radius: 24,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '视频缓存',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.palette.ink,
                    ),
                  ),
                  const VideoCacheTile(),
                  Text(
                    _cache == null
                        ? '缓存服务暂不可用，正常播放不受影响。'
                        : '退出播放后可以清理。收藏与观看记录会保留。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _cache = await AndroidVideoCache.read();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListView(
      key: const PageStorageKey('my'),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 130),
      children: [
        Text(
          '我的',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '观看、偏好与这台设备。',
          style: TextStyle(fontSize: 12, color: context.palette.muted),
        ),
        const SizedBox(height: 30),
        _group('我的故事', [
          _row(
            Icons.history_rounded,
            '观看记录',
            value: '${widget.library.resumeEntries.length} 部',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _HistoryPage(
                  library: widget.library,
                  onResume: widget.onResume,
                ),
              ),
            ),
          ),
        ]),
        _group('播放偏好', [
          _row(
            Icons.playlist_play_rounded,
            '自动连播',
            value: _preferences.autoNext ? '已开启' : '已关闭',
            onTap: () => _save(autoNext: !_preferences.autoNext),
          ),
          _row(
            Icons.speed_rounded,
            '默认倍速',
            value: '${_preferences.speed}×',
            onTap: () => _choose<double>(
              '默认倍速',
              {
                for (final speed in PlaybackPreferences.speeds)
                  speed: '$speed×',
              },
              _preferences.speed,
              (v) => _save(speed: v),
            ),
          ),
          _row(
            Icons.high_quality_outlined,
            '默认清晰度',
            value: _preferences.quality == 'auto'
                ? '自动'
                : _preferences.quality.toUpperCase(),
            onTap: () => _choose<String>(
              '默认清晰度',
              {'auto': '自动', '720p': '720P', '1080p': '1080P'},
              _preferences.quality,
              (v) => _save(quality: v),
            ),
          ),
          _row(
            Icons.chat_bubble_outline_rounded,
            '显示弹幕',
            value: _preferences.danmaku ? '已开启' : '已关闭',
            onTap: () => _save(danmaku: !_preferences.danmaku),
          ),
        ]),
        _group('设备与外观', [
          _row(
            Icons.palette_outlined,
            '外观',
            value: {
              ThemeMode.system: '跟随系统',
              ThemeMode.light: '浅色',
              ThemeMode.dark: '夜间',
            }[widget.themeMode],
            onTap: () => _choose<ThemeMode>(
              '外观',
              {
                ThemeMode.system: '跟随系统',
                ThemeMode.light: '浅色',
                ThemeMode.dark: '夜间',
              },
              widget.themeMode,
              (v) async {
                widget.onThemeMode?.call(v);
              },
            ),
          ),
          _row(
            Icons.cleaning_services_outlined,
            '视频缓存',
            value: _cache == null
                ? '查看与清理'
                : '${(_cache!.bytes / 1048576).toStringAsFixed(1)} MB',
            onTap: _storage,
          ),
        ]),
        _group('关于 ZOVV', [
          _row(Icons.auto_awesome_outlined, '重播开屏演示', onTap: widget.onReplay),
          _row(Icons.info_outline_rounded, '版本', value: _version),
        ]),
      ],
    ),
  );
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.library, required this.onResume});
  final DramaLibraryController library;
  final ValueChanged<Drama> onResume;
  Future<void> _clear(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空观看记录？'),
        content: const Text('收藏和视频缓存会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (yes == true) library.clearHistory();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.canvas,
    appBar: AppBar(
      title: const Text('观看记录'),
      actions: [
        TextButton(onPressed: () => _clear(context), child: const Text('清空')),
      ],
    ),
    body: AnimatedBuilder(
      animation: library,
      builder: (context, _) {
        final entries = library.resumeEntries;
        if (entries.isEmpty) return const Center(child: Text('还没有观看记录'));
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 48,
                height: 64,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DramaPoster(drama: entry.drama, showTitle: false),
                ),
              ),
              title: Text(
                entry.drama.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(entry.caption),
              trailing: IconButton(
                tooltip: '删除这条记录',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => library.removeHistory(entry.drama.id),
              ),
              onTap: () => onResume(entry.drama),
            );
          },
        );
      },
    ),
  );
}
