import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/drama/presentation/drama_search_screen.dart';

class PendingSearch implements DramaRepository, SearchableDramaRepository {
  final requests = <Completer<List<Drama>>>[];
  @override
  Future<List<Drama>> search(String query) {
    final request = Completer<List<Drama>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<Drama>> discover() async => [];
  @override
  Future<PlaybackSource> resolveEpisode(String dramaId, String episodeId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets(
    'search refresh retains results while pending and after failure',
    (tester) async {
      final repo = PendingSearch();
      final drama = DemoDramaRepository.catalog.first;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DramaSearchScreen(
              dramas: const [],
              repository: repo,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.enterText(find.byKey(const Key('drama-search')), 'story');
      await tester.pump(const Duration(milliseconds: 450));
      repo.requests.single.complete([drama]);
      await tester.pumpAndSettle();
      expect(find.text(drama.title), findsOneWidget);
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final pending = refresh.onRefresh();
      await tester.pump();
      expect(find.text(drama.title), findsOneWidget);
      repo.requests.last.completeError(StateError('offline'));
      await pending;
      await tester.pumpAndSettle();
      expect(find.text(drama.title), findsOneWidget);
      expect(find.text('更新失败，保留上次搜索结果。下拉可重试。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty search refresh refreshes catalog', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DramaSearchScreen(
            dramas: const [],
            onOpen: (_) {},
            onRefreshCatalog: () async {
              refreshes++;
            },
          ),
        ),
      ),
    );
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    expect(refreshes, 1);
  });
}
