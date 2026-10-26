import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/data/hongguo_drama_repository.dart';
import 'package:zovv/features/drama/domain/drama.dart';

void main() {
  test(
    'playback cache expiry is carried through to the phone preloader',
    () async {
      final expires = DateTime.now().toUtc().add(const Duration(minutes: 10));
      final repository = HongguoDramaRepository(
        transport: (_, _) async => {
          'url': 'https://example.com/video.mp4',
          'expiresAt': expires.toIso8601String(),
        },
      );
      final result = await repository.resolveEpisode('hongguo:123', '456');
      expect(result.expiresAt, expires);
    },
  );
  const detailSummary = Drama(
    id: 'hongguo:7698294694886788121',
    title: '测试',
    subtitle: '',
    category: '',
    description: '',
    poster: '',
    color: 0,
    episodes: [],
  );
  test('empty details report a useful error and are never cached', () async {
    var calls = 0;
    final repository = HongguoDramaRepository(
      transport: (_, query) async {
        calls++;
        return {
          'series_id': query['sid'],
          'episodes': calls == 1
              ? []
              : [
                  {'id': '7698309376561400856', 'number': 1, 'locked': false},
                ],
        };
      },
    );
    await expectLater(
      repository.fetchDetails(detailSummary),
      throwsA(
        isA<PlaybackUnavailable>().having(
          (error) => error.code,
          'code',
          'EMPTY_EPISODES',
        ),
      ),
    );
    expect((await repository.fetchDetails(detailSummary)).episodes.length, 1);
    expect(calls, 2);
  });
  test('repeated and concurrent details share valid data and preserve stale notice', () async {
    var calls = 0;
    final repository = HongguoDramaRepository(
      transport: (_, query) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return {
          'series_id': query['sid'],
          'description': '完整简介',
          '_meta': {'notice': '显示最近一次成功详情'},
          'episodes': [
            {'id': '7698309376561400856', 'number': 1, 'locked': false},
          ],
        };
      },
    );
    final values = await Future.wait([
      repository.fetchDetails(detailSummary),
      repository.fetchDetails(detailSummary),
    ]);
    expect(calls, 1);
    expect(values.first.detailsNotice, '显示最近一次成功详情');
    expect(values.first.description, '完整简介');
    expect((await repository.fetchDetails(detailSummary)).episodes.length, 1);
    expect(calls, 1);
  });
  test('accepts only the exact local trial media route over HTTP', () async {
    final token = List.filled(48, 'a').join();
    var url = 'http://127.0.0.1:8765/media/$token.mp4';
    final repository = HongguoDramaRepository(
      transport: (_, _) async => {'url': url},
    );
    final source = await repository.resolveEpisode(
      'hongguo:7698294694886788121',
      '7698309376561400856',
    );
    expect(source.uri.toString(), url);
    for (final invalid in [
      'http://example.com/media/$token.mp4',
      'http://127.0.0.1:8766/media/$token.mp4',
      'http://127.0.0.1:8765/other/$token.mp4',
      'http://user@127.0.0.1:8765/media/$token.mp4',
    ]) {
      url = invalid;
      await expectLater(
        repository.resolveEpisode(
          'hongguo:7698294694886788121',
          '7698309376561400856',
        ),
        throwsA(isA<PlaybackUnavailable>()),
      );
    }
  });
  test(
    'Redfruit App catalog preserves long string IDs and source identity',
    () async {
      final repository = HongguoDramaRepository(
        transport: (path, query) async {
          expect(path, '/catalog');
          expect(query['category'], 'comic-drama');
          return {
            'genres': [
              {'slug': 'cate_7', 'label': '玄幻'},
            ],
            'results': [
              {
                'series_id': '7698294694886788121',
                'series_title': '和离后我带女儿横扫魔域',
                'episode_count': 1000,
                'cover': 'https://example.com/cover.jpg',
                'tags': ['第1季', '8602万', '玄幻'],
              },
            ],
          };
        },
      );
      final drama = (await repository.discover()).single;
      expect(drama.id, 'hongguo:7698294694886788121');
      expect(drama.sourceName, '红果');
      expect(drama.episodeCount, 1000);
      expect(drama.category, '玄幻');
      expect(repository.genres['cate_7'], '玄幻');
    },
  );
  test('detail validates identity and keeps protection markers', () async {
    final repository = HongguoDramaRepository(
      transport: (path, query) async => {
        'series_id': query['sid'],
        'episodes': [
          {'id': '7698309376561400856', 'number': 1, 'locked': false},
          {'id': '7698309376561400857', 'number': 2, 'locked': true},
        ],
      },
    );
    const summary = Drama(
      id: 'hongguo:7698294694886788121',
      title: '红果测试',
      subtitle: '',
      category: '漫剧',
      description: '',
      poster: '',
      color: 0,
      episodes: [],
    );
    final drama = await repository.fetchDetails(summary);
    expect(drama.episodes.first.locked, isFalse);
    expect(drama.episodes.last.locked, isTrue);
  });
  test(
    'encrypted App media remains blocked pending explicit approval',
    () async {
      final repository = HongguoDramaRepository(
        transport: (path, query) async => {
          'requiresMediaApproval': true,
          'error': 'App 加密媒体处理尚待确认',
        },
      );
      await expectLater(
        repository.resolveEpisode(
          'hongguo:7698294694886788121',
          '7698309376561400856',
        ),
        throwsA(isA<PlaybackUnavailable>()),
      );
    },
  );
  test('prefetch, public comments and sequel lookup round-trip', () async {
    final calls = <String>[];
    final repository = HongguoDramaRepository(
      transport: (path, query) async {
        calls.add(path);
        return switch (path) {
          '/prefetch' => {'queued': true},
          '/comments' => {
            'total': 2,
            'notice': '公开评论只读',
            'items': [
              {'author': '阿甲', 'content': '好看', 'likes': 3},
              {'author': '阿乙', 'content': '   '},
            ],
          },
          '/sequel' => {
            'results': [
              {
                'series_id': '7698309376561400999',
                'series_title': '测试短剧 第二季',
                'episode_count': 12,
                'cover': 'https://example.com/cover.jpg',
              },
            ],
          },
          _ => <String, dynamic>{},
        };
      },
    );
    repository.prefetchEpisode(
      'hongguo:7698294694886788121',
      '7698309376561400856',
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, contains('/prefetch'));

    final digest = await repository.fetchComments(
      'hongguo:7698294694886788121',
      '7698309376561400856',
    );
    expect(digest.items.single.author, '阿甲');
    expect(digest.items.single.content, '好看');
    expect(digest.total, 2);
    expect(digest.notice, '公开评论只读');

    final sequels = await repository.findSequels('hongguo:7698294694886788121');
    expect(sequels.single.id, 'hongguo:7698309376561400999');
    expect(sequels.single.title, '测试短剧 第二季');
    expect(sequels.single.episodeCount, 12);
    expect(sequels.single.sourceName, '红果');
  });
  test(
    'catalog pages report hasMore and search keeps the source notice',
    () async {
      final repository = HongguoDramaRepository(
        transport: (path, query) async {
          if (path == '/catalog') {
            final page = '${query['page']}';
            return {
              'results': [
                {
                  'series_id': '76980$page',
                  'series_title': '第$page页',
                  'episode_count': 10,
                  'tags': ['玄幻'],
                },
              ],
              'hasMore': page == '1',
              'genres': [
                {'slug': 'cate_7', 'label': '玄幻'},
              ],
            };
          }
          if (path == '/search') {
            return {
              'results': [
                {
                  'series_id': '769811',
                  'series_title': '命中',
                  'episode_count': 1,
                },
              ],
              'notice': '来源搜索暂不可用，以下为本地已收录目录的匹配结果',
            };
          }
          return <String, dynamic>{};
        },
      );
      final first = await repository.discoverPage();
      expect(first.page, 1);
      expect(first.hasMore, isTrue);
      expect(first.dramas.single.id, 'hongguo:769801');
      expect(repository.genres['cate_7'], '玄幻');
      final second = await repository.discoverPage(page: 2);
      expect(second.page, 2);
      expect(second.hasMore, isFalse);
      expect(second.dramas.single.id, 'hongguo:769802');
      final outcome = await repository.searchWithNotice('命中');
      expect(outcome.dramas.single.title, '命中');
      expect(outcome.notice, contains('本地已收录'));
    },
  );
  test(
    'sequel lookup surfaces the source note instead of a blank list',
    () async {
      final repository = HongguoDramaRepository(
        transport: (path, query) async => {
          'results': <Object>[],
          'error': '来源搜索暂不可用',
        },
      );
      await expectLater(
        repository.findSequels('hongguo:7698294694886788121'),
        throwsA(
          isA<PlaybackUnavailable>().having(
            (error) => error.message,
            'message',
            contains('来源搜索暂不可用'),
          ),
        ),
      );
    },
  );
}
