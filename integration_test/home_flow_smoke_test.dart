import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zovv/app/zovv_app.dart';
import 'package:zovv/features/drama/data/demo_drama_repository.dart';
import 'package:zovv/features/drama/domain/watch_progress.dart';
import 'package:zovv/features/startup/data/startup_history.dart';

class _Storage implements LibraryStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

class _History implements StartupHistory {
  @override
  Future<bool> hasCompleted() async => false;
  @override
  Future<void> markCompleted() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('startup, sticky feed, top navigation and local My settings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ZovvApp(
        history: _History(),
        hasCompletedStartup: false,
        dramaRepository: DemoDramaRepository(),
        libraryStorage: _Storage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('startup-start')));
    await tester.pumpAndSettle();
    expect(find.text('好故事，慢慢看。'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();
    expect(find.text('回顶部'), findsOneWidget);
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
  });
}
