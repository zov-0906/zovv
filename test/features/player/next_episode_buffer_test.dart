import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/application/next_episode_buffer.dart';

class FakePlayer extends VideoPlayerController {
  FakePlayer({this.initialization})
    : super.networkUrl(Uri.parse('https://example.com/video'));
  final Completer<void>? initialization;
  bool closed = false;
  @override
  Future<void> initialize() async {
    if (initialization != null) await initialization!.future;
    if (!closed) {
      value = VideoPlayerValue(
        duration: const Duration(seconds: 60),
        size: const Size(640, 360),
        isInitialized: true,
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (!closed) value = value.copyWith(volume: volume);
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!closed) value = value.copyWith(position: position);
  }

  @override
  Future<void> dispose() async {
    if (closed) return;
    closed = true;
    await super.dispose();
  }
}

PlaybackSource source({bool expired = false}) => PlaybackSource(
  uri: Uri.parse('https://example.com/video'),
  attribution: 'test',
  expiresAt: DateTime.now().add(Duration(minutes: expired ? -1 : 10)),
);

Future<void> drain() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'prepared player transfers ownership without a second source request',
    () async {
      var requests = 0;
      final player = FakePlayer();
      final states = <NextEpisodeState>[];
      final buffer = NextEpisodeBuffer(
        resolve: (_) async {
          requests++;
          return source();
        },
        create: (_) => player,
        onChanged: states.add,
      );
      buffer.prepare(1);
      await drain();
      expect(states.last, NextEpisodeState.ready);
      expect(player.value.volume, 0);
      final ready = await buffer.take(1);
      expect(ready!.controller, same(player));
      expect(requests, 1);
      await buffer.dispose();
      expect(player.closed, isFalse);
      await ready.controller.dispose();
    },
  );
  test('leaving while resolving never allocates a native player', () async {
    final pending = Completer<PlaybackSource>();
    var creates = 0;
    final buffer = NextEpisodeBuffer(
      resolve: (_) => pending.future,
      create: (_) {
        creates++;
        return FakePlayer();
      },
      onChanged: (_) {},
    );
    buffer.prepare(1);
    await buffer.dispose();
    pending.complete(source());
    await drain();
    expect(creates, 0);
  });
  test('skipping during initialization retires the abandoned preload before a new one', () async {
    final init = Completer<void>();
    final players = <FakePlayer>[];
    final buffer = NextEpisodeBuffer(
      resolve: (_) async => source(),
      create: (_) {
        final player = FakePlayer(
          initialization: players.isEmpty ? init : null,
        );
        players.add(player);
        return player;
      },
      onChanged: (_) {},
    );
    buffer.prepare(1);
    await drain();
    buffer.prepare(2);
    await drain();
    expect(players.first.closed, isTrue);
    expect(players.length, 2);
    init.complete();
    await drain();
    final ready = await buffer.take(2);
    expect(ready!.index, 2);
    await ready.controller.dispose();
    await buffer.dispose();
  });
  test('rapid selection cancels a pending handoff instead of leaking its controller', () async {
    final init = Completer<void>();
    final player = FakePlayer(initialization: init);
    final buffer = NextEpisodeBuffer(
      resolve: (_) async => source(),
      create: (_) => player,
      onChanged: (_) {},
    );
    buffer.prepare(1);
    await drain();
    final taking = buffer.take(1);
    await buffer.cancelHandoff();
    expect(player.closed, isTrue);
    init.complete();
    expect(await taking, isNull);
    await buffer.dispose();
  });
  test(
    'failed preload can be retried and expired source is never promoted',
    () async {
      var attempts = 0;
      final states = <NextEpisodeState>[];
      final buffer = NextEpisodeBuffer(
        resolve: (_) async => source(expired: attempts++ == 0),
        create: (_) => FakePlayer(),
        onChanged: states.add,
      );
      buffer.prepare(1);
      await drain();
      expect(states.last, NextEpisodeState.failed);
      buffer.prepare(1);
      await drain();
      expect(states.last, NextEpisodeState.ready);
      final ready = await buffer.take(1);
      await ready!.controller.dispose();
      await buffer.dispose();
      expect(attempts, 2);
    },
  );
}
