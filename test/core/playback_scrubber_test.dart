import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/core/widgets/playback_scrubber.dart';

void main() {
  testWidgets(
    'tap commits once; drag never commits a premature tap before release',
    (tester) async {
      var starts = 0, ends = 0;
      Duration? target;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: PlaybackScrubber(
                  position: Duration.zero,
                  duration: const Duration(seconds: 60),
                  onSeekStart: () => starts++,
                  onSeek: (value) => target = value,
                  onSeekEnd: () => ends++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PlaybackScrubber));
      expect(starts, 1);
      expect(ends, 1);
      expect(target, const Duration(seconds: 30));
      starts = 0;
      ends = 0;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PlaybackScrubber)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(starts, 1);
      expect(ends, 0);
      await gesture.up();
      await tester.pump();
      expect(ends, 1);
      expect(target!.inSeconds, greaterThan(30));
    },
  );
}
