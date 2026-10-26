import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_catalog_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';

import '../startup/memory_library_storage.dart';

class PendingFeed implements DramaRepository, PagedDramaRepository {
  final requests = <Completer<DramaPage>>[];
  @override
  Future<DramaPage> discoverPage({int page = 1}) {
    final pending = Completer<DramaPage>();
    requests.add(pending);
    return pending.future;
  }

  @override
  Future<List<Drama>> discover() async => (await discoverPage()).dramas;
  @override
  Future<PlaybackSource> resolveEpisode(String dramaId, String episodeId) =>
      throw UnimplementedError();
}

void main() {
  test('cached startup remains visible when network refresh fails', () async {
    final snapshot = DemoDramaRepository.catalog.first;
    final cache = MemoryLibraryStorage(
      jsonEncode({
        'key': 'one',
        'dramas': [snapshot.toSummaryJson()],
      }),
    );
    final repo = PendingFeed();
    final controller = DramaCatalogController(
      repo,
      cache: cache,
      cacheKey: () => 'one',
    );
    addTearDown(controller.dispose);
    final loading = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.dramas.single.id, snapshot.id);
    expect(controller.loading, isTrue);
    repo.requests.single.completeError(StateError('offline'));
    await loading;
    expect(controller.dramas.single.id, snapshot.id);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
  });

  test('refresh invalidates in-flight pagination and changing filter clears old feed', () async {
    final repo = PendingFeed();
    var key = 'one';
    final controller = DramaCatalogController(repo, cacheKey: () => key);
    addTearDown(controller.dispose);
    final first = controller.load();
    repo.requests[0].complete(
      DramaPage(
        dramas: [DemoDramaRepository.catalog.first],
        page: 1,
        hasMore: true,
      ),
    );
    await first;
    final more = controller.loadMore();
    final refresh = controller.load();
    repo.requests[2].complete(
      DramaPage(
        dramas: [DemoDramaRepository.catalog.last],
        page: 1,
        hasMore: false,
      ),
    );
    await refresh;
    repo.requests[1].complete(
      DramaPage(dramas: DemoDramaRepository.catalog, page: 2, hasMore: true),
    );
    await more;
    expect(controller.dramas.single.id, DemoDramaRepository.catalog.last.id);
    key = 'two';
    final filtered = controller.load();
    expect(controller.dramas, isEmpty);
    repo.requests[3].complete(DramaPage(dramas: [], page: 1, hasMore: false));
    await filtered;
    expect(controller.loadingMore, isFalse);
  });
}
