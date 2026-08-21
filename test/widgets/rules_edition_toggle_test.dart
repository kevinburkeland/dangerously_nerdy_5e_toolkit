import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/common/diff_highlight_banner.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/common/edition_diff_badge.dart';

void main() {
  group('RulesEditionToggle Tests', () {
    testWidgets('Renders 2014 and 2024 options with active selection', (tester) async {
      DmRulesEdition selected = DmRulesEdition.v2024;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RulesEditionToggle(
                  currentEdition: selected,
                  onEditionChanged: (newEdition) {
                    setState(() {
                      selected = newEdition;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('2014'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);

      // Tap 2014
      await tester.tap(find.text('2014'));
      await tester.pumpAndSettle();

      expect(selected, DmRulesEdition.v2014);

      // Tap 2024
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();

      expect(selected, DmRulesEdition.v2024);
    });

    testWidgets('Renders dense, expanded, showIcons, and showSubtext variants', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RulesEditionToggle(
              currentEdition: DmRulesEdition.v2014,
              isDense: true,
              isExpanded: true,
              showIcons: true,
              showSubtext: true,
              onEditionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('2014'), findsOneWidget);
      expect(find.text('(5.1 RAW)'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('(5.2 Revised)'), findsOneWidget);
      expect(find.byIcon(Icons.history_edu), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });

  group('Common Diff Widgets Tests', () {
    testWidgets('DiffHighlightBanner renders summary and highlight chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DiffHighlightBanner(
              diffSummary: 'Key mechanical revisions to this rule.',
              diffHighlights: ['Bonus action activation', 'New range limit'],
            ),
          ),
        ),
      );

      expect(find.text('2024 REVISED RULES DIFF HIGHLIGHTS'), findsOneWidget);
      expect(find.text('Key mechanical revisions to this rule.'), findsOneWidget);
      expect(find.text('• Bonus action activation'), findsOneWidget);
      expect(find.text('• New range limit'), findsOneWidget);
    });

    testWidgets('EditionDiffBadge renders and responds to tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditionDiffBadge(
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('2024 Diff'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      await tester.tap(find.byType(EditionDiffBadge));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });
}
