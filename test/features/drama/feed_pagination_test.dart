import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_catalog_controller.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/drama/presentation/drama_shell.dart';
import 'package:zovv/features/drama/presentation/widgets/drama_card.dart';

import '../startup/memory_library_storage.dart';

Drama card(String id, String title) => Drama(
  id: id,
  title: title,
  subtitle: '都市',
  category: '都市',
  description: '测试分页',
  poster: '',
  color: 0xFF647BA4,
  episodes: const [],
);

class PagedFeedRepository implements DramaRepository, PagedDramaRepository {
  int calls = 0;
  @override
  Future<List<Drama>> discover() async => (await discoverPage()).dramas;
  @override
  Future<DramaPage> discoverPage({int page = 1}) async {
    calls += 1;
    return DramaPage(
      dramas: [card('p${page}a', '第$page页甲'), card('p${page}b', '第$page页乙')],
      page: page,
      hasMore: page < 4,
    );
  }

  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => throw const PlaybackUnavailable('测试占位');
}

void main() {
  test(
    'catalog appends pages, de-duplicates and stops when exhausted',
    () async {
      final repository = PagedFeedRepository();
      final catalog = DramaCatalogController(repository);
      addTearDown(catalog.dispose);
      await catalog.load();
      expect(catalog.dramas.length, 2);
      expect(catalog.hasMore, isTrue);
      await catalog.loadMore();
      expect(catalog.dramas.length, 4);
      expect(catalog.dramas.first.id, 'p1a');
      await catalog.loadMore();
      await catalog.loadMore();
      expect(catalog.dramas.length, 8);
      expect(catalog.hasMore, isFalse);
      await catalog.loadMore();
      expect(repository.calls, 4);
      expect(catalog.dramas.map((drama) => drama.id).toSet().length, 8);
    },
  );

  testWidgets('scrolling the home feed loads the next page automatically', (
    tester,
  ) async {
    final repository = PagedFeedRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: DramaShell(
          onReplayStartup: () {},
          storage: MemoryLibraryStorage(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DramaCard), findsNWidgets(2));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1600),
    );
    await tester.pumpAndSettle();
    expect(repository.calls, greaterThan(1));
    expect(find.byType(DramaCard), findsNWidgets(repository.calls * 2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
