import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ports/i_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_upcast_sheet.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/spellbook/spell_card.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_sheet/interactive_spell_tile.dart';
import 'package:dangerously_nerdy_5e_toolkit/screens/character_sheet/abilities_and_traits_tab.dart';

class _FakeRepo implements ICharacterRepository {
  Character? saved;
  @override
  Future<List<Character>> saveCharacter(Character character) async {
    saved = character;
    return [character];
  }

  @override
  Future<List<Character>> loadCharacters() async => saved != null ? [saved!] : [];
  @override
  Future<String?> loadActiveCharacterId() async => saved?.id.slug;
  @override
  Future<void> saveActiveCharacterId(String slug) async {}
  @override
  Future<void> clearActiveCharacterId() async {}
  @override
  Future<void> saveRoster(List<Character> roster) async {}
  @override
  Future<List<Character>> deleteCharacter(String slug) async => [];
  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async => saved != null ? [saved!] : [];
  @override
  Future<Character?> getCharacter(String id) async => saved;
  @override
  Future<void> saveCharacters(List<Character> characters) async {
    if (characters.isNotEmpty) saved = characters.last;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Character baseCharacter;
  late _FakeRepo fakeRepo;

  setUp(() {
    fakeRepo = _FakeRepo();
    baseCharacter = const Character(
      id: EntityId(slug: 'hero-caster', ruleset: RulesetVersion.v2024),
      name: 'Eldritch Scholar',
      speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'High Elf'),
      progression: CharacterProgression(
        classes: [
          ClassLevelProgression(
            classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
            level: 3,
            hitDie: 'd10',
            isStartingClass: true,
          ),
        ],
      ),
      baseScores: AbilityScores(
        strength: 14,
        dexterity: 16,
        constitution: 14,
        intelligence: 18,
        wisdom: 12,
        charisma: 10,
      ),
      resources: CharacterResourcePool(
        currentHp: 28,
        spellSlots: SpellSlotPool(
          maxSlots: {1: 4, 2: 3, 3: 2, 4: 1},
          currentSlots: {1: 4, 2: 3, 3: 0, 4: 1}, // 3rd level exhausted
        ),
        customResourcesCurrent: {'action surge': 1, 'second wind': 1},
        customResourcesMax: {'action surge': 1, 'second wind': 1},
      ),
    );
  });

