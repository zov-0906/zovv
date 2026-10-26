import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';
import 'next_episode_buffer_test.dart' show FakePlayer, source;

class PlayingFake extends FakePlayer {
  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);
  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);
}

class PlaybackFeed extends DemoDramaRepository {
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => source();
}

void main() {
  testWidgets(
    'automatic handoff stays clear while a user pause reveals controls',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final players = <PlayingFake>[];
      final library = DramaLibraryController(MemoryLibraryStorage());
      await library.load();
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            drama: DemoDramaRepository.catalog.first,
            repository: PlaybackFeed(),
            library: library,
            createPlayer: (_) {
              final player = PlayingFake();
              players.add(player);
              return player;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      players.first.value = players.first.value.copyWith(
        position: const Duration(seconds: 60),
        isCompleted: true,
        isPlaying: false,
      );
      await tester.pumpAndSettle();
      expect(
        players.any((player) => !player.closed && player.value.isPlaying),
        isTrue,
      );
      expect(find.byTooltip('暂停').hitTestable(), findsNothing);
      await tester.tapAt(const Offset(400, 250));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('暂停'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byTooltip('播放').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'vertical drag follows the finger, rebounds, and changes episode after release',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final library = DramaLibraryController(MemoryLibraryStorage());
      await library.load();
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            drama: DemoDramaRepository.catalog.first,
            repository: PlaybackFeed(),
            library: library,
            createPlayer: (_) => PlayingFake(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(190, 300));
      await gesture.moveBy(const Offset(0, -20));
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset.dy,
        lessThan(0),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
      );
      expect(find.text('第 1 集'), findsWidgets);
      await tester.dragFrom(const Offset(190, 300), const Offset(0, -220));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('第 2 集'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
