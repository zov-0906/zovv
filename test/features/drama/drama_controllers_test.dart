import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/application/drama_catalog_controller.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/drama/domain/watch_progress.dart';

import '../startup/memory_library_storage.dart';

class FailingRepository implements DramaRepository {
  @override
  Future<List<Drama>> discover() async => throw StateError('offline');
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => throw UnimplementedError();
}

class DelayedStorage extends MemoryLibraryStorage {
  final first = Completer<void>();
  int writes = 0;
  @override
  Future<void> write(String value) async {
    writes++;
    if (writes == 1) await first.future;
    await super.write(value);
  }
}

void main() {
  test('favorites and episode position survive a new controller', () async {
    final storage = MemoryLibraryStorage();
    final first = DramaLibraryController(storage);
    await first.load();
    first.remember(DemoDramaRepository.catalog.first);
    first.toggleFavorite('evening');
    first.record(
      WatchProgress(
        dramaId: 'evening',
        episodeIndex: 1,
        positionSeconds: 37,
        updatedAt: DateTime.utc(2026, 10, 26),
      ),
    );
    await first.persist();
    first.dispose();
    final next = DramaLibraryController(storage);
    addTearDown(next.dispose);
    await next.load();
    expect(next.favorites, contains('evening'));
    expect(next.knownDramas.single.title, '晚风来信');
    expect(next.progressFor('evening')?.positionSeconds, 37);
    expect(next.progressFor('evening')?.episodeIndex, 1);
    next.toggleFavorite('evening');
    await next.persist();
    expect(next.favorites, isEmpty);
  });
  test('writes stay in order under slow storage', () async {
    final storage = DelayedStorage();
    final library = DramaLibraryController(storage);
    addTearDown(library.dispose);
    await library.load();
    library.toggleFavorite('evening');
    library.toggleFavorite('night');
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, 1);
    storage.first.complete();
    await library.persist();
    final restored = DramaLibraryController(storage);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.favorites, containsAll(['evening', 'night']));
  });
  test(
    'malformed local data reports an error without blocking the library',
    () async {
      final library = DramaLibraryController(MemoryLibraryStorage('{broken'));
      addTearDown(library.dispose);
      await library.load();
      expect(library.ready, isTrue);
      expect(library.error, isNotNull);
      library.toggleFavorite('evening');
      await library.persist();
      expect(library.error, isNull);
    },
  );
  test(
    'catalog handles errors and source validates episode ownership',
    () async {
      final catalog = DramaCatalogController(FailingRepository());
      addTearDown(catalog.dispose);
      await catalog.load();
      expect(catalog.loading, isFalse);
      expect(catalog.error, isNotNull);
      final repository = DemoDramaRepository();
      await expectLater(
        repository.resolveEpisode('unknown', 'sample-480'),
        throwsArgumentError,
      );
      final source = await repository.resolveEpisode('evening', 'sample-480');
      expect(source.uri.scheme, 'https');
      expect(source.attribution, contains('Blender'));
    },
  );
}
