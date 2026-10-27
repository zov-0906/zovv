import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/application/playback_preferences.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';
import 'player_interaction_test.dart' show PlayingFake, PlaybackFeed;

class QualityFeed extends PlaybackFeed implements ScheduledPlaybackRepository {
  final pending = Completer<PlaybackSource>();
  final released = <String>[];
  @override
  Future<PlaybackSource> resolveScheduledEpisode(
    String dramaId,
    String episodeId, {
    required String session,
    required int sequence,
    bool preload = false,
    String quality = 'auto',
    bool waitComplete = false,
  }) async => quality == 'auto'
      ? PlaybackSource(
          uri: Uri.parse('https://example.com/auto.mp4'),
          attribution: 'test',
          availableQualities: const ['1080p'],
        )
      : pending.future;
  @override
  Future<void> releasePlaybackSession(String session) async =>
      released.add(session);
}

class QualityFake extends PlayingFake {
  QualityFake(this.resolution);
  final Size resolution;
  @override
  Future<void> initialize() async {
    await super.initialize();
    value = value.copyWith(size: resolution);
  }
}

void main() {
  for (final outcome in ['success', 'failure', 'wrong-size', 'paused-during']) {
    testWidgets(
      'quality switch $outcome preserves position, speed and original playback on failure',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final prefs = PlaybackPreferences(storage: MemoryLibraryStorage());
        await prefs.save(speed: 1.5, autoNext: false);
        final library = DramaLibraryController(MemoryLibraryStorage());
        await library.load();
        addTearDown(library.dispose);
        final repo = QualityFeed(), players = <QualityFake>[];
        await tester.pumpWidget(
          MaterialApp(
            home: PlayerScreen(
              drama: DemoDramaRepository.catalog.first,
              repository: repo,
              library: library,
              preferences: prefs,
              createPlayer: (source) {
                final player = QualityFake(
                  source.quality == '1080p' && outcome != 'wrong-size'
                      ? const Size(1920, 1080)
                      : const Size(640, 360),
                );
                players.add(player);
                return player;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final original = players.single;
        await original.seekTo(const Duration(seconds: 12));
        await tester.tap(find.byTooltip('更多播放设置'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('1080p'));
        await tester.tap(find.text('1080p'));
        await tester.pump();
        expect(original.closed, isFalse);
        expect(original.value.isPlaying, isTrue);
        if (outcome == 'paused-during') await original.pause();
        if (outcome == 'failure') {
          repo.pending.completeError(StateError('offline'));
        } else {
          repo.pending.complete(
            PlaybackSource(
              uri: Uri.parse('https://example.com/full.mp4'),
              attribution: 'test',
              quality: '1080p',
              availableQualities: const ['1080p'],
            ),
          );
        }
        await tester.pumpAndSettle();
        if (outcome == 'success' || outcome == 'paused-during') {
          expect(original.closed, isTrue);
          expect(players.last.value.position, const Duration(seconds: 12));
          expect(players.last.value.playbackSpeed, 1.5);
          expect(players.last.value.isPlaying, outcome != 'paused-during');
          expect(prefs.quality, '1080p');
        } else {
          expect(original.closed, isFalse);
          expect(original.value.isPlaying, isTrue);
          expect(original.value.position, const Duration(seconds: 12));
          expect(prefs.quality, 'auto');
        }
        expect(players.where((p) => !p.closed).length, lessThanOrEqualTo(2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
