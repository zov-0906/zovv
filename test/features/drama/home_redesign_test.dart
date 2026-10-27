import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/core/widgets/zovv_refresh.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/presentation/drama_shell.dart';
import 'package:zovv/features/drama/application/drama_library_controller.dart';
import 'package:zovv/features/drama/domain/watch_progress.dart';
import 'package:zovv/features/startup/domain/startup_config.dart';
import 'package:zovv/features/startup/presentation/startup_screen.dart';

import '../startup/memory_library_storage.dart';

void main() {
  test('clearing history preserves favorites after reload', () async {
    final storage = MemoryLibraryStorage();
    final library = DramaLibraryController(storage);
    await library.load();
    final drama = DemoDramaRepository.catalog.first;
    library.remember(drama);
    library.toggleFavorite(drama.id);
    library.record(
      WatchProgress(
        dramaId: drama.id,
        episodeIndex: 1,
        positionSeconds: 23,
        updatedAt: DateTime.now(),
      ),
    );
    library.clearHistory();
    await library.persist();
    final restored = DramaLibraryController(storage);
    await restored.load();
    expect(restored.recent, isEmpty);
    expect(restored.favorites, contains(drama.id));
    library.dispose();
    restored.dispose();
  });
  testWidgets('small screen My supports larger text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.6)),
          child: child!,
        ),
        home: DramaShell(
          repository: DemoDramaRepository(),
          storage: MemoryLibraryStorage(),
          onReplayStartup: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'discover scroll changes navigation to top and My keeps page state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DramaShell(
            repository: DemoDramaRepository(),
            storage: MemoryLibraryStorage(),
            onReplayStartup: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      expect(find.text('回顶部'), findsOneWidget);
      final headers = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      expect(headers.single.pinned, isTrue);
      await tester.tap(find.byKey(const Key('nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('播放偏好'), findsOneWidget);
      final speedRow = find
          .ancestor(of: find.text('默认倍速'), matching: find.byType(InkWell))
          .first;
      final arrow = find.descendant(
        of: speedRow,
        matching: find.byIcon(Icons.chevron_right_rounded),
      );
      expect(
        tester.getRect(speedRow).right - tester.getRect(arrow).right,
        closeTo(2, 1),
      );
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      expect(find.text('回顶部'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nav-0')));
      await tester.pumpAndSettle();
      expect(find.text('回顶部'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('custom refresh coalesces repeated requests', (tester) async {
    final done = Completer<void>();
    var count = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: ZovvRefresh(
            onRefresh: () {
              count++;
              return done.future;
            },
            child: ListView(children: const [Text('feed')]),
          ),
        ),
      ),
    );
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    final one = refresh.onRefresh(), two = refresh.onRefresh();
    expect(count, 1);
    done.complete();
    await Future.wait([one, two]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('startup completion waits for real preparation', (tester) async {
    final ready = ValueNotifier(false);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupScreen(
          config: const StartupConfig(fullSequence: false),
          ready: ready,
          onComplete: () => completed = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(completed, isFalse);
    expect(find.text('正在整理本地记录与首页…'), findsOneWidget);
    ready.value = true;
    await tester.pump();
    await tester.pump();
    expect(completed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    ready.dispose();
  });
}
