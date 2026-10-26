import 'package:flutter/material.dart';

/// Hand-drawn playback scrubber: a hairline track, a white fill and a small
/// knob with a soft accent halo. Replaces the Material [Slider] so playback
/// controls share the app's flat language.
class PlaybackScrubber extends StatelessWidget {
  const PlaybackScrubber({
    super.key,
    required this.position,
    required this.duration,
    this.onSeekStart,
    this.onSeek,
    this.onSeekEnd,
    this.trackColor = const Color(0x33FFFFFF),
    this.fillColor = Colors.white,
    this.accent = const Color(0xFF7C93E4),
  });
  final Duration position;
  final Duration duration;
  final VoidCallback? onSeekStart;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onSeekEnd;
  final Color trackColor;
  final Color fillColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
    final progress = (position.inMilliseconds / total).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(Offset local) {
          final ratio = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek?.call(Duration(milliseconds: (ratio * total).round()));
        }

        return Semantics(
          slider: true,
          value: '${position.inSeconds}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              onSeekStart?.call();
              seekTo(details.localPosition);
              onSeekEnd?.call();
            },
            onHorizontalDragStart: (details) {
              onSeekStart?.call();
              seekTo(details.localPosition);
            },
            onHorizontalDragUpdate: (details) => seekTo(details.localPosition),
            onHorizontalDragEnd: (_) => onSeekEnd?.call(),
            onHorizontalDragCancel: () => onSeekEnd?.call(),
            child: SizedBox(
              height: 22,
              child: CustomPaint(
                painter: _ScrubberPainter(
                  progress: progress,
                  trackColor: trackColor,
                  fillColor: fillColor,
                  accent: accent,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  _ScrubberPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.accent,
  });
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    const trackHeight = 3.0;
    final centerY = size.height / 2;
    final radius = Radius.circular(trackHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, centerY - trackHeight / 2, size.width, trackHeight),
        radius,
      ),
      Paint()..color = trackColor,
    );
    final filled = size.width * progress;
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, centerY - trackHeight / 2, filled, trackHeight),
          radius,
        ),
        Paint()..color = fillColor,
      );
    }
    final knob = Offset(filled.clamp(5.0, size.width - 5.0), centerY);
    canvas.drawCircle(knob, 7, Paint()..color = accent.withValues(alpha: .35));
    canvas.drawCircle(knob, 4.5, Paint()..color = fillColor);
  }

  @override
  bool shouldRepaint(_ScrubberPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor;
}
