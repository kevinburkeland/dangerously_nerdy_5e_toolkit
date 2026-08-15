import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/dm_reference/rules_edition_toggle.dart';

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

    testWidgets('Renders dense variant correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RulesEditionToggle(
              currentEdition: DmRulesEdition.v2014,
              isDense: true,
              onEditionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('2014'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
    });
  });
}
