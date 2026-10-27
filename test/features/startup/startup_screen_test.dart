import 'package:zovv/features/drama/data/demo_drama_repository.dart';

import 'memory_library_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/app/zovv_app.dart';
import 'package:zovv/features/startup/data/startup_history.dart';

class MemoryHistory implements StartupHistory {
  bool completed = false;
  @override
  Future<bool> hasCompleted() async => completed;
  @override
  Future<void> markCompleted() async {
    completed = true;
  }
}

Future<void> advance(WidgetTester tester, int milliseconds) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('small screen welcome, home and replay work', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final history = MemoryHistory();
    await tester.pumpWidget(
      ZovvApp(
        history: history,
        hasCompletedStartup: false,
        libraryStorage: MemoryLibraryStorage(),
        dramaRepository: DemoDramaRepository(),
      ),
    );
    await advance(tester, 2000);
    expect(find.byKey(const Key('startup-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('startup-start')));
    await tester.pump();
    await tester.pump();
    expect(history.completed, isTrue);
    expect(find.text('好故事，慢慢看。'), findsOneWidget);
    await tester.tap(find.byTooltip('关于 ZOVV'));
    await tester.pumpAndSettle();
    expect(find.text('经典启动演出'), findsNothing);
    await tester.tap(find.text('重播开屏演示'));
    await tester.pump();
    await advance(tester, 2000);
    expect(find.byKey(const Key('startup-start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('startup-skip')));
    await tester.pump();
    await tester.pump();
    expect(find.text('好故事，慢慢看。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'returning launch pauses in background and completes after resume',
    (tester) async {
      final history = MemoryHistory();
      await tester.pumpWidget(
        ZovvApp(
          history: history,
          hasCompletedStartup: true,
          libraryStorage: MemoryLibraryStorage(),
          dramaRepository: DemoDramaRepository(),
        ),
      );
      await advance(tester, 400);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(history.completed, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await advance(tester, 2200);
      expect(history.completed, isTrue);
      expect(find.byKey(const Key('startup-skip')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
