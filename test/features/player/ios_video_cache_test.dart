import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/data/ios_video_cache.dart';

void main() {
  test(
    'loopback proxy refreshes playlists, caches media and serves byte ranges',
    () async {
      final folder = await Directory.systemTemp.createTemp('zovv-proxy-');
      final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var manifests = 0, media = 0;
      upstream.listen((request) async {
        expect(request.headers.value('Authorization'), 'Bearer test');
        if (request.uri.path.endsWith('index.m3u8')) {
          manifests++;
          request.response.write('#EXTM3U\n#EXTINF:2,\nsegment-00000.m4s\n');
        } else {
          media++;
          request.response.add(List.generate(16, (i) => i));
        }
        await request.response.close();
      });
      final origin = Uri.parse('http://127.0.0.1:${upstream.port}');
      final service = await IosVideoCache.start(folder, origin: origin);
      final player = service.create(
        PlaybackSource(
          uri: origin.resolve('/stream/${'a' * 48}/index.m3u8'),
          attribution: 'test',
          headers: {
            'X-Zovv-Cache-Key': 'episode:quality:version',
            'Authorization': 'Bearer test',
          },
        ),
      );
      final uri = Uri.parse(player.dataSource);
      final client = HttpClient();
      Future<List<int>> get(
        Uri target, {
        String? range,
        int status = 200,
      }) async {
        final request = await client.getUrl(target);
        if (range != null) request.headers.set('Range', range);
        final response = await request.close();
        expect(response.statusCode, status);
        return response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
      }

      try {
        expect(utf8.decode(await get(uri)), contains('#EXTM3U'));
        await get(uri);
        expect(manifests, 2);
        final asset = uri.resolve('segment-00000.m4s');
        await get(asset);
        expect(await get(asset, range: 'bytes=4-7', status: 206), [4, 5, 6, 7]);
        expect(media, 1);
        await get(asset, range: 'bytes=99-', status: 416);
        expect((await service.stats(clear: true))['busy'], isTrue);
        expect((await service.stats())['bytes'], 16);
        await get(uri.resolve('../unknown/index.m3u8'), status: 404);
      } finally {
        await player.dispose();
        expect((await service.stats(clear: true))['cleared'], isTrue);
        client.close(force: true);
        await service.close();
        await upstream.close(force: true);
        await folder.delete(recursive: true);
      }
    },
  );
}
