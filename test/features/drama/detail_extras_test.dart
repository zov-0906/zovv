import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/core/theme/app_theme.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/drama/domain/episode_extras.dart';
import 'package:zovv/features/drama/presentation/drama_detail_screen.dart';

import '../startup/memory_library_storage.dart';

const testDrama = Drama(
  id: 'hongguo:7698294694886788121',
  title: '测试漫剧',
  subtitle: '都市 · 逆袭',
  category: '都市',
  description: '仅用于详情页附加功能测试的简介。',
  poster: '',
  color: 0xFF647BA4,
  episodes: [Episode(id: '7698309376561400856', title: '第 1 集', number: 1)],
  declaredEpisodeCount: 1,
  isDemo: false,
  sourceName: '红果',
);

class ExtrasRepository
    implements DramaRepository, EpisodeCommentSource, SequelSource {
  @override
  Future<List<Drama>> discover() async => const [testDrama];
  @override
  Future<PlaybackSource> resolveEpisode(
    String dramaId,
    String episodeId,
  ) async => throw const PlaybackUnavailable('测试占位');
  @override
  Future<CommentDigest> fetchComments(String dramaId, String episodeId) async =>
      const CommentDigest(
        items: [
          EpisodeComment(author: '阿甲', content: '这一集节奏很好', likes: 7),
          EpisodeComment(author: '阿乙', content: '等更新'),
        ],
        total: 2,
        notice: '公开评论只读',
      );
  @override
  Future<List<Drama>> findSequels(String dramaId) async => const [];
}

void main() {
  testWidgets('detail exposes share, favorite, comments and sequel actions', (
    tester,
  ) async {
    final repository = ExtrasRepository();
    final library = DramaLibraryController(MemoryLibraryStorage());
    addTearDown(library.dispose);
    await library.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DramaDetailScreen(
          drama: testDrama,
          repository: repository,
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('公开评论，只读。收藏仅保存在本机。'), findsOneWidget);
    expect(find.text('查找下一季'), findsOneWidget);
    expect(find.text('复制分享链接'), findsOneWidget);
    expect(find.text('收藏到本机'), findsOneWidget);
    expect(find.text('查看公开剧评'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('收藏到本机'));
    await tester.pumpAndSettle();
    expect(library.favorites, contains(testDrama.id));
    expect(find.text('已收藏到本机'), findsOneWidget);

    await tester.tap(find.text('查看公开剧评'));
    await tester.pumpAndSettle();
    expect(find.text('公开剧评'), findsOneWidget);
    expect(find.text('这一集节奏很好'), findsOneWidget);
    expect(find.text('公开评论只读'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
