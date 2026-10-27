import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:zovv/features/player/data/android_video_cache.dart';

// Run only on an Android emulator with tools/android-player-fixture.cjs and
// adb reverse tcp:8766 tcp:8766. This is a separate test entrypoint, not app UI.
final status = ValueNotifier('Starting native Android smoke checks');
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void report(String message) {
  status.value = message;
  debugPrint('ZOVV_SMOKE $message');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    ),
  );
  try {
    await smoke();
    report('PASS native playback, cache reuse, eviction and clear');
  } catch (error, stack) {
    report('FAIL $error');
    debugPrintStack(stackTrace: stack);
  }
}

Future<VideoPlayerController> open(int identity) async {
  final player = VideoPlayerController.networkUrl(
    Uri.parse('http://127.0.0.1:8766/fixture.mp4'),
    httpHeaders: {'X-Zovv-Cache-Key': 'synthetic-smoke:$identity'},
  );
  try {
    await player.initialize().timeout(const Duration(seconds: 15));
    check(!player.value.hasError, 'Native initialization error');
    check(player.value.duration.inSeconds == 12, 'Unexpected timeline');
    check(player.value.size == const Size(640, 360), 'Unexpected decoded size');
    await player.setPlaybackSpeed(1.5);
    await player.play();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    check(player.value.position > Duration.zero, 'Playback did not advance');
    await player.pause();
    return player;
  } catch (_) {
    await player.dispose();
    rethrow;
  }
}

Future<void> smoke() async {
  await smokeHls();
  final initial = await AndroidVideoCache.read(clear: true);
  check(initial?.cleared == true, 'Initial cache clear failed');
  var player = await open(0);
  await player.seekTo(const Duration(seconds: 7));
  await Future<void>.delayed(const Duration(milliseconds: 350));
  check(player.value.position.inMilliseconds >= 6900, 'Native seek truncated');
  check(player.value.playbackSpeed == 1.5, 'Speed lost after seek');
  await player.dispose();
  var stats = await AndroidVideoCache.read();
  check(stats != null && stats.bytes > 0, 'No media cached');
  final before = stats!.bytes;
  player = await open(0);
  await player.dispose();
  stats = await AndroidVideoCache.read();
  check(
    stats!.bytes <= before + 2000000,
    'Reopen unexpectedly duplicates cache',
  );
  report(
    'PASS seek, speed and same-identity cache reuse; bytes=${stats.bytes}',
  );
  for (var i = 1; i <= 16; i++) {
    player = await open(i);
    await player.dispose();
    stats = await AndroidVideoCache.read();
    check(stats != null && stats.bytes <= stats.limit, 'Cache exceeded budget');
    report('cache sample=$i bytes=${stats!.bytes} limit=${stats.limit}');
  }
  check(stats!.bytes > 140 * 1048576, 'Fixture did not exercise the LRU limit');
  final cleared = await AndroidVideoCache.read(clear: true);
  check(cleared?.cleared == true && cleared?.bytes == 0, 'Final clear failed');
}

Future<void> smokeHls() async {
  final client = HttpClient();
  Future<String> get(String path) async {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:8766/$path'),
    );
    return (await request.close()).transform(utf8.decoder).join();
  }

  VideoPlayerController? player;
  try {
    await get('reset-hls');
    player = VideoPlayerController.networkUrl(
      Uri.parse('http://127.0.0.1:8766/hls/index.m3u8'),
      httpHeaders: {'X-Zovv-Cache-Key': 'synthetic-smoke:hls'},
    );
    await player.initialize().timeout(const Duration(seconds: 15));
    final firstDuration = player.value.duration.inMilliseconds;
    check(
      firstDuration == 2000,
      'Fixture must initialize from the short EVENT window',
    );
    player.value = player.value.copyWith(duration: const Duration(seconds: 12));
    await player.seekTo(Duration.zero);
    await player.play();
    await Future<void>.delayed(const Duration(milliseconds: 4200));
    check(
      !player.value.hasError && !player.value.isCompleted,
      'Growing HLS stopped early',
    );
    check(
      player.value.position.inMilliseconds > 2500,
      'Growing manifest did not advance',
    );
    final stats = jsonDecode(await get('stats')) as Map;
    check(
      (stats['manifests'] as int) > 1,
      'Manifest was cached instead of refreshing',
    );
    report(
      'PASS growing HLS, initial duration=$firstDuration, manifest requests=${stats['manifests']}',
    );
  } finally {
    await player?.dispose();
    client.close(force: true);
  }
}
