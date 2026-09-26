import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/common/formatted_markdown_text.dart';

void main() {
  group('FormattedMarkdownText Widget Tests', () {
    testWidgets('renders plain text without markdown tokens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText('Plain text trait description.'),
          ),
        ),
      );

      expect(find.text('Plain text trait description.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('renders bold text tokens with bold TextStyle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(
              '**Darkvision.** You can see in dim light.',
              boldColor: Colors.cyanAccent,
            ),
          ),
        ),
      );

      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);

      // Verify the parsed text contains Darkvision. and body text
      expect(find.textContaining('Darkvision.', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('You can see in dim light.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('renders bullet lists and multiple paragraphs', (tester) async {
      const sample = '''
**Resourceful.** You gain Heroic Inspiration whenever you finish a Long Rest.

- Bonus skill proficiency
- One origin feat of your choice
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(sample),
          ),
        ),
      );

      expect(find.textContaining('Resourceful.', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Bonus skill proficiency', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('One origin feat of your choice',
              findRichText: true),
          findsOneWidget);
    });

    testWidgets('renders inline code and headings', (tester) async {
      const sample = '''
### Rage Feature
In battle, you enter a rage using `Bonus Action`.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(sample),
          ),
        ),
      );

      expect(find.textContaining('Rage Feature', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Bonus Action', findRichText: true),
          findsOneWidget);
    });

    testWidgets('handles empty string gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(''),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'renders markdown tables as native Table widgets with headers and rows',
        (tester) async {
      const tableSample = '''
| d4 | Result |
|---|---|
| 1 | Potion of Healing |
| 2 | Scroll of Shield |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(tableSample),
          ),
        ),
      );

      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('d4', findRichText: true), findsOneWidget);
      expect(find.textContaining('Potion of Healing', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Scroll of Shield', findRichText: true),
          findsOneWidget);
    });

    testWidgets(
        'renders markdown tables embedded in text without double blank lines',
        (tester) async {
      const embeddedSample = '''
Roll on the table below:
| d6 | Boon |
|---|---|
| 1 | +1 to STR |
| 2 | +1 to DEX |
Effects last 1 hour.
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(embeddedSample),
          ),
        ),
      );

      expect(find.byType(Table), findsOneWidget);
      expect(
          find.textContaining('Roll on the table below:', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('Boon', findRichText: true), findsOneWidget);
      expect(
          find.textContaining('+1 to STR', findRichText: true), findsOneWidget);
      expect(find.textContaining('Effects last 1 hour.', findRichText: true),
          findsOneWidget);
    });

    testWidgets('handles escaped pipes and uneven columns without throwing',
        (tester) async {
      const escapedSample = '''
| Roll | Description | Notes |
|:---|:---:|---:|
| 1 | Option A \\| Option B | Extra |
| 2 | Uneven row with fewer cells |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(escapedSample),
          ),
        ),
      );

      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('Option A | Option B', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('Uneven row with fewer cells',
              findRichText: true),
          findsOneWidget);
    });

    testWidgets('respects maxLines and overflow on Text.rich preview',
        (tester) async {
      const sample =
          '**Bold Title.** Long description paragraph that needs truncation in card previews.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(
              sample,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.byType(Text));
      expect(textWidget.maxLines, equals(2));
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets(
        'wide table inside narrow card renders without overflow and enables horizontal scrolling',
        (tester) async {
      const wideTableSample = '''
| Level | Proficiency | Features | Cantrips | Spells Known | 1st | 2nd | 3rd | 4th | 5th |
|---|---|---|---|---|---|---|---|---|---|
| 1st | +2 | Spellcasting, Arcane Recovery | 3 | — | 2 | — | — | — | — |
| 2nd | +2 | Arcane Tradition | 3 | — | 3 | — | — | — | — |
''';

      // Constrain to narrow card width (280dp)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: FormattedMarkdownText(wideTableSample),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Verify no RenderFlex overflow exception was thrown
      expect(tester.takeException(), isNull);

      // Verify Table widget and horizontal scrollable are present
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);

      final scrollableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(scrollableFinder, findsOneWidget);

      // Verify the table content extends beyond the narrow 280dp card
      final tableSize = tester.getSize(find.byType(Table));
      expect(tableSize.width, greaterThan(280.0));

      // Test horizontal dragging across the table
      await tester.drag(scrollableFinder, const Offset(-150, 0));
      await tester.pumpAndSettle();

      // Headers at the end of the table should be in view after scroll
      expect(find.textContaining('5th', findRichText: true), findsOneWidget);
    });

    testWidgets(
        'horizontal table drag inside PressableCard does not trigger card onTap',
        (tester) async {
      bool cardTapped = false;
      const wideTableSample = '''
| Column 1 | Column 2 | Column 3 | Column 4 | Column 5 | Column 6 |
|---|---|---|---|---|---|
| Value A1 | Value A2 | Value A3 | Value A4 | Value A5 | Value A6 |
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Card(
                  child: InkWell(
                    onTap: () => cardTapped = true,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: FormattedMarkdownText(wideTableSample),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final scrollableFinder = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      );
      expect(scrollableFinder, findsOneWidget);

      // Drag horizontally to scroll table
      await tester.drag(scrollableFinder, const Offset(-100, 0));
      await tester.pumpAndSettle();

      // Dragging horizontally must NOT trigger card's onTap
      expect(cardTapped, isFalse);
    });

    testWidgets(
        'renders tables without explicit separator row as scrollable tables',
        (tester) async {
      const relaxedTable = '''
| Option | Cost | Weight |
| Abacus | 2 gp | 2 lb. |
| Bedroll | 1 gp | 7 lb. |
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FormattedMarkdownText(relaxedTable),
          ),
        ),
      );

      expect(find.byType(Table), findsOneWidget);
      expect(find.textContaining('Abacus', findRichText: true), findsOneWidget);
      expect(find.textContaining('2 gp', findRichText: true), findsOneWidget);
    });
  });
}
