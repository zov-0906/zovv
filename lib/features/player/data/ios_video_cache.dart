import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/config/zovv_gateway.dart';
import '../../drama/domain/drama.dart';
import 'hls_disk_cache.dart';

class IosVideoCache {
  IosVideoCache._(this._disk, this._server, this._origin);
  static IosVideoCache? instance;
  final HlsDiskCache _disk;
  final HttpServer _server;
  final Uri _origin;
  bool _sameOrigin(Uri uri) =>
      uri.scheme == _origin.scheme &&
      uri.host == _origin.host &&
      uri.port == _origin.port;
  final _sources = <String, PlaybackSource>{};
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  int _requests = 0;
  static const _maxBody = 8 * 1024 * 1024;

  static Future<void> initialize() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        instance != null) {
      return;
    }
    try {
      final path = await const MethodChannel('zovv/ios-cache')
          .invokeMethod<String>('directory')
          .timeout(const Duration(seconds: 2));
      if (path == null) return;
      instance = await start(Directory(path), origin: ZovvGateway.base);
    } catch (_) {
      // Keep the original secure network player if local caching is unavailable.
    }
  }

  @visibleForTesting
  static Future<IosVideoCache> start(
    Directory directory, {
    required Uri origin,
  }) async {
    final disk = HlsDiskCache(directory);
    await disk.initialize();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final service = IosVideoCache._(disk, server, origin);
    server.listen((request) => unawaited(service._serve(request)));
    return service;
  }

  @visibleForTesting
  Future<void> close() async {
    _http.close(force: true);
    await _server.close(force: true);
  }

  Future<Map<String, Object>> stats({bool clear = false}) async {
    if (clear && _sources.isEmpty) {
      for (var attempt = 0; _requests > 0 && attempt < 4; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    final busy = _sources.isNotEmpty || _requests > 0;
    final cleared = clear && !busy && await _disk.clear();
    return {
      'bytes': await _disk.bytes(),
      'limit': _disk.limit,
      'busy': busy,
      'cleared': cleared,
    };
  }

  VideoPlayerController create(PlaybackSource source) {
    final identity = source.headers['X-Zovv-Cache-Key'];
    if (!_sameOrigin(source.uri) ||
        !RegExp(r'^/stream/[a-f0-9]{48}/index\.m3u8$')
            .hasMatch(source.uri.path) ||
        identity == null ||
        !RegExp(r'^[a-zA-Z0-9:_-]{1,256}$').hasMatch(identity) ||
        _sources.length >= 8) {
      return VideoPlayerController.networkUrl(
        source.uri,
        httpHeaders: source.headers,
      );
    }
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _sources[token] = source;
    return _CachedPlayer(
      Uri.parse('http://localhost:${_server.port}/$token/index.m3u8'),
      () => _sources.remove(token),
    );
  }

  Future<Uint8List> _download(PlaybackSource source, String asset) async {
    final url = source.uri.resolve(asset);
    if (!_sameOrigin(url)) throw const FormatException('origin');
    final request = await _http
        .getUrl(url)
        .timeout(const Duration(seconds: 15));
    for (final entry in source.headers.entries) {
      if (entry.key.toLowerCase() != 'x-zovv-cache-key') {
        request.headers.set(entry.key, entry.value);
      }
    }
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200 || response.contentLength > _maxBody) {
      await response.drain<void>();
      throw const FormatException('media response');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      builder.add(chunk);
      if (builder.length > _maxBody) throw const FormatException('media limit');
    }
    final data = builder.takeBytes();
    if (data.isEmpty ||
        (response.contentLength >= 0 &&
            data.length != response.contentLength)) {
      throw const FormatException('incomplete media');
    }
    return data;
  }

  Future<void> _serve(HttpRequest request) async {
    _requests++;
    _disk.active++;
    try {
      final parts = request.uri.pathSegments;
      final source = parts.length == 2 ? _sources[parts.first] : null;
      final name = parts.length == 2 ? parts.last : '';
      if (source == null ||
          !['GET', 'HEAD'].contains(request.method) ||
          request.uri.hasQuery ||
          !RegExp(r'^(index\.m3u8|init\.mp4|segment-\d{5}\.m4s)$')
              .hasMatch(name)) {
        request.response.statusCode = 404;
        return;
      }
      if (_requests > 6) {
        request.response.statusCode = 503;
        return;
      }
      final manifest = name == 'index.m3u8';
      final data = manifest
          ? await _download(source, name)
          : await _disk.load(
              source.headers['X-Zovv-Cache-Key']!,
              name,
              () => _download(source, name),
            );
      var start = 0, end = data.length - 1;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
        if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
          request.response.statusCode = 416;
          return;
        }
        if (match[1]!.isEmpty) {
          start = max(0, data.length - int.parse(match[2]!));
        } else {
          start = int.parse(match[1]!);
          if (match[2]!.isNotEmpty) end = min(end, int.parse(match[2]!));
        }
        if (start > end || start >= data.length) {
          request.response.statusCode = 416;
          request.response.headers.set(
            'Content-Range',
            'bytes */${data.length}',
          );
          return;
        }
        request.response.statusCode = 206;
        request.response.headers.set(
          'Content-Range',
          'bytes $start-$end/${data.length}',
        );
      }
      request.response.headers.set(
        'Content-Type',
        manifest ? 'application/vnd.apple.mpegurl' : 'video/mp4',
      );
      request.response.headers.set('Cache-Control', 'no-store');
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.contentLength = end - start + 1;
      if (request.method != 'HEAD') {
        request.response.add(data.sublist(start, end + 1));
      }
    } catch (_) {
      request.response.statusCode = 502;
    } finally {
      try {
        await request.response.close();
      } catch (_) {
        /* Client retired. */
      }
      _requests--;
      _disk.active--;
    }
  }
}

class _CachedPlayer extends VideoPlayerController {
  _CachedPlayer(super.url, this._release) : super.networkUrl();
  final void Function() _release;
  bool _released = false;
  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } finally {
      if (!_released) {
        _released = true;
        _release();
      }
    }
  }
}
