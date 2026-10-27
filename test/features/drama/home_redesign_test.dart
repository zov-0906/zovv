import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/core/widgets/zovv_refresh.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/presentation/drama_shell.dart';
import 'package:zovv/features/startup/domain/startup_config.dart';
import 'package:zovv/features/startup/presentation/startup_screen.dart';

import '../startup/memory_library_storage.dart';

void main() {
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
