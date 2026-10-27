import 'package:video_player/video_player.dart';

/// Only count the buffered range containing the current playhead.
Duration bufferedAhead(VideoPlayerValue value) {
  for (final range in value.buffered) {
    if (range.start <= value.position && range.end > value.position) {
      return range.end - value.position;
    }
  }
  return Duration.zero;
}

bool canWarmNext(VideoPlayerValue value) =>
    value.isPlaying &&
    !value.isBuffering &&
    (bufferedAhead(value) >= const Duration(seconds: 10) ||
        (value.duration > Duration.zero &&
            value.buffered.any(
              (range) =>
                  range.start <= value.position && range.end >= value.duration,
            )));
