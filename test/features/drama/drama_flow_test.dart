import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/presentation/drama_shell.dart';

import '../startup/memory_library_storage.dart';

void main() {
  testWidgets(
    'search, details, favorite and library form a small-screen loop',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = MemoryLibraryStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: DramaShell(
            onReplayStartup: () {},
            storage: storage,
            repository: DemoDramaRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('好故事，慢慢看。'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('drama-search')), '长夜');
      await tester.pumpAndSettle();
      expect(find.text('找到 1 个故事'), findsOneWidget);
      await tester.tap(find.byKey(const Key('drama-card-night')));
      await tester.pumpAndSettle();
      expect(find.text('故事简介'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-favorite')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('取消收藏'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('长夜微光'), findsOneWidget);
      await tester.tap(find.byTooltip('取消收藏'));
      await tester.pumpAndSettle();
      expect(find.text('把喜欢的故事留在这里'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('drama-search')), '不存在的剧名');
      await tester.pumpAndSettle();
      expect(find.text('还没有找到这个故事'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
