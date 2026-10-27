import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/application/playback_preferences.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';
import 'player_interaction_test.dart' show PlaybackFeed, PlayingFake;

void main() {
  testWidgets(
    'rapid episode changes preserve the mounted viewport and retire old players',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final library = DramaLibraryController(MemoryLibraryStorage());
      await library.load();
      addTearDown(library.dispose);
      final prefs = PlaybackPreferences(storage: MemoryLibraryStorage());
      await prefs.save(autoNext: false);
      final players = <PlayingFake>[];
      final drama = Drama(
        id: 'rapid-switch',
        title: 'Rapid switch fixture',
        subtitle: '',
        category: '',
        description: '',
        poster: '',
        color: 0,
        episodes: List.generate(
          30,
          (i) => Episode(id: '$i', title: '', number: i + 1),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PlayerScreen(
            drama: drama,
            repository: PlaybackFeed(),
            library: library,
            initialEpisode: 5,
            preferences: prefs,
            createPlayer: (_) {
              final player = PlayingFake();
              players.add(player);
              return player;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = tester.element(find.byType(AnimatedSlide));
      for (var batch = 0; batch < 6; batch++) {
        final next = tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
            )
            .onPressed!;
        final previous = tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
            )
            .onPressed!;
        next();
        next();
        previous();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(AnimatedSlide)),
          same(viewport),
          reason: 'Episode changes must not destroy the parent of the keyed video area',
        );
        expect(tester.takeException(), isNull);
        expect(players.where((player) => !player.closed).length, 1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(players.every((player) => player.closed), true);
    },
  );
}
