import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../drama/domain/danmaku.dart';
import '../../application/danmaku_layout.dart';

class DanmakuOverlay extends StatefulWidget {
  const DanmakuOverlay({
    super.key,
    required this.player,
    required this.source,
    required this.dramaId,
    required this.episodeId,
  });
  final VideoPlayerController player;
  final EpisodeDanmakuSource source;
  final String dramaId, episodeId;
  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final _windows = <int, DanmakuWindow>{};
  final _pending = <int>{};
  final _renderer = _DanmakuRenderer();
  DateTime _anchor = DateTime.now();
  Duration _position = Duration.zero;
  bool _reduce = false;
  @override
  void initState() {
    super.initState();
    widget.player.addListener(_sync);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant DanmakuOverlay old) {
    super.didUpdateWidget(old);
    if (old.player != widget.player) {
      old.player.removeListener(_sync);
      widget.player.addListener(_sync);
      _sync();
    }
  }

  double _time() {
    final value = widget.player.value;
    final advance = value.isPlaying && !value.isBuffering
        ? DateTime.now().difference(_anchor).inMicroseconds /
              1000000 *
              value.playbackSpeed
        : 0.0;
    return _position.inMicroseconds / 1000000 +
        advance.clamp(0, 0.5 * value.playbackSpeed);
  }

  void _sync() {
    if (!mounted) return;
    final value = widget.player.value;
    _anchor = DateTime.now();
    _position = value.position;
    if (value.duration > Duration.zero) {
      final bucket = value.position.inMilliseconds ~/ 30000 * 30000;
      _load(bucket);
      if (value.position.inMilliseconds >= bucket + 25000) {
        _load(bucket + 30000);
      }
    }
    final animate =
        !_reduce &&
        value.isPlaying &&
        !value.isBuffering &&
        _renderer.items.isNotEmpty;
    if (animate && !_motion.isAnimating) _motion.repeat();
    if (!animate && _motion.isAnimating) _motion.stop();
  }

  Future<void> _load(int start) async {
    final duration = widget.player.value.duration;
    if (start >= duration.inMilliseconds ||
        _windows.containsKey(start) ||
        _pending.contains(start) ||
        _pending.length >= 2) {
      return;
    }
    _pending.add(start);
    DanmakuWindow result;
    try {
      result = await widget.source.fetchDanmakuWindow(
        widget.dramaId,
        widget.episodeId,
        start: Duration(milliseconds: start),
        duration: duration,
      );
    } catch (_) {
      result = const DanmakuWindow(available: false, notice: '弹幕暂不可用，不影响播放');
    }
    if (!mounted) return;
    _pending.remove(start);
    final current =
        widget.player.value.position.inMilliseconds ~/ 30000 * 30000;
    if ((start - current).abs() <= 30000) _windows[start] = result;
    _windows.removeWhere((key, _) => (key - current).abs() > 30000);
    _renderer.update(_windows.values.expand((window) => window.items).toList());
    setState(() {});
    _sync();
  }

  @override
  void dispose() {
    widget.player.removeListener(_sync);
    _motion.dispose();
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bucket = widget.player.value.position.inMilliseconds ~/ 30000 * 30000;
    final notice = _windows[bucket]?.notice ?? '';
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DanmakuPainter(
                  renderer: _renderer,
                  revision: _renderer.revision,
                  clock: _time,
                  videoSize: widget.player.value.size,
                  reduce: _reduce,
                  fontSize: MediaQuery.textScalerOf(context)
                      .scale(13)
                      .clamp(13, 17)
                      .toDouble(),
                  repaint: Listenable.merge([_motion, widget.player]),
                ),
              ),
            ),
          ),
          if (notice.isNotEmpty)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Text(
                notice,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _DanmakuRenderer {
  List<DanmakuItem> items = const [];
  int revision = 0;
  final texts = <String, TextPainter>{};
  List<DanmakuFlight> flights = const [];
  Size? _size;
  double? _font;
  void update(List<DanmakuItem> value) {
    items = value;
    revision++;
    _size = null;
  }

  void layout(Size size, double font) {
    if (_size == size && _font == font) return;
    for (final text in texts.values) {
      text.dispose();
    }
    texts.clear();
    _size = size;
    _font = font;
    double measure(String value) {
      final text = texts.putIfAbsent(
        value,
        () => TextPainter(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .8),
              fontSize: font,
              fontWeight: FontWeight.w500,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: size.width * .7),
      );
      return text.width;
    }

    flights = layoutDanmaku(items, measure);
  }

  void dispose() {
    for (final text in texts.values) {
      text.dispose();
    }
    texts.clear();
  }
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter({
    required this.renderer,
    required this.revision,
    required this.clock,
    required this.videoSize,
    required this.reduce,
    required this.fontSize,
    required super.repaint,
  });
  final _DanmakuRenderer renderer;
  final int revision;
  final double Function() clock;
  final Size videoSize;
  final bool reduce;
  final double fontSize;
  @override
  void paint(Canvas canvas, Size size) {
    if (videoSize.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.contain, videoSize, size).destination;
    final rect = Alignment.center.inscribe(fitted, Offset.zero & size);
    renderer.layout(fitted, fontSize);
    final now = clock(), height = fontSize + 8;
    canvas.save();
    canvas.clipRect(rect);
    var visible = 0;
    for (final flight in renderer.flights) {
      final elapsed = now - flight.item.time.inMicroseconds / 1000000;
      final x = rect.width - elapsed * 90;
      if (elapsed < 0 || x + flight.width < 0) continue;
      if (reduce && elapsed > 3) continue;
      if (visible >= 8) break;
      final text = renderer.texts[flight.item.text]!;
      final y = rect.top + 8 + flight.lane * height;
      if (y + height > rect.top + rect.height * .4) continue;
      text.paint(
        canvas,
        Offset(
          reduce ? rect.left + (rect.width - flight.width) / 2 : rect.left + x,
          y,
        ),
      );
      visible++;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter old) =>
      old.revision != revision ||
      old.videoSize != videoSize ||
      old.reduce != reduce ||
      old.fontSize != fontSize;
}
