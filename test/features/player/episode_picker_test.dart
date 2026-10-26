import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zovv/features/drama/domain/drama.dart';
import 'package:zovv/features/player/presentation/widgets/episode_picker.dart';

void main() {
  testWidgets(
    'long series opens at current group and supports bounded navigation',
    (tester) async {
      final episodes = List.generate(
        1000,
        (i) => Episode(id: '$i', title: '', number: i + 1, locked: i == 94),
      );
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodePicker(
              episodes: episodes,
              current: 93,
              onSelected: (index) => selected = index,
            ),
          ),
        ),
      );
      expect(find.text('51–100 集'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('94'),
        160,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('94'));
      expect(selected, 93);
      await tester.tap(find.text('95'));
      expect(selected, 93);
      await tester.tap(find.byTooltip('后 50 集'));
      await tester.pumpAndSettle();
      expect(find.text('101–150 集'), findsOneWidget);
      await tester.tap(find.byTooltip('前 50 集'));
      await tester.pumpAndSettle();
      expect(find.text('51–100 集'), findsOneWidget);
    },
  );
}