  group('SpellUpcastSheet UI & Accessibility Tests', () {
    testWidgets('Renders actionable rows with >= spellLevel, disables depleted slots, min 48dp height', (tester) async {
      int? selectedSlot;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedSlot = await SpellUpcastSheet.show(
                    context,
                    spellName: 'Misty Step',
                    spellLevel: 2,
                    resources: baseCharacter.resources,
                  );
                },
                child: const Text('Open Upcast'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Upcast'));
      await tester.pumpAndSettle();

      // Title header
      expect(find.text('Cast Misty Step'), findsOneWidget);

      // Should show slots for level 2, 3, 4 (since spellLevel is 2)
      // Level 1 slot should NOT be shown
      expect(find.text('1st Level Slot'), findsNothing);
      expect(find.text('2nd Level Slot'), findsOneWidget);
      expect(find.text('3rd Level Slot'), findsOneWidget);
      expect(find.text('4th Level Slot'), findsOneWidget);

      // Verify 3rd level is DEPLETED (currentSlots is 0)
      expect(find.text('DEPLETED'), findsOneWidget);
      expect(find.text('0 of 2 slots remaining'), findsOneWidget);

      // Tap depleted 3rd level row -> should not select or pop
      await tester.tap(find.text('3rd Level Slot'));
      await tester.pump();
      expect(find.text('Cast Misty Step'), findsOneWidget); // still open

      // Verify touch target min 48dp on 2nd level row
      final row2Finder = find.ancestor(
        of: find.text('2nd Level Slot'),
        matching: find.byType(ConstrainedBox),
      );
      final box = tester.renderObject<RenderBox>(row2Finder.first);
      expect(box.size.height, greaterThanOrEqualTo(48.0));

      // Tap 4th-level upcast row -> should select 4 and pop
      await tester.tap(find.text('4th Level Slot'));
      await tester.pumpAndSettle();

      expect(selectedSlot, equals(4));
    });

    testWidgets('Dismissing SpellUpcastSheet returns null gracefully', (tester) async {
      int? selectedSlot = 999;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedSlot = await SpellUpcastSheet.show(
                    context,
                    spellName: 'Fireball',
                    spellLevel: 3,
                    resources: baseCharacter.resources,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(selectedSlot, isNull);
    });
  });

  group('InteractiveSpellTile & SpellCard Upcasting Flow Tests', () {
    testWidgets('Cantrips roll immediately without triggering upcast bottom sheet', (tester) async {
      final controller = CharacterSheetController(character: baseCharacter, persistenceService: fakeRepo);

      const cantrip = Spell(
        id: EntityId(slug: 'fire-bolt', ruleset: RulesetVersion.v2024),
        name: 'Fire Bolt',
        level: 0,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '120 ft',
        components: SpellComponents(),
        descriptionMarkdown: 'Ranged spell attack. 1d10 fire damage.',
        damageMath: [
          EvaluationMath(
            diceFormula: '1d10',
            damageType: DamageType.fire,
            isAttackRoll: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveSpellTile(
              spell: cantrip,
              controller: controller,
              isCantrip: true,
            ),
          ),
        ),
      );

      // Tap the tile to execute cantrip action
      await tester.tap(find.text('Fire Bolt'));
      await tester.pumpAndSettle();

      // Verify upcast modal did NOT open
      expect(find.text('Select casting or upcast slot'), findsNothing);
      expect(find.byType(SpellUpcastSheet), findsNothing);

      // Spell slots unchanged
      expect(controller.character.resources.spellSlots.currentSlots[1], equals(4));
    });

    testWidgets('Leveled spell triggers upcast sheet, selecting 4th level decrements 4th leaving 2nd untouched', (tester) async {
      final controller = CharacterSheetController(character: baseCharacter, persistenceService: fakeRepo);

      const leveledSpell = Spell(
        id: EntityId(slug: 'scorching-ray', ruleset: RulesetVersion.v2024),
        name: 'Scorching Ray',
        level: 2,
        school: 'evocation',
        castingTime: CastingTime(cost: 1, actionType: ActionType.action),
        duration: SpellDuration(type: DurationType.instantaneous),
        range: '120 ft',
        components: SpellComponents(),
        descriptionMarkdown: 'Make three ranged spell attacks. Each deals 2d6 fire damage.',
        damageMath: [
          EvaluationMath(
            diceFormula: '2d6',
            damageType: DamageType.fire,
            scalingFormula: '+1d6 per slot above 2nd',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveSpellTile(
              spell: leveledSpell,
              controller: controller,
            ),
          ),
        ),
      );

      // Tap tile to cast
      await tester.tap(find.text('Scorching Ray'));
      await tester.pumpAndSettle();

      // Bottom sheet should be visible
      expect(find.byType(SpellUpcastSheet), findsOneWidget);
      expect(find.text('Cast Scorching Ray'), findsOneWidget);

      // Select 4th Level Slot (+2 UPCAST)
      await tester.tap(find.text('4th Level Slot'));
      await tester.pumpAndSettle();

      // 4th level slot decremented from 1 to 0
      expect(controller.character.resources.spellSlots.currentSlots[4], equals(0));
      // 2nd level slot left untouched at 3
      expect(controller.character.resources.spellSlots.currentSlots[2], equals(3));
    });

    testWidgets('SpellCard Cast button invokes upcasting bottom sheet on Level 1+ spell', (tester) async {
      final controller = CharacterSheetController(character: baseCharacter, persistenceService: fakeRepo);
      final spellItem = SpellbookLibrary.getSpellById('shield')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpellCard(
              spell: spellItem,
              edition: DmRulesEdition.v2024,
              isPinned: false,
              onTogglePin: () {},
              onTap: () {},
              controller: controller,
            ),
          ),
        ),
      );

      // Cast button exists and meets touch target
      final castButton = find.text('Cast');
      expect(castButton, findsOneWidget);

      await tester.tap(castButton);
      await tester.pumpAndSettle();

      // Modal bottom sheet opens
      expect(find.byType(SpellUpcastSheet), findsOneWidget);
      expect(find.text('Cast Shield'), findsOneWidget);

      // Select 1st Level Slot
      await tester.tap(find.text('1st Level Slot'));
      await tester.pumpAndSettle();

      // Level 1 slot decrements from 4 to 3
      expect(controller.character.resources.spellSlots.currentSlots[1], equals(3));
    });
  });

  group('AbilitiesAndTraitsTab Component Tests', () {
    testWidgets('Renders Active Features, tracking pips, decrement button, passive traits, and feats', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = CharacterSheetController(character: baseCharacter, persistenceService: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AbilitiesAndTraitsTab(controller: controller),
          ),
        ),
      );

      // Headers exist
      expect(find.text('ACTIVE FEATURES & CHARGES'), findsOneWidget);
      expect(find.text('PASSIVE TRAITS & LINEAGE'), findsOneWidget);
      expect(find.text('FEATS (0)'), findsOneWidget);

      // Active feature Action Surge appears
      expect(find.text('Action Surge'), findsOneWidget);
      // Tap decrement charge button for Second Wind (first)
      final decrementBtn = find.byIcon(Icons.remove_circle_outline);
      expect(decrementBtn, findsWidgets);

      await tester.tap(decrementBtn.first);
      await tester.pumpAndSettle();
      expect(controller.getResourceCharges('Second Wind'), equals(0));

      // Tap decrement charge button for Action Surge (second)
      await tester.tap(decrementBtn.at(1));
      await tester.pumpAndSettle();
      expect(controller.getResourceCharges('Action Surge'), equals(0));

      // Tap increment button to recover Action Surge
      final incrementBtn = find.byIcon(Icons.add_circle_outline);
      await tester.tap(incrementBtn.at(1));
      await tester.pumpAndSettle();
      expect(controller.getResourceCharges('Action Surge'), equals(1));

      // Passive traits exist (High Elf Traits)
      expect(find.text('High Elf Traits'), findsOneWidget);
    });
  });
}
