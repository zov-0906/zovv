import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_chip.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/liquid_segmented_control.dart';
import '../../player/application/playback_preferences.dart';
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

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        GlassSurface(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: ListView(
      key: const PageStorageKey('my'),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 130),
      children: [
        Text(
          '我的',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '故事与偏好，留在这台设备。',
          style: TextStyle(fontSize: 12, color: context.palette.muted),
        ),
        const SizedBox(height: 24),
        _section('观看记录', [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_rounded),
            title: const Text('全部观看记录'),
            subtitle: Text('${widget.library.resumeEntries.length} 部故事'),
            trailing: const Icon(Icons.chevron_right_rounded),
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
        _section('播放偏好', [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动连播'),
            value: _preferences.autoNext,
            onChanged: (v) => _save(autoNext: v),
          ),
          const Text('默认倍速', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final speed in PlaybackPreferences.speeds)
                GlassChip(
                  label: '$speed×',
                  selected: _preferences.speed == speed,
                  onTap: () => _save(speed: speed),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('默认清晰度', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in {
                'auto': '自动',
                '720p': '720P',
                '1080p': '1080P',
              }.entries)
                GlassChip(
                  label: item.value,
                  selected: _preferences.quality == item.key,
                  onTap: () => _save(quality: item.key),
                ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('显示弹幕'),
            value: _preferences.danmaku,
            onChanged: (v) => _save(danmaku: v),
          ),
        ]),
        _section('外观', [
          LiquidSegmentedControl<ThemeMode>(
            semanticLabel: '外观模式',
            value: widget.themeMode,
            height: 42,
            segments: const [
              LiquidSegment(value: ThemeMode.system, label: '跟随系统'),
              LiquidSegment(value: ThemeMode.light, label: '浅色'),
              LiquidSegment(value: ThemeMode.dark, label: '夜间'),
            ],
            onChanged: (mode) => widget.onThemeMode?.call(mode),
          ),
        ]),
        _section('存储管理', [
          VideoCacheTile(key: ValueKey(widget.active)),
          Text(
            '清理视频缓存不会删除收藏与观看记录。',
            style: TextStyle(fontSize: 11, color: context.palette.muted),
          ),
        ]),
        _section('关于 ZOVV', [
          Text(
            _version,
            style: TextStyle(fontSize: 12, color: context.palette.muted),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('重播开屏演示'),
            leading: const Icon(Icons.auto_awesome_outlined),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.onReplay,
          ),
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
