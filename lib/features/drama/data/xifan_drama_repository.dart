import 'dart:convert';
import 'dart:io';

import '../domain/drama.dart';

typedef XifanTransport = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, String> query,
);

/// Independently implemented adapter for the same public source used by the
/// reference desktop client. Never unlocks protected episodes or stores URLs.
class XifanDramaRepository
    implements
        DramaRepository,
        DetailedDramaRepository,
        SearchableDramaRepository {
  XifanDramaRepository({XifanTransport? transport})
    : _transport = transport ?? _request;
  final XifanTransport _transport;
  final Map<String, Drama> _summaries = {};
  static final _id = RegExp(r'^[a-zA-Z0-9_-]{1,200}$');

  static Future<Map<String, dynamic>> _request(
    String path,
    Map<String, String> query,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.https('xifan-api-cn.youlishipin.com', path, {
        ...query,
        'version': '2001001',
        'androidVersionCode': '28',
      });
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) {
        throw const FormatException('Source unavailable');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 12))) {
        bytes.addAll(chunk);
        if (bytes.length > 8 * 1024 * 1024) {
          throw const FormatException('Response too large');
        }
      }
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic> ||
          value['ret'] != 0 ||
          value['result'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid source response');
      }
      return value['result'] as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  static String _text(Object? value) =>
      value is String ? value.replaceAll(RegExp(r'<[^>]*>'), '').trim() : '';
  static String _https(Object? value) {
    final uri = Uri.tryParse(value is String ? value : '');
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? uri.toString()
        : '';
  }

  static int _integer(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static List<Map<String, dynamic>> _objects(Object? value) =>
      value is List ? value.whereType<Map<String, dynamic>>().toList() : [];

  List<Drama> _list(Map<String, dynamic> result) {
    final dramas = <Drama>[];
    final seen = <String>{};
    for (final element in _objects(result['elements'])) {
      for (final content in _objects(element['contents'])) {
        final value = content['duanjuVo'];
        if (value is! Map<String, dynamic>) continue;
        final source = '${value['source']}';
        final id = '${value['duanjuId']}';
        final title = _text(value['title']);
        if (!_id.hasMatch(source) || !_id.hasMatch(id) || title.isEmpty) {
          continue;
        }
        final key = 'xifan:$source:$id';
        if (!seen.add(key)) continue;
        final tags =
            (value['categories'] is List
                    ? value['categories'] as List
                    : const [])
                .map(_text)
                .where((tag) => tag.isNotEmpty)
                .toList();
        final drama = Drama(
          id: key,
          title: title,
          subtitle: tags.take(3).join(' · '),
          category: tags.contains('都市')
              ? '都市'
              : tags.contains('古装') || tags.contains('古风')
              ? '古风'
              : tags.contains('悬疑')
              ? '悬疑'
              : tags.contains('甜宠')
              ? '甜宠'
              : tags.firstOrNull ?? '短剧',
          description: _text(value['desc']),
          poster: _https(value['coverImageUrl']),
          color: 0xFF74849B,
          episodes: const [],
          declaredEpisodeCount: _integer(value['total']),
          isDemo: false,
          sourceName: '西饭',
          tags: tags,
        );
        _summaries[key] = drama;
        dramas.add(drama);
      }
    }
    return dramas;
  }

  @override
  Future<List<Drama>> discover() async => _list(
    await _transport('/xifan/drama/portalPage', {
      'reqType': 'aggregationPage',
      'offset': '0',
    }),
  );
  @override
  Future<List<Drama>> search(String query) async => _list(
    await _transport('/xifan/search/getSearchList', {
      'keyword': query.trim(),
      'pageIndex': '1',
    }),
  );

  Future<Map<String, dynamic>> _detail(String key) async {
    final parts = key.split(':');
    if (parts.length != 3 ||
        parts[0] != 'xifan' ||
        !parts.skip(1).every(_id.hasMatch)) {
      throw const FormatException('Invalid series identity');
    }
    final result = await _transport('/xifan/drama/getDuanjuInfo', {
      'source': parts[1],
      'duanjuId': parts[2],
    });
    if ('${result['source']}' != parts[1] ||
        '${result['duanjuId']}' != parts[2] ||
        result['episodeList'] is! List) {
      throw const FormatException('Mismatched source response');
    }
    return result;
  }

  @override
  Future<Drama> fetchDetails(Drama summary) async {
    final result = await _detail(summary.id);
    final episodes =
        _objects(result['episodeList'])
            .where((item) => _id.hasMatch('${item['episodeId']}'))
            .map(
              (item) => Episode(
                id: '${item['episodeId']}',
                title: _text(item['title']),
                number: _integer(item['index']),
                locked: item['unlock'] != true,
              ),
            )
            .toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    if (episodes.isEmpty) throw const FormatException('Empty episodes');
    return Drama(
      id: summary.id,
      title: _text(result['title']).isEmpty
          ? summary.title
          : _text(result['title']),
      subtitle: summary.subtitle,
      category: summary.category,
      tags: summary.tags,
      description: _text(result['desc']).isEmpty
          ? summary.description
          : _text(result['desc']),
      poster: _https(result['coverImageUrl']).isEmpty
          ? summary.poster
          : _https(result['coverImageUrl']),
      color: summary.color,
      episodes: episodes,
      declaredEpisodeCount: episodes.length,
      isDemo: false,
      sourceName: '西饭',
    );
  }

  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async {
    // Fetch fresh access state every time; never trust a cached unlock marker.
    final result = await _detail(dramaId);
    final episode = _objects(result['episodeList'])
        .where((item) => '${item['episodeId']}' == episodeId)
        .firstOrNull;
    if (episode == null) throw const PlaybackUnavailable('来源未找到这一集，请返回刷新');
    if (episode['unlock'] != true) {
      throw const PlaybackUnavailable('这一集当前锁定，请在西饭官方平台确认可看范围');
    }
    final url = _https(episode['playUrl']);
    if (url.isEmpty) throw const PlaybackUnavailable('来源暂未提供可播放地址');
    return PlaybackSource(
      uri: Uri.parse(url),
      attribution: '片源：西饭 · 可看范围由来源平台决定',
    );
  }
}
