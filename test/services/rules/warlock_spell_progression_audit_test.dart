import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/character_persistence_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spell_allocation_validator.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/character_builder/level_up_wizard_dialog.dart';

void main() {
  group('Warlock Spell Progression & Untraining Audit', () {
    test('Warlock untraining at level 3 must not prevent learning 5th spell at level 4', () {
      // 1. Level 1 Warlock
      var warlock = const Character(
        id: EntityId(slug: 'warlock_test', ruleset: RulesetVersion.v2014),
        name: 'Warlock Test',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16),
        resources: CharacterResourcePool(
          currentHp: 10,
          currentHitDice: {'d8': 1},
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_eldritch_blast', displayName: 'Eldritch Blast'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_mage_hand', displayName: 'Mage Hand'),
        ],
        spellsKnown: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hex', displayName: 'Hex'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hellish_rebuke', displayName: 'Hellish Rebuke'),
        ],
      );

      expect(warlock.spellsKnown.length, 2);

      // 2. Level up to Level 2: learns Armor of Agathys
      const lvl2Request = LevelUpRequest(
        targetClassSlug: 'warlock',
        targetClassDisplayName: 'WARLOCK',
        targetClassHitDie: 'd8',
        newSpells: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_armor_of_agathys', displayName: 'Armor of Agathys'),
        ],
      );
      warlock = CharacterProgressionEngine.applyLevelUp(warlock, lvl2Request);
      expect(warlock.spellsKnown.length, 3);
      expect(warlock.allocatedSpells['class-warlock-spells']?.map((s) => s.slug).toSet(), contains('spell_armor_of_agathys'));

      // 3. Level up to Level 3:
      // Player untrains Hellish Rebuke to learn Darkness, AND learns Misty Step (1 new + 1 replacement = 2 new spells)
      const lvl3Request = LevelUpRequest(
        targetClassSlug: 'warlock',
        targetClassDisplayName: 'WARLOCK',
        targetClassHitDie: 'd8',
        newSpells: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_misty_step', displayName: 'Misty Step'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
        ],
        replacedSpellIds: ['spell_hellish_rebuke'],
      );
      warlock = CharacterProgressionEngine.applyLevelUp(warlock, lvl3Request);

      // At level 3, Warlock must have exactly 4 spells known: Hex, Armor of Agathys, Misty Step, Darkness
      expect(warlock.spellsKnown.map((s) => s.slug).toSet(), isNot(contains('spell_hellish_rebuke')));
      expect(warlock.spellsKnown.length, 4, reason: 'Warlock at level 3 should know exactly 4 spells after 1-for-1 swap');

      // 4. Level up to Level 4:
      // Level 4 Warlock limit
      final lvl4Limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 4,
        abilityModifier: 3,
      );
      expect(lvl4Limits.maxSpellsKnown, 5);

      // Quota calculation check
      final curKnownCount = warlock.spellsKnown.length;
      final delta = lvl4Limits.maxSpellsKnown - curKnownCount;
      expect(delta, 1, reason: 'Warlock leveling to level 4 should have delta of 1 new leveled spell');
    });

    test('Untraining a spell previously learned at level up (stored in allocatedSpells) removes it from allocatedSpells', () {
      var warlock = const Character(
        id: EntityId(slug: 'warlock_test_2', ruleset: RulesetVersion.v2014),
        name: 'Warlock Test 2',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 1,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16),
        resources: CharacterResourcePool(
          currentHp: 10,
          currentHitDice: {'d8': 1},
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_eldritch_blast', displayName: 'Eldritch Blast'),
        ],
        spellsKnown: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hex', displayName: 'Hex'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_arms_of_hadar', displayName: 'Arms of Hadar'),
        ],
      );

      // Level 2: learns Armor of Agathys (this goes into allocatedSpells['class-warlock-spells'])
      const lvl2Request = LevelUpRequest(
        targetClassSlug: 'warlock',
        targetClassDisplayName: 'WARLOCK',
        targetClassHitDie: 'd8',
        newSpells: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_armor_of_agathys', displayName: 'Armor of Agathys'),
        ],
      );
      warlock = CharacterProgressionEngine.applyLevelUp(warlock, lvl2Request);
      expect(warlock.allocatedSpells['class-warlock-spells']?.map((s) => s.slug).toSet(), contains('spell_armor_of_agathys'));

      // Level 3: Swaps Armor of Agathys for Darkness, and learns Misty Step
      const lvl3Request = LevelUpRequest(
        targetClassSlug: 'warlock',
        targetClassDisplayName: 'WARLOCK',
        targetClassHitDie: 'd8',
        newSpells: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_misty_step', displayName: 'Misty Step'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
        ],
        replacedSpellIds: ['spell_armor_of_agathys'],
      );
      warlock = CharacterProgressionEngine.applyLevelUp(warlock, lvl3Request);

      // Verify Armor of Agathys was removed from allocatedSpells AND spellsKnown
      expect(warlock.allocatedSpells['class-warlock-spells']?.map((s) => s.slug).toSet(), isNot(contains('spell_armor_of_agathys')));
      expect(warlock.spellsKnown.map((s) => s.slug).toSet(), isNot(contains('spell_armor_of_agathys')));
      expect(warlock.spellsKnown.length, 4);

      // Level 4: applyLevelUp with 1 new leveled spell and 1 new cantrip
      const lvl4Request = LevelUpRequest(
        targetClassSlug: 'warlock',
        targetClassDisplayName: 'WARLOCK',
        targetClassHitDie: 'd8',
        newCantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_chill_touch', displayName: 'Chill Touch'),
        ],
        newSpells: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hold_person', displayName: 'Hold Person'),
        ],
      );
      warlock = CharacterProgressionEngine.applyLevelUp(warlock, lvl4Request);
      expect(warlock.cantrips.length, 2); // 1 initial + 1 new = 2
      expect(warlock.spellsKnown.length, 5); // 4 + 1 = 5
      expect(warlock.spellsKnown.map((s) => s.slug).toSet(), contains('spell_hold_person'));
      expect(warlock.allocatedSpells['class-warlock-spells']?.map((s) => s.slug).toSet(), contains('spell_hold_person'));
    });

    test('College of Lore Bard at Level 6 receives 2 Additional Magical Secrets (+2 known)', () {
      final loreLimits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 6,
        subclassSlug: 'college_of_lore',
        abilityModifier: 3,
      );
      // Base bard knows 9 spells at level 6. Lore bard gains +2 = 11.
      expect(loreLimits.maxSpellsKnown, 11);
      expect(loreLimits.magicalSecretsCount, 2);
    });

    test('Eldritch Knight Fighter at Level 3 is recognized as 1/3 caster with Wizard spell list', () {
      final ekLimits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'fighter',
        classLevel: 3,
        subclassSlug: 'eldritch_knight',
        abilityModifier: 3,
      );
      expect(ekLimits.isSpellcaster, isTrue);
      expect(ekLimits.maxCantrips, 2);
      expect(ekLimits.maxSpellsKnown, 3);
      expect(ekLimits.maxSpellSlotLevel, 1);
      expect(ekLimits.castingAbility, 'Intelligence');
    });

    testWidgets('LevelUpWizardDialog correctly computes Level 4 Warlock quotas after Level 3 untrain', (tester) async {
      tester.view.physicalSize = const Size(1024, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Character at Level 3 Warlock with 4 spells known and 2 cantrips
      const lvl3Warlock = Character(
        id: EntityId(slug: 'warlock_hud_test', ruleset: RulesetVersion.v2014),
        name: 'Warlock HUD Test',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 3,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16),
        resources: CharacterResourcePool(
          currentHp: 24,
          currentHitDice: {'d8': 3},
        ),
        cantrips: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_eldritch_blast', displayName: 'Eldritch Blast'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_mage_hand', displayName: 'Mage Hand'),
        ],
        spellsKnown: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hex', displayName: 'Hex'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_armor_of_agathys', displayName: 'Armor of Agathys'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_misty_step', displayName: 'Misty Step'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LevelUpWizardDialog(
              character: lvl3Warlock,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Class (Warlock) -> Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: HP -> Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Features -> Step 4
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 4: ASI/Feat -> Step 5
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 5: Spells & Cantrips
      expect(find.textContaining('Step 5 of 6'), findsOneWidget);

      // Verify that Quota for Level 4 offers 1 new leveled spell and 1 new cantrip!
      expect(find.textContaining('0/1 New Leveled Spell(s)'), findsOneWidget);
      expect(find.textContaining('0/1 New Cantrip(s)'), findsOneWidget);

      // Verify user can tap a spell to replace (e.g. Hex)
      final hexChip = find.text('Hex');
      expect(hexChip, findsOneWidget);
      await tester.tap(hexChip);
      await tester.pumpAndSettle();

      // After selecting 1 spell to replace, quota should now be 2 New Leveled Spells (1 milestone + 1 replacement)
      expect(find.textContaining('0/2 New Leveled Spell(s)'), findsOneWidget);
    });

    test('CharacterSheetController.removeSpell purges spell from allocatedSpells as well as spellsKnown', () async {
      final mockPersistence = _MockAuditPersistence();
      const testChar = Character(
        id: EntityId(slug: 'warlock_sheet_test', ruleset: RulesetVersion.v2014),
        name: 'Warlock Sheet Test',
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock',
              ),
              level: 3,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(charisma: 16),
        resources: CharacterResourcePool(
          currentHp: 24,
          currentHitDice: {'d8': 3},
        ),
        allocatedSpells: {
          'class-warlock-spells': [
            EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hex', displayName: 'Hex'),
            EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
          ],
        },
        spellsKnown: [
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_hex', displayName: 'Hex'),
          EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
        ],
      );

      final controller = CharacterSheetController(
        character: testChar,
        persistenceService: mockPersistence,
      );

      expect(controller.character.spellsKnown.length, 2);
      expect(controller.character.allocatedSpells['class-warlock-spells']?.length, 2);

      // Remove darkness from sheet
      await controller.removeSpell(
        const EntityReference<Spell>(refType: EntityType.spell, slug: 'spell_darkness', displayName: 'Darkness'),
      );

      expect(controller.character.spellsKnown.length, 1);
      expect(controller.character.spellsKnown.map((s) => s.slug).toSet(), contains('spell_hex'));
      expect(controller.character.spellsKnown.map((s) => s.slug).toSet(), isNot(contains('spell_darkness')));
      expect(controller.character.allocatedSpells['class-warlock-spells']?.map((s) => s.slug).toSet(), isNot(contains('spell_darkness')));
    });
  });
}

class _MockAuditPersistence implements CharacterPersistenceService {
  Character? savedCharacter;
  List<Character> roster = [];

  @override
  Future<List<Character>> saveCharacter(Character character) async {
    savedCharacter = character;
    roster.removeWhere((c) => c.id.slug == character.id.slug);
    roster.add(character);
    return roster;
  }

  @override
  Future<List<Character>> loadCharacters() async => roster;

  @override
  Future<String?> loadActiveCharacterId() async => savedCharacter?.id.slug;

  @override
  Future<void> saveActiveCharacterId(String slug) async {}

  @override
  Future<void> saveRoster(List<Character> newRoster) async {
    roster = List.from(newRoster);
  }

  @override
  Future<List<Character>> deleteCharacter(String slug) async {
    roster.removeWhere((c) => c.id.slug == slug);
    return roster;
  }

  @override
  Future<List<Character>> getCharactersByIds(List<String> ids) async =>
      roster.where((c) => ids.contains(c.id.slug)).toList();

  @override
  Future<void> saveCharacters(List<Character> characters) async {
    for (final c in characters) {
      await saveCharacter(c);
    }
  }
}
