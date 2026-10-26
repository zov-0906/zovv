class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.number,
    this.locked = false,
  });
  final String id;
  final String title;
  final int number;
  final bool locked;
}

class Drama {
  const Drama({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.description,
    required this.poster,
    required this.color,
    required this.episodes,
    this.declaredEpisodeCount,
    this.isDemo = true,
    this.sourceName = '演示',
    this.tags = const [],
    this.detailsNotice,
  });
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String description;
  final String poster;
  final int color;
  final List<Episode> episodes;
  final int? declaredEpisodeCount;
  final bool isDemo;
  final String sourceName;
  final List<String> tags;
  final String? detailsNotice;
  int get episodeCount => declaredEpisodeCount ?? episodes.length;
  String get episodeLabel => isDemo ? '$episodeCount 段体验' : '$episodeCount 集';
  Map<String, Object> toSummaryJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'category': category,
    'description': description,
    'poster': poster,
    'color': color,
    'episodeCount': episodeCount,
    'isDemo': isDemo,
    'sourceName': sourceName,
    'tags': tags,
  };
  static Drama? fromSummaryJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['title'] is! String) {
      return null;
    }
    String text(String key) => value[key] is String ? value[key] as String : '';
    return Drama(
      id: text('id'),
      title: text('title'),
      subtitle: text('subtitle'),
      category: text('category'),
      description: text('description'),
      poster: text('poster'),
      color: value['color'] is int ? value['color'] as int : 0xFF74849B,
      declaredEpisodeCount: value['episodeCount'] is int
          ? value['episodeCount'] as int
          : 0,
      isDemo: value['isDemo'] == true,
      sourceName: text('sourceName'),
      tags: value['tags'] is List
          ? (value['tags'] as List).whereType<String>().toList()
          : const [],
      episodes: const [],
    );
  }
}

abstract interface class DetailedDramaRepository {
  Future<Drama> fetchDetails(Drama summary);
}

abstract interface class SearchableDramaRepository {
  Future<List<Drama>> search(String query);
}

class PlaybackUnavailable implements Exception {
  const PlaybackUnavailable(this.message, {this.code, this.requestId});
  final String message;
  final String? code;
  final String? requestId;
}

class PlaybackSource {
  const PlaybackSource({
    required this.uri,
    required this.attribution,
    this.headers = const {},
    this.expiresAt,
  });
  final Uri uri;
  final String attribution;
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

abstract interface class DramaRepository {
  Future<List<Drama>> discover();
  Future<PlaybackSource> resolveEpisode(String dramaId, String episodeId);
}

/// One page of a feed, used by sources that paginate the catalogue.
class DramaPage {
  const DramaPage({
    required this.dramas,
    required this.page,
    required this.hasMore,
  });
  final List<Drama> dramas;
  final int page;
  final bool hasMore;
}

abstract interface class PagedDramaRepository {
  Future<DramaPage> discoverPage({int page = 1});
}

/// Search result plus an optional explanation (for example when the source
/// search is unavailable and the answer comes from a local index).
class SearchOutcome {
  const SearchOutcome({required this.dramas, this.notice});
  final List<Drama> dramas;
  final String? notice;
}

abstract interface class NotedSearchableDramaRepository {
  Future<SearchOutcome> searchWithNotice(String query);
}
