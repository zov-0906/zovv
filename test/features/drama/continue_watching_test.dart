import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/drama/domain/watch_progress.dart';
import 'package:zovv/features/drama/presentation/drama_shell.dart';
import 'package:zovv/features/player/presentation/player_screen.dart';

import '../startup/memory_library_storage.dart';

/// Never reaches the video plugin: the resume flow is what is under test.
class SilentPlaybackRepository implements DramaRepository {
  @override
  Future<List<Drama>> discover() async => DemoDramaRepository.catalog;
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => throw const PlaybackUnavailable('本站占位：暂不播放');
}

/// Catalog-only source, like the Redfruit summary list.
class DeferredDetailsRepository
    implements DramaRepository, DetailedDramaRepository {
  DeferredDetailsRepository(this.summary);
  final Drama summary;
  final pending = Completer<Drama>();
  int requests = 0;
  @override
  Future<List<Drama>> discover() async => [summary];
  @override
  Future<Drama> fetchDetails(Drama drama) {
    requests++;
    return pending.future;
  }

  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => throw const PlaybackUnavailable('本站占位：暂不播放');
}

const remoteSummary = Drama(
  id: 'hongguo:1001',
  title: '测试漫剧',
  subtitle: '都市 · 逆袭',
  category: '都市',
  description: '仅用于续播流程测试的摘要。',
  poster: 'assets/posters/night.jpg',
  color: 0xFF647BA4,
  episodes: [],
  declaredEpisodeCount: 12,
  isDemo: false,
  sourceName: '红果',
);

Drama remoteDetails() => Drama(
  id: remoteSummary.id,
  title: remoteSummary.title,
  subtitle: remoteSummary.subtitle,
  category: remoteSummary.category,
  description: remoteSummary.description,
  poster: remoteSummary.poster,
  color: remoteSummary.color,
  episodes: [
    for (var number = 1; number <= 12; number++)
      Episode(id: '$number', title: '第 $number 集', number: number),
  ],
  declaredEpisodeCount: 12,
  isDemo: false,
  sourceName: '红果',
);

String seededLibrary({
  required Drama summary,
  required int episodeIndex,
  required int positionSeconds,
}) => jsonEncode({
  'version': 1,
  'metadata': [summary.toSummaryJson()],
  'favorites': <String>[],
  'progress': [
    WatchProgress(
      dramaId: summary.id,
      episodeIndex: episodeIndex,
      positionSeconds: positionSeconds,
      updatedAt: DateTime.utc(2026, 10, 26, 12),
    ).toJson(),
  ],
});

void main() {
  test('resume entries are newest first and skip unknown summaries', () async {
    final library = DramaLibraryController(MemoryLibraryStorage());
    addTearDown(library.dispose);
    await library.load();
    library.remember(DemoDramaRepository.catalog[0]);
    library.remember(DemoDramaRepository.catalog[1]);
    library.record(
      WatchProgress(
        dramaId: 'evening',
        episodeIndex: 2,
        positionSeconds: 75,
        updatedAt: DateTime.utc(2026, 10, 26, 10),
      ),
    );
    library.record(
      WatchProgress(
        dramaId: 'night',
        episodeIndex: 0,
        positionSeconds: 5,
        updatedAt: DateTime.utc(2026, 10, 26, 12),
      ),
    );
    library.record(
      WatchProgress(
        dramaId: 'ghost',
        episodeIndex: 0,
        positionSeconds: 9,
        updatedAt: DateTime.utc(2026, 10, 26, 13),
      ),
    );
    final entries = library.resumeEntries;
    expect(entries.map((entry) => entry.drama.id), ['night', 'evening']);
    expect(entries.first.caption, '第 1 集 · 已看 0:05');
    expect(entries.last.caption, '第 3 集 · 已看 1:15');
    expect(
      ResumeEntry(
        drama: DemoDramaRepository.catalog.first,
        progress: WatchProgress(
          dramaId: 'evening',
          episodeIndex: 0,
          positionSeconds: 3725,
          updatedAt: DateTime.utc(2026, 10, 26),
        ),
      ).positionLabel,
      '1:02:05',
    );
  });

  testWidgets('the rail stays hidden without saved progress', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DramaShell(
          onReplayStartup: () {},
          storage: MemoryLibraryStorage(),
          repository: SilentPlaybackRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('继续观看'), findsNothing);
    expect(find.text('好故事，慢慢看。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home rail resumes the saved episode without opening details', (
    tester,
  ) async {
    final storage = MemoryLibraryStorage(
      seededLibrary(
        summary: DemoDramaRepository.catalog.first,
        episodeIndex: 1,
        positionSeconds: 42,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DramaShell(
          onReplayStartup: () {},
          storage: storage,
          repository: SilentPlaybackRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('第 2 集 · 已看 0:42'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('resume-evening')));
    await tester.tap(find.byKey(const Key('resume-evening')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('第 2 集'), findsOneWidget);
    expect(find.text('本站占位：暂不播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('catalog-only source resolves details before playback', (
    tester,
  ) async {
    final repository = DeferredDetailsRepository(remoteSummary);
    final storage = MemoryLibraryStorage(
      seededLibrary(
        summary: remoteSummary,
        episodeIndex: 4,
        positionSeconds: 62,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DramaShell(
          onReplayStartup: () {},
          storage: storage,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('第 5 集 · 已看 1:02'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('resume-hongguo:1001')));
    await tester.tap(find.byKey(const Key('resume-hongguo:1001')));
    await tester.pump();
    expect(find.byKey(const Key('resume-preparing')), findsOneWidget);
    expect(repository.requests, 1);
    repository.pending.complete(remoteDetails());
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('第 5 集'), findsOneWidget);
    expect(find.text('本站占位：暂不播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed detail request keeps the viewer on the rail', (
    tester,
  ) async {
    final repository = DeferredDetailsRepository(remoteSummary);
    final storage = MemoryLibraryStorage(
      seededLibrary(
        summary: remoteSummary,
        episodeIndex: 2,
        positionSeconds: 18,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: DramaShell(
          onReplayStartup: () {},
          storage: storage,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('resume-hongguo:1001')));
    await tester.tap(find.byKey(const Key('resume-hongguo:1001')));
    await tester.pump();
    repository.pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsNothing);
    expect(find.text('暂时打不开这一集，请稍后重试'), findsOneWidget);
    expect(find.byKey(const Key('resume-hongguo:1001')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
