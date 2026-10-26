import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/config/zovv_gateway.dart';
import '../domain/drama.dart';
import '../domain/episode_extras.dart';

typedef HongguoTransport = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String> query,
);

/// Redfruit App metadata via the local trial gateway. No Xifan fallback.
class HongguoDramaRepository
    implements
        DramaRepository,
        DetailedDramaRepository,
        SearchableDramaRepository,
        PagedDramaRepository,
        NotedSearchableDramaRepository,
        EpisodeCommentSource,
        SequelSource,
        PrefetchedPlayback {
  HongguoDramaRepository({HongguoTransport? transport})
    : _transport = transport ?? _request;
  final HongguoTransport _transport;
  final _detailCache = <String, ({Drama drama, DateTime expires})>{};
  final _detailPending = <String, Future<Drama>>{};
  String contentType = 'comic-drama';
  String genre = '';
  Map<String, String> genres = {};
  static const contentTypes = {
    'real-drama': '真人剧',
    'comic-drama': '漫剧',
    'ai-drama': 'AI 剧',
  };
  static Future<Map<String, dynamic>> _request(
    String path,
    Map<String, String> query,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(ZovvGateway.endpoint(path, query));
      for (final entry in ZovvGateway.headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close().timeout(
        Duration(seconds: path == '/playback' ? 90 : 30),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 8 * 1024 * 1024) {
          throw const FormatException('Response too large');
        }
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid gateway response');
      }
      if (response.statusCode >= 300) {
        throw PlaybackUnavailable(
          '${value['error'] ?? '内容服务暂时不可用，请稍后重试'}',
          code: value['code'] is String ? value['code'] as String : null,
          requestId: value['requestId'] is String
              ? value['requestId'] as String
              : null,
        );
      }
      return value;
    } on SocketException {
      throw const PlaybackUnavailable(
        '无法连接内容服务，请检查网络后重试',
        code: 'CONNECTION_FAILED',
      );
    } on HttpException {
      throw const PlaybackUnavailable(
        '内容服务连接中断，请稍后重试',
        code: 'CONNECTION_FAILED',
      );
    } on TimeoutException {
      throw const PlaybackUnavailable('加载时间较长，请稍后重试', code: 'TIMEOUT');
    } on FormatException {
      throw const PlaybackUnavailable(
        '内容服务返回的数据不完整，请稍后重试',
        code: 'INVALID_RESPONSE',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _text(Object? value) =>
      value is String ? value.replaceAll(RegExp(r'<[^>]*>'), '').trim() : '';
  static int _number(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static String _https(Object? value) {
    final uri = Uri.tryParse(value is String ? value : '');
    return uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty
        ? uri.toString()
        : '';
  }

  List<Drama> _parseList(Map<String, dynamic> payload) {
    final results = payload['results'];
    if (results is! List) throw const FormatException('Invalid Redfruit list');
    return results
        .whereType<Map<String, dynamic>>()
        .where((item) => RegExp(r'^\d{1,30}$').hasMatch('${item['series_id']}'))
        .map((item) {
          final tags = item['tags'] is List
              ? (item['tags'] as List).map(_text).toList()
              : <String>[];
          final type =
              tags.where((tag) => genres.containsValue(tag)).firstOrNull ??
              tags.lastOrNull ??
              '短剧';
          return Drama(
            id: 'hongguo:${item['series_id']}',
            title: _text(item['series_title']),
            subtitle: tags.join(' · '),
            category: type,
            description: _text(item['description']),
            poster: _https(item['cover']),
            color: 0xFF8F7C87,
            episodes: const [],
            declaredEpisodeCount: _number(item['episode_count']),
            isDemo: false,
            sourceName: '红果',
            tags: tags,
          );
        })
        .toList();
  }

  @override
  Future<List<Drama>> discover() async => (await discoverPage()).dramas;

  @override
  Future<DramaPage> discoverPage({int page = 1}) async {
    final type = contentType;
    final payload = await _transport('/catalog', {
      'category': type,
      'genre': genre,
      'page': '$page',
    });
    if (payload['genres'] is List && type == contentType && page == 1) {
      genres = {
        for (final item
            in (payload['genres'] as List).whereType<Map<String, dynamic>>())
          '${item['slug']}': _text(item['label']),
      };
    }
    return DramaPage(
      dramas: _parseList(payload),
      page: page,
      hasMore: payload['hasMore'] == true,
    );
  }

  @override
  Future<SearchOutcome> searchWithNotice(String query) async {
    final payload = await _transport('/search', {'q': query.trim()});
    return SearchOutcome(
      dramas: _parseList(payload),
      notice: payload['notice'] is String ? payload['notice'] as String : null,
    );
  }

  @override
  Future<List<Drama>> search(String query) async =>
      (await searchWithNotice(query)).dramas;
  String _seriesId(String id) {
    final parts = id.split(':');
    if (parts.length != 2 ||
        parts.first != 'hongguo' ||
        !RegExp(r'^\d{1,30}$').hasMatch(parts.last)) {
      throw const FormatException('Invalid Redfruit identity');
    }
    return parts.last;
  }

  @override
  Future<Drama> fetchDetails(Drama summary) {
    final sid = _seriesId(summary.id);
    final cached = _detailCache[sid];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      _detailCache.remove(sid);
      _detailCache[sid] = cached;
      return Future.value(cached.drama);
    }
    return _detailPending.putIfAbsent(
      sid,
      () => _fetchDetails(summary)
          .then((drama) {
            _detailCache.remove(sid);
            _detailCache[sid] = (
              drama: drama,
              expires: DateTime.now().add(const Duration(minutes: 2)),
            );
            while (_detailCache.length > 24) {
              _detailCache.remove(_detailCache.keys.first);
            }
            return drama;
          })
          .whenComplete(() {
            _detailPending.remove(sid);
          }),
    );
  }

  Future<Drama> _fetchDetails(Drama summary) async {
    final sid = _seriesId(summary.id);
    final result = await _transport('/details', {'sid': sid});
    if ('${result['series_id']}' != sid || result['episodes'] is! List) {
      throw const PlaybackUnavailable(
        '剧集详情校验失败，请重新加载',
        code: 'IDENTITY_MISMATCH',
      );
    }
    final rows = result['episodes'] as List;
    if (rows.any(
      (item) =>
          item is! Map<String, dynamic> ||
          !RegExp(r'^\d{1,30}$').hasMatch('${item['id']}') ||
          _number(item['number']) < 1,
    )) {
      throw const PlaybackUnavailable(
        '来源分集格式不完整，请稍后重试',
        code: 'INVALID_EPISODES',
      );
    }
    final episodes = (result['episodes'] as List)
        .whereType<Map<String, dynamic>>()
        .where((item) => RegExp(r'^\d{1,30}$').hasMatch('${item['id']}'))
        .map(
          (item) => Episode(
            id: '${item['id']}',
            title: '第 ${_number(item['number'])} 集',
            number: _number(item['number']),
            locked: item['locked'] != false,
          ),
        )
        .toList();
    if (episodes.isEmpty) {
      throw const PlaybackUnavailable('来源暂未返回分集，请稍后重试', code: 'EMPTY_EPISODES');
    }
    return Drama(
      id: summary.id,
      title: _text(result['series_title']).isEmpty
          ? summary.title
          : _text(result['series_title']),
      subtitle: summary.subtitle,
      category: summary.category,
      description: _text(result['description']).isEmpty
          ? summary.description
          : _text(result['description']),
      poster: _https(result['cover']).isEmpty
          ? summary.poster
          : _https(result['cover']),
      color: summary.color,
      episodes: episodes,
      declaredEpisodeCount: episodes.length,
      isDemo: false,
      sourceName: '红果',
      tags: summary.tags,
      detailsNotice:
          result['_meta'] is Map &&
              _text((result['_meta'] as Map)['notice']).isNotEmpty
          ? _text((result['_meta'] as Map)['notice'])
          : null,
    );
  }

  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async {
    if (!RegExp(r'^\d{1,30}$').hasMatch(episodeId)) {
      throw const FormatException('Invalid episode');
    }
    final result = await _transport('/playback', {
      'sid': _seriesId(dramaId),
      'vid': episodeId,
    });
    if (result['requiresMediaApproval'] == true) {
      throw PlaybackUnavailable('${result['error']}');
    }
    final uri = Uri.tryParse('${result['url']}');
    final gatewayMedia =
        uri != null &&
        ZovvGateway.sameOrigin(uri) &&
        RegExp(r'^/media/[a-f0-9]{48}\.mp4$').hasMatch(uri.path) &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
    if (uri == null || (uri.scheme != 'https' && !gatewayMedia)) {
      throw const PlaybackUnavailable('红果返回的播放地址无效，请重新连接');
    }
    final headers = <String, String>{
      if (ZovvGateway.sameOrigin(uri)) ...ZovvGateway.headers,
      if (result['headers'] is Map)
        ...Map<String, String>.from(result['headers'] as Map),
    };
    return PlaybackSource(
      uri: uri,
      headers: headers,
      attribution: '${result['attribution'] ?? '片源：红果'}',
    );
  }

  /// Warms the gateway cache for the next episode. Best effort only.
  @override
  void prefetchEpisode(String dramaId, String episodeId) {
    final String sid;
    try {
      sid = _seriesId(dramaId);
    } on FormatException {
      return;
    }
    if (!RegExp(r'^\d{1,30}$').hasMatch(episodeId)) return;
    unawaited(
      _transport('/prefetch', {
        'sid': sid,
        'vid': episodeId,
      }).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  @override
  Future<CommentDigest> fetchComments(String dramaId, String episodeId) async {
    if (!RegExp(r'^\d{1,30}$').hasMatch(episodeId)) {
      throw const FormatException('Invalid episode');
    }
    final payload = await _transport('/comments', {
      'sid': _seriesId(dramaId),
      'vid': episodeId,
    });
    final items = payload['items'];
    return CommentDigest(
      items: [
        for (final item in items is List ? items : const <Object>[])
          ?EpisodeComment.fromJson(item),
      ],
      total: payload['total'] is int ? payload['total'] as int : null,
      notice: payload['notice'] is String ? payload['notice'] as String : null,
    );
  }

  @override
  Future<List<Drama>> findSequels(String dramaId) async {
    final payload = await _transport('/sequel', {'sid': _seriesId(dramaId)});
    final results = payload['results'];
    if (results is! List || results.isEmpty) {
      final note = payload['error'];
      if (note is String && note.isNotEmpty) throw PlaybackUnavailable(note);
      return const [];
    }
    return [
      for (final item in results)
        if (item is Map<String, dynamic> &&
            RegExp(r'^\d{1,30}$').hasMatch('${item['series_id']}'))
          Drama(
            id: 'hongguo:${item['series_id']}',
            title: _text(item['series_title']),
            subtitle: '续作 · 红果',
            category: '短剧',
            description: _text(item['description']),
            poster: _https(item['cover']),
            color: 0xFF8F7C87,
            episodes: const [],
            declaredEpisodeCount: _number(item['episode_count']),
            isDemo: false,
            sourceName: '红果',
          ),
    ];
  }
}
