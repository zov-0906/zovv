import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';

class PendingRepository implements DramaRepository {
  final pending = Completer<PlaybackSource>();
  @override
  Future<List<Drama>> discover() async => DemoDramaRepository.catalog;
  @override
  Future<PlaybackSource> resolveEpisode(String dramaId, String episodeId) =>
      pending.future;
}

class OfflineRepository implements DramaRepository {
  int requests = 0;
  @override
  Future<List<Drama>> discover() async => DemoDramaRepository.catalog;
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async {
    requests++;
    throw StateError('offline');
  }
}

void main() {
  testWidgets(
    'compact player moves autoplay into more settings and remembers its in-page selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final library = DramaLibraryController(MemoryLibraryStorage());
      await library.load();
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: PlayerScreen(
            drama: DemoDramaRepository.catalog.first,
            repository: OfflineRepository(),
            library: library,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('选集 · 共'), findsOneWidget);
      await tester.tap(find.byTooltip('更多播放设置'));
      await tester.pumpAndSettle();
      expect(find.text('播放设置'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      Navigator.of(tester.element(find.text('播放设置'))).pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('leaving before source resolution ignores the stale result', (
    tester,
  ) async {
    final repository = PendingRepository();
    final library = DramaLibraryController(MemoryLibraryStorage());
    await library.load();
    addTearDown(library.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          drama: DemoDramaRepository.catalog.first,
          repository: repository,
          library: library,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('正在连接故事…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pending.complete(
      PlaybackSource(
        uri: Uri.parse('https://example.com/sample.mp4'),
        attribution: 'test',
      ),
    );
    await tester.pump();
    expect(library.recent, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('source failure offers retry without losing page controls', (
    tester,
  ) async {
    final repository = OfflineRepository();
    final library = DramaLibraryController(MemoryLibraryStorage());
    await library.load();
    addTearDown(library.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerScreen(
          drama: DemoDramaRepository.catalog.first,
          repository: repository,
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('视频暂时无法播放，请检查网络后重试'), findsOneWidget);
    await tester.tap(find.text('重新连接'));
    await tester.pumpAndSettle();
    expect(repository.requests, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
