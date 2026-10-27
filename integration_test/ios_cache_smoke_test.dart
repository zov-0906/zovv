import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/data/ios_video_cache.dart';

import 'support/hls_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('AVPlayer plays cached HLS and cache survives proxy restart', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final path = await const MethodChannel('zovv/ios-cache')
          .invokeMethod<String>('directory');
      expect(path, isNotNull);
      final folder = Directory('$path/smoke');
      if (await folder.exists()) await folder.delete(recursive: true);
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final hits = <String, int>{};
      upstream.listen((request) async {
        final name = request.uri.pathSegments.last;
        final fixture = hlsFixture[name];
        if (fixture == null) {
          request.response.statusCode = 404;
        } else {
          hits.update(name, (count) => count + 1, ifAbsent: () => 1);
          request.response.add(base64Decode(fixture));
        }
        await request.response.close();
      });
      final origin = Uri.parse('http://127.0.0.1:${upstream.port}');
      var service = await IosVideoCache.start(folder, origin: origin);
      final source = PlaybackSource(
        uri: origin.resolve('/stream/${'a' * 48}/index.m3u8'),
        attribution: 'synthetic',
        headers: {'X-Zovv-Cache-Key': 'synthetic:version1'},
      );
      Future<void> play() async {
        final player = service.create(source);
        try {
          await player.initialize().timeout(const Duration(seconds: 30));
          await player.play();
          final deadline = DateTime.now().add(const Duration(seconds: 15));
          while (player.value.position.inMilliseconds < 500 &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          expect(player.value.hasError, isFalse);
          expect(
            player.value.position.inMilliseconds,
            greaterThanOrEqualTo(500),
          );
          expect((await service.stats())['bytes'] as int, greaterThan(0));
          expect((await service.stats(clear: true))['busy'], isTrue);
        } finally {
          await player.dispose();
        }
      }

      try {
        await play();
        final firstInit = hits['init.mp4'];
        final firstSegment = hits['segment-00000.m4s'];
        expect(firstInit, 1);
        expect(firstSegment, 1);
        await service.close();
        service = await IosVideoCache.start(folder, origin: origin);
        await play();
        expect(hits['init.mp4'], firstInit);
        expect(hits['segment-00000.m4s'], firstSegment);
        expect(hits['index.m3u8'], greaterThanOrEqualTo(2));
        expect((await service.stats(clear: true))['cleared'], isTrue);
        expect((await service.stats())['bytes'], 0);
      } finally {
        await service.close();
        await upstream.close(force: true);
        if (await folder.exists()) await folder.delete(recursive: true);
      }
    });
  });
}
