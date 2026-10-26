/// Extras around a single episode: public comments and sequel lookup.
///
/// These are optional capabilities: pages check for the interface instead of
/// assuming the current source supports them.
library;

import 'drama.dart';

class EpisodeComment {
  const EpisodeComment({
    required this.author,
    required this.content,
    this.likes,
    this.createdAt,
  });
  final String author;
  final String content;
  final int? likes;
  final DateTime? createdAt;

  static EpisodeComment? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final content = value['content'];
    if (content is! String || content.trim().isEmpty) return null;
    final likes = value['likes'];
    final created = value['created_at'];
    return EpisodeComment(
      author: value['author'] is String ? value['author'] as String : '',
      content: content,
      likes: likes is int ? likes : null,
      createdAt: created is int
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : null,
    );
  }
}

class CommentDigest {
  const CommentDigest({required this.items, this.total, this.notice});
  final List<EpisodeComment> items;
  final int? total;
  final String? notice;
}

abstract interface class EpisodeCommentSource {
  Future<CommentDigest> fetchComments(String dramaId, String episodeId);
}

abstract interface class SequelSource {
  /// Summaries of later seasons found for the same base title.
  Future<List<Drama>> findSequels(String dramaId);
}

/// Prefetches the next episode so switching does not wait for a cold source.
abstract interface class PrefetchedPlayback {
  void prefetchEpisode(String dramaId, String episodeId);
}
