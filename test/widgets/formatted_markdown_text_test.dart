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

      expect(find.text('Plain text trait description.', findRichText: true), findsOneWidget);
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
      expect(find.textContaining('Darkvision.', findRichText: true), findsOneWidget);
      expect(find.textContaining('You can see in dim light.', findRichText: true), findsOneWidget);
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

      expect(find.textContaining('Resourceful.', findRichText: true), findsOneWidget);
      expect(find.textContaining('Bonus skill proficiency', findRichText: true), findsOneWidget);
      expect(find.textContaining('One origin feat of your choice', findRichText: true), findsOneWidget);
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

      expect(find.textContaining('Rage Feature', findRichText: true), findsOneWidget);
      expect(find.textContaining('Bonus Action', findRichText: true), findsOneWidget);
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

    testWidgets('renders markdown tables as native Table widgets with headers and rows', (tester) async {
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
      expect(find.textContaining('Potion of Healing', findRichText: true), findsOneWidget);
      expect(find.textContaining('Scroll of Shield', findRichText: true), findsOneWidget);
    });

    testWidgets('renders markdown tables embedded in text without double blank lines', (tester) async {
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
      expect(find.textContaining('Roll on the table below:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Boon', findRichText: true), findsOneWidget);
      expect(find.textContaining('+1 to STR', findRichText: true), findsOneWidget);
      expect(find.textContaining('Effects last 1 hour.', findRichText: true), findsOneWidget);
    });

    testWidgets('handles escaped pipes and uneven columns without throwing', (tester) async {
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
      expect(find.textContaining('Option A | Option B', findRichText: true), findsOneWidget);
      expect(find.textContaining('Uneven row with fewer cells', findRichText: true), findsOneWidget);
    });
  });
}
