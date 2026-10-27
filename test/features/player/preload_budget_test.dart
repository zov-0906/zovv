import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:zovv/features/player/application/preload_budget.dart';

void main() {
  VideoPlayerValue sample(List<DurationRange> ranges) => VideoPlayerValue(
    duration: const Duration(seconds: 60),
    position: const Duration(seconds: 20),
    isPlaying: true,
    buffered: ranges,
  );
  test('future disconnected buffer cannot authorize competing preload', () {
    final value = sample([
      DurationRange(const Duration(seconds: 20), const Duration(seconds: 22)),
      DurationRange(const Duration(seconds: 40), const Duration(seconds: 60)),
    ]);
    expect(bufferedAhead(value), const Duration(seconds: 2));
    expect(canWarmNext(value), isFalse);
  });
  test('sufficient current buffer authorizes next; buffering revokes it', () {
    final value = sample([
      DurationRange(Duration.zero, const Duration(seconds: 32)),
    ]);
    expect(canWarmNext(value), isTrue);
    expect(canWarmNext(value.copyWith(isBuffering: true)), isFalse);
  });
}
