import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/player/data/android_video_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('zovv/video-cache');
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  for (final becomesIdle in [true, false]) {
    testWidgets('cache clear bounded wait, becomes idle=$becomesIdle', (
      tester,
    ) async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            calls++;
            final busy = !becomesIdle || calls < 3;
            return {
              'available': true,
              'bytes': busy ? 100 : 0,
              'limit': 150,
              'busy': busy,
              'cleared': !busy,
            };
          });
      final pending = AndroidVideoCache.read(clear: true);
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      final result = await pending;
      expect(result?.cleared, becomesIdle);
      expect(calls, becomesIdle ? 3 : 7);
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
