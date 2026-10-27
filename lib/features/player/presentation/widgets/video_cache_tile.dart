import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/android_video_cache.dart';

class VideoCacheTile extends StatefulWidget {
  const VideoCacheTile({super.key});
  @override
  State<VideoCacheTile> createState() => _VideoCacheTileState();
}

class _VideoCacheTileState extends State<VideoCacheTile> {
  VideoCacheSnapshot? _snapshot;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final value = await AndroidVideoCache.read();
    if (mounted) setState(() => _snapshot = value);
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    final value = await AndroidVideoCache.read(clear: true);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (value != null) _snapshot = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value?.cleared == true
              ? '视频缓存已清理'
              : value?.busy == true
              ? '请在退出播放后清理缓存'
              : '暂时无法清理缓存，请重试',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) return const SizedBox.shrink();
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.cleaning_services_outlined, size: 20, color: palette.ink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '视频缓存',
                  style: TextStyle(color: palette.ink, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(snapshot.bytes / 1048576).toStringAsFixed(1)} MB / ${(snapshot.limit / 1048576).round()} MB',
                  style: TextStyle(color: palette.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _clear,
            child: Text(_busy ? '清理中…' : '清理'),
          ),
        ],
      ),
    );
  }
}
