import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/srd_summons_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/theme/app_theme.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spell_reference.dart';

void main() {
  testWidgets('SpellReferenceWidget renders responsive creature profile cards', (WidgetTester tester) async {
    final wolfPreset = SrdSummonsLibrary.allPresets.firstWhere((p) => p.id == 'conjure_animals');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SpellReferenceWidget(initialPreset: wolfPreset),
        ),
      ),
    );

    expect(find.text('CONJURE ANIMALS CREATURE PROFILES'), findsOneWidget);
    expect(find.text('Wolf'), findsOneWidget);
    expect(find.text('Medium • CR 1/4'), findsWidgets);
    expect(find.textContaining('HP 11'), findsWidgets);
    expect(find.textContaining('AC 12'), findsWidgets);
    expect(find.textContaining('ATK +4'), findsWidgets);
    expect(find.textContaining('Pack Tactics'), findsWidgets);
  });
}
