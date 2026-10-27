import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/player/data/hls_disk_cache.dart';

void main() {
  late Directory folder;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('zovv-cache-');
  });
  tearDown(() async {
    await folder.delete(recursive: true);
  });
  test('restart reuses bytes while identity and asset isolate media', () async {
    final cache = HlsDiskCache(folder);
    await cache.initialize();
    var downloads = 0;
    Future<Uint8List> download() async => Uint8List.fromList([++downloads]);
    await cache.load('episode1:quality:version', 'init.mp4', download);
    final restarted = HlsDiskCache(folder);
    await restarted.initialize();
    expect(
      await restarted.load('episode1:quality:version', 'init.mp4', download),
      [1],
    );
    expect(
      await restarted.load('episode2:quality:version', 'init.mp4', download),
      [2],
    );
    expect(
      await restarted.load(
        'episode1:quality:version',
        'segment-00001.m4s',
        download,
      ),
      [3],
    );
    expect(downloads, 3);
  });
  test(
    'concurrent reads coalesce; failed downloads are never cached',
    () async {
      final cache = HlsDiskCache(folder);
      await cache.initialize();
      final pending = Completer<Uint8List>();
      var calls = 0;
      Future<Uint8List> load() => cache.load('one', 'init.mp4', () {
        calls++;
        return pending.future;
      });
      final first = load(), second = load();
      pending.complete(Uint8List.fromList([1, 2]));
      await Future.wait([first, second]);
      expect(calls, 1);
      await expectLater(
        cache.load('two', 'init.mp4', () async {
          throw const HttpException('failed');
        }),
        throwsA(isA<HttpException>()),
      );
      expect(await cache.bytes(), 2);
    },
  );
  test(
    'LRU enforces disk budget and refuses clearing active playback',
    () async {
      final cache = HlsDiskCache(folder, limit: 6);
      await cache.initialize();
      Future<Uint8List> body() async => Uint8List(4);
      await cache.load('one', 'init.mp4', body);
      await cache.load('two', 'init.mp4', body);
      expect(await cache.bytes(), 4);
      var miss = false;
      await cache.load('one', 'init.mp4', () async {
        miss = true;
        return Uint8List(4);
      });
      expect(miss, isTrue);
      cache.active = 1;
      expect(await cache.clear(), isFalse);
      cache.active = 0;
      expect(await cache.clear(), isTrue);
      expect(await cache.bytes(), 0);
    },
  );
}
