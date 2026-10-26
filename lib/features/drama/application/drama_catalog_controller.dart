import 'package:flutter/foundation.dart';

import '../domain/drama.dart';

class DramaCatalogController extends ChangeNotifier {
  DramaCatalogController(this.repository);
  final DramaRepository repository;
  List<Drama> dramas = const [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  String? error;
  String? moreError;
  int page = 1;
  bool _disposed = false;
  int _request = 0;
  Future<void> load() async {
    final request = ++_request;
    loading = true;
    error = null;
    moreError = null;
    loadingMore = false;
    hasMore = false;
    page = 1;
    notifyListeners();
    try {
      final first = await _fetch(1);
      if (_disposed || request != _request) return;
      dramas = List.unmodifiable(_unique(first.dramas));
      hasMore = first.hasMore;
      page = first.page;
    } catch (_) {
      if (_disposed || request != _request) return;
      error = '暂时无法加载剧目，请重试';
    }
    if (!_disposed && request == _request) {
      loading = false;
      notifyListeners();
    }
  }

  /// Appends the next page. Safe to call repeatedly from scroll events.
  Future<void> loadMore() async {
    if (_disposed || loading || loadingMore || !hasMore) return;
    final request = _request;
    loadingMore = true;
    moreError = null;
    notifyListeners();
    try {
      final next = await _fetch(page + 1);
      if (_disposed || request != _request) return;
      final seen = {for (final drama in dramas) drama.id};
      dramas = List.unmodifiable([
        ...dramas,
        ...next.dramas.where((drama) => seen.add(drama.id)),
      ]);
      hasMore = next.hasMore;
      page = next.page;
    } catch (_) {
      if (_disposed || request != _request) return;
      moreError = '加载下一页失败，点击重试';
    } finally {
      if (!_disposed && request == _request) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<DramaPage> _fetch(int target) async {
    if (repository case final PagedDramaRepository paged) {
      return paged.discoverPage(page: target);
    }
    final dramas = await repository.discover();
    return DramaPage(dramas: dramas, page: 1, hasMore: false);
  }

  List<Drama> _unique(List<Drama> input) {
    final seen = <String>{};
    return [
      for (final drama in input)
        if (seen.add(drama.id)) drama,
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
