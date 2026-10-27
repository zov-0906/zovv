import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/application/playback_preferences.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';
import 'player_interaction_test.dart' show PlaybackFeed, PlayingFake;
import 'next_episode_buffer_test.dart' show source;

class PendingPreloadFeed extends PlaybackFeed
    implements PreloadCancellationRepository {
  final next = Completer<PlaybackSource>();
  int requests = 0, cancellations = 0;
  @override
  Future<PlaybackSource> resolveEpisode(String dramaId, String episodeId) {
    requests++;
    return requests == 1 ? Future.value(source()) : next.future;
  }

  @override
  Future<void> cancelPreload(String session, int sequence) async {
    cancellations++;
  }
}

void main() {
  for (final trigger in ['buffering', 'background']) {
    testWidgets('$trigger cancels speculative work without disposing current', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final library = DramaLibraryController(MemoryLibraryStorage());
      await library.load();
      addTearDown(library.dispose);
      final repo = PendingPreloadFeed(), players = <PlayingFake>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            drama: DemoDramaRepository.catalog.first,
            repository: repo,
            library: library,
            preferences: PlaybackPreferences(storage: MemoryLibraryStorage()),
            createPlayer: (_) {
              final player = PlayingFake();
              players.add(player);
              return player;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      players.first.value = players.first.value.copyWith(
        buffered: [DurationRange(Duration.zero, const Duration(seconds: 30))],
      );
      await tester.pump(const Duration(seconds: 3));
      expect(repo.requests, 2);
      if (trigger == 'buffering') {
        players.first.value = players.first.value.copyWith(isBuffering: true);
        await tester.pump(const Duration(seconds: 3));
      } else {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
      }
      expect(repo.cancellations, 1);
      expect(players.first.closed, false);
      repo.next.complete(source());
      await tester.pump();
      await tester.pump();
      expect(
        players.length,
        1,
      ); // Cancelled response cannot allocate a native player.
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
}
