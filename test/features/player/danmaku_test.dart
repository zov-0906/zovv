import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/domain/danmaku.dart';
import 'package:zovv/features/player/application/danmaku_layout.dart';
import 'package:zovv/features/player/presentation/widgets/danmaku_overlay.dart';

import 'next_episode_buffer_test.dart' show FakePlayer;

class WindowSource implements EpisodeDanmakuSource {
  final requests = <int>[];
  bool available = true;
  @override
  Future<DanmakuWindow> fetchDanmakuWindow(
    String dramaId,
    String episodeId, {
    required Duration start,
    required Duration duration,
  }) async {
    requests.add(start.inSeconds);
    return DanmakuWindow(
      available: available,
      notice: available ? '' : '弹幕暂不可用，不影响播放',
      items: available
          ? [
              DanmakuItem(
                time: start + const Duration(seconds: 1),
                text: 'hello',
              ),
            ]
          : [],
    );
  }
}

void main() {
  test('bounded lanes drop dense comments until the previous tail clears', () {
    final items = [0, 0, 0, 0, 1000, 1300]
        .map(
          (ms) => DanmakuItem(
            time: Duration(milliseconds: ms),
            text: 'hello',
          ),
        )
        .toList();
    final plan = layoutDanmaku(items, (_) => 90);
    expect(plan.length, 4);
    expect(plan.take(3).map((flight) => flight.lane).toList(), [0, 1, 2]);
    expect(plan.last.item.time, const Duration(milliseconds: 1300));
    expect(plan.last.lane, 0);
    expect(DanmakuItem.fromJson({'timeMs': -1, 'text': 'bad'}), isNull);
    expect(
      DanmakuItem.fromJson({'timeMs': 1, 'text': 'x' * 200})!.text.length,
      120,
    );
  });
  testWidgets(
    'paused video fetches only current and imminent windows, failure stays non-blocking',
    (tester) async {
      final player = FakePlayer();
      await player.initialize();
      final source = WindowSource();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              height: 220,
              child: DanmakuOverlay(
                player: player,
                source: source,
                dramaId: '1',
                episodeId: '2',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(source.requests, [0]);
      await player.seekTo(const Duration(seconds: 27));
      await tester.pumpAndSettle();
      expect(source.requests, [0, 30]);
      await player.seekTo(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(source.requests, [0, 30]);
      expect(player.value.isPlaying, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await player.dispose();
      final failedPlayer = FakePlayer();
      await failedPlayer.initialize();
      final failed = WindowSource()..available = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DanmakuOverlay(
              player: failedPlayer,
              source: failed,
              dramaId: '1',
              episodeId: '2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('弹幕暂不可用，不影响播放'), findsOneWidget);
      expect(failedPlayer.value.hasError, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await failedPlayer.dispose();
    },
  );
}
