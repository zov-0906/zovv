import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/data/xifan_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';

void main() {
  Map<String, dynamic> listing() => {
    'elements': [
      {
        'contents': [
          {
            'duanjuVo': {
              'source': 'jiuzhou',
              'duanjuId': '1340',
              'title': '测试短剧',
              'total': 95,
              'coverImageUrl': 'https://example.com/cover.webp',
              'desc': '真实来源简介',
              'categories': ['都市'],
            },
          },
        ],
      },
    ],
  };
  test(
    'live source separates summaries from details and preserves locks',
    () async {
      var unlocked = true;
      final repository = XifanDramaRepository(
        transport: (path, query) async {
          if (path.contains('portalPage')) return listing();
          return {
            'source': 'jiuzhou',
            'duanjuId': '1340',
            'title': '测试短剧',
            'episodeList': [
              {
                'episodeId': 'first',
                'index': 1,
                'title': '第一集',
                'unlock': unlocked,
                'playUrl': 'https://example.com/first.mp4',
              },
              {
                'episodeId': 'second',
                'index': 2,
                'title': '第二集',
                'unlock': false,
                'playUrl': 'https://example.com/second.mp4',
              },
            ],
          };
        },
      );
      final summary = (await repository.discover()).single;
      expect(summary.id, 'xifan:jiuzhou:1340');
      expect(summary.episodeCount, 95);
      expect(summary.isDemo, isFalse);
      expect(summary.episodes, isEmpty);
      final detail = await repository.fetchDetails(summary);
      expect(detail.episodes.first.locked, isFalse);
      expect(detail.episodes.last.locked, isTrue);
      expect(
        (await repository.resolveEpisode(summary.id, 'first')).uri.path,
        '/first.mp4',
      );
      unlocked = false;
      await expectLater(
        repository.resolveEpisode(summary.id, 'first'),
        throwsA(isA<PlaybackUnavailable>()),
      );
      await expectLater(
        repository.resolveEpisode(summary.id, 'wrong-id'),
        throwsA(isA<PlaybackUnavailable>()),
      );
    },
  );
  test('search passes keyword and mismatched detail cannot play', () async {
    final repository = XifanDramaRepository(
      transport: (path, query) async {
        if (path.contains('Search')) {
          expect(query['keyword'], '测试');
          return listing();
        }
        return {'source': 'jiuzhou', 'duanjuId': 'another', 'episodeList': []};
      },
    );
    final summary = (await repository.search('测试')).single;
    await expectLater(repository.fetchDetails(summary), throwsFormatException);
    await expectLater(
      repository.resolveEpisode(summary.id, 'first'),
      throwsFormatException,
    );
  });
}
