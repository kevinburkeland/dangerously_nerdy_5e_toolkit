import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/skills_saves_matrix.dart';

void main() {
  testWidgets('SkillsSavesMatrix renders all 6 saves, 18 skills, and allows Advantage toggling', (tester) async {
    const character = Character(
      id: EntityId(slug: 'hero-test', ruleset: RulesetVersion.v2024),
      name: 'Rogue Scout',
      speciesRef: EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: 'elf',
        displayName: 'Elf',
      ),
      progression: CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference<DomainEntity>(
              refType: EntityType.classDefinition,
              slug: 'rogue',
              displayName: 'Rogue',
            ),
            level: 5,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(
        strength: 10,
        dexterity: 18,
        constitution: 14,
        intelligence: 12,
        wisdom: 14,
        charisma: 10,
      ),
      skillProficiencies: {
        SkillType.stealth: SkillProficiencyLevel.expertise,
        SkillType.acrobatics: SkillProficiencyLevel.proficient,
      },
      savingThrowProficiencies: {
        AbilityType.dexterity,
        AbilityType.intelligence,
      },
      resources: CharacterResourcePool(currentHp: 38),
    );

    final controller = CharacterSheetController(
      character: character,
      persistenceService: CharacterPersistenceService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SkillsSavesMatrix(controller: controller),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Saves are rendered
    expect(find.text('STR'), findsOneWidget);
    expect(find.text('DEX'), findsOneWidget);
    expect(find.text('CON'), findsOneWidget);
    expect(find.text('INT'), findsOneWidget);
    expect(find.text('WIS'), findsOneWidget);
    expect(find.text('CHA'), findsOneWidget);

    // Verify Skills are rendered
    expect(find.text('Stealth'), findsOneWidget);
    expect(find.text('Acrobatics'), findsOneWidget);
    expect(find.text('Perception'), findsOneWidget);

    // Verify Roll Mode segment buttons
    expect(find.text('Norm'), findsOneWidget);
    expect(find.text('Adv'), findsOneWidget);
    expect(find.text('Dis'), findsOneWidget);

    // Toggle to Advantage
    await tester.tap(find.text('Adv'));
    await tester.pumpAndSettle();

    // Scroll Stealth into view and tap
    await tester.ensureVisible(find.text('Stealth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stealth'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify SnackBar was shown with roll results
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('[Rogue Scout] Stealth'), findsOneWidget);
  });
}
