import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart'
    show SpellClass;
import 'package:dangerously_nerdy_5e_toolkit/services/repository/layered_priority_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/repository/reference_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/spell_allocation_validator.dart';

Spell _makeTestSpell(String slug, String name, int level) {
  return Spell(
    id: EntityId(slug: slug, ruleset: RulesetVersion.v2024),
    name: name,
    level: level,
    school: 'necromancy',
    castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
    duration: const SpellDuration(type: DurationType.instantaneous),
    range: '60 feet',
    components: const SpellComponents(v: true, s: true, m: false),
    descriptionMarkdown: 'Test spell markdown.',
  );
}

void main() {
  group('SpellAllocationValidator RAW Tests', () {
    test('Wizard Level 1 spell limits and spellbook initial scribe quota', () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'wizard',
        classLevel: 1,
        abilityModifier: 3, // 16 INT -> +3
        edition: DmRulesEdition.v2024,
      );

      expect(limits.isSpellcaster, isTrue);
      expect(limits.maxCantrips, 3);
      expect(limits.maxSpellsPrepared, 4); // 1 + 3 = 4
      expect(limits.maxSpellbookInitialScribe, 6);
      expect(limits.maxSpellbookLevelUpScribe, 2);
      expect(limits.maxSpellSlotLevel, 1);
    });

    test('Wizard Level 1 validates exactly 6 spellbook spells', () {
      final cantrips = [
        const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'fire-bolt',
            displayName: 'Fire Bolt'),
        const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'mage-hand',
            displayName: 'Mage Hand'),
        const EntityReference<Spell>(
            refType: EntityType.spell, slug: 'light', displayName: 'Light'),
      ];

      final spellbookValid = List.generate(
        6,
        (i) => EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spell-$i',
            displayName: 'Spell $i'),
      );

      final preparedValid = spellbookValid.take(4).toList();

      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid,
        spellsPrepared: preparedValid,
        edition: DmRulesEdition.v2024,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);

      // Invalid: Only 5 spells in spellbook
      final invalidResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'wizard',
        targetClassLevel: 1,
        castingAbilityModifier: 3,
        cantrips: cantrips,
        spellsKnown: spellbookValid.take(5).toList(),
        spellsPrepared: preparedValid,
        edition: DmRulesEdition.v2024,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.first, contains('6 1st-level spells'));
    });

    test('Sorcerer Spells Known progression across levels', () {
      final lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 1,
        abilityModifier: 3,
      );
      expect(lvl1.maxCantrips, 4);
      expect(lvl1.maxSpellsKnown, 2);
      expect(lvl1.maxSpellSlotLevel, 1);

      final lvl5 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'sorcerer',
        classLevel: 5,
        abilityModifier: 4,
      );
      expect(lvl5.maxCantrips, 5);
      expect(lvl5.maxSpellsKnown, 6);
      expect(lvl5.maxSpellSlotLevel, 3);
    });

    test('Paladin spellcasting starts at Level 2 in 2014, Level 1 in 2024', () {
      final paladin2014Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: DmRulesEdition.v2014,
      );
      expect(paladin2014Lvl1.isSpellcaster, isFalse);
      expect(paladin2014Lvl1.maxSpellSlotLevel, 0);

      final paladin2024Lvl1 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'paladin',
        classLevel: 1,
        abilityModifier: 2,
        edition: DmRulesEdition.v2024,
      );
      expect(paladin2024Lvl1.isSpellcaster, isTrue);
      expect(paladin2024Lvl1.maxSpellSlotLevel, 1);
      expect(paladin2024Lvl1.maxSpellsPrepared, 3); // ((1+1)~/2) + 2 = 3
    });

    test('Max tier gating prevents selecting higher level spells', () {
      final tierLvl3Wizard = SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'wizard',
        classLevel: 3,
      );
      expect(tierLvl3Wizard,
          2); // 3rd level wizard can cast up to 2nd level spells

      final tierLvl5Ranger2014 =
          SpellAllocationValidator.getMaxSpellTierForClass(
        classSlug: 'ranger',
        classLevel: 5,
        edition: DmRulesEdition.v2014,
      );
      expect(tierLvl5Ranger2014, 2);
    });

    test('Bard 2014 Magical Secrets progression at levels 10, 14, 18', () {
      final l10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: DmRulesEdition.v2014,
      );
      expect(l10.magicalSecretsCount, 2);
      expect(l10.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final l14 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 14,
        abilityModifier: 4,
        edition: DmRulesEdition.v2014,
      );
      expect(l14.magicalSecretsCount, 4);

      final l18 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 18,
        abilityModifier: 5,
        edition: DmRulesEdition.v2014,
      );
      expect(l18.magicalSecretsCount, 6);
    });

    test('Lore Bard Additional Magical Secrets at Level 6 (2014 vs 2024)', () {
      final lore2014 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: DmRulesEdition.v2014,
      );
      expect(lore2014.magicalSecretsCount, 2);
      expect(
          lore2014.allowedMagicalSecretClasses.length, greaterThanOrEqualTo(8));

      final lore2024 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        subclassSlug: 'college_of_lore',
        classLevel: 6,
        abilityModifier: 3,
        edition: DmRulesEdition.v2024,
      );
      expect(lore2024.magicalSecretsCount, 2);
      expect(
          lore2024.allowedMagicalSecretClasses,
          containsAll(
              [SpellClass.wizard, SpellClass.cleric, SpellClass.druid]));
    });

    test(
        'Bard 2024 Level 10 Magical Secrets unlocks Cleric, Druid, and Wizard spell lists',
        () {
      final bard2024L10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'bard',
        classLevel: 10,
        abilityModifier: 4,
        edition: DmRulesEdition.v2024,
      );
      expect(
          bard2024L10.allowedMagicalSecretClasses,
          containsAll([
            SpellClass.bard,
            SpellClass.cleric,
            SpellClass.druid,
            SpellClass.wizard,
          ]));
    });

    test('Warlock Mystic Arcanum milestones at levels 11, 13, 15, 17', () {
      final w10 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 10,
        abilityModifier: 4,
      );
      expect(w10.mysticArcanumLevel, 0);
      expect(w10.mysticArcanumCount, 0);

      final w11 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 11,
        abilityModifier: 4,
      );
      expect(w11.mysticArcanumLevel, 6);
      expect(w11.mysticArcanumCount, 1);
      expect(w11.maxSpellsKnown, 11);
      expect(w11.maxSpellSlotLevel, 5);

      final w13 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 13,
        abilityModifier: 4,
      );
      expect(w13.mysticArcanumLevel, 7);
      expect(w13.mysticArcanumCount, 2);

      final w15 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 15,
        abilityModifier: 4,
      );
      expect(w15.mysticArcanumLevel, 8);
      expect(w15.mysticArcanumCount, 3);

      final w17 = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'warlock',
        classLevel: 17,
        abilityModifier: 4,
      );
      expect(w17.mysticArcanumLevel, 9);
      expect(w17.mysticArcanumCount, 4);
    });

    test(
        'Warlock Level 11 validates 11 known spells AND 1 Level 6 Mystic Arcanum spell without quota error',
        () {
      final repo = LayeredPriorityRepository();
      final baseLayer = PriorityLayer(
          layerId: 'srd', name: 'SRD', priority: LayerPriority.baseRuleset);
      repo.addLayer(baseLayer);
      final resolver = ReferenceResolver(repo);

      // Register 11 Level-5 spells
      final regularSpells = <EntityReference<Spell>>[];
      for (int i = 1; i <= 11; i++) {
        final s = _makeTestSpell('pact-spell-$i', 'Pact Spell $i', 5);
        baseLayer.registerEntity(s);
        regularSpells.add(EntityReference<Spell>(
            refType: EntityType.spell, slug: s.id.slug, displayName: s.name));
      }

      // Register 1 Level-6 Mystic Arcanum spell
      final arcanum = _makeTestSpell('eyebite', 'Eyebite', 6);
      baseLayer.registerEntity(arcanum);
      final arcanumRef = EntityReference<Spell>(
          refType: EntityType.spell,
          slug: arcanum.id.slug,
          displayName: arcanum.name);

      // Validate with 11 regular + 1 arcanum = 12 total in spellsKnown
      final validResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 11,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [...regularSpells, arcanumRef],
        spellsPrepared: const [],
        edition: DmRulesEdition.v2024,
        resolver: resolver,
      );

      expect(validResult.isValid, isTrue);
      expect(validResult.errors, isEmpty);

      // Invalid: 12 regular spells + 1 arcanum = exceeds 11 maxSpellsKnown
      final extraSpell = _makeTestSpell('pact-spell-12', 'Pact Spell 12', 5);
      baseLayer.registerEntity(extraSpell);
      final extraRef = EntityReference<Spell>(
          refType: EntityType.spell,
          slug: extraSpell.id.slug,
          displayName: extraSpell.name);

      final invalidResult = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 11,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [...regularSpells, extraRef, arcanumRef],
        spellsPrepared: const [],
        edition: DmRulesEdition.v2024,
        resolver: resolver,
      );

      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errors.first,
          contains('exceeding the maximum allowed limit of 11'));
    });

    test(
        'Warlock Level 13 validates lower-tier Level 6 Arcanum alongside new Level 7 Arcanum',
        () {
      final repo = LayeredPriorityRepository();
      final baseLayer = PriorityLayer(
          layerId: 'srd', name: 'SRD', priority: LayerPriority.baseRuleset);
      repo.addLayer(baseLayer);
      final resolver = ReferenceResolver(repo);

      final arcanum6 = _makeTestSpell('eyebite', 'Eyebite', 6);
      final arcanum7 = _makeTestSpell('forcecage', 'Forcecage', 7);
      final invalid8 = _makeTestSpell('demiplane', 'Demiplane', 8);
      baseLayer.registerEntity(arcanum6);
      baseLayer.registerEntity(arcanum7);
      baseLayer.registerEntity(invalid8);

      final ref6 = EntityReference<Spell>(
          refType: EntityType.spell,
          slug: arcanum6.id.slug,
          displayName: arcanum6.name);
      final ref7 = EntityReference<Spell>(
          refType: EntityType.spell,
          slug: arcanum7.id.slug,
          displayName: arcanum7.name);
      final ref8 = EntityReference<Spell>(
          refType: EntityType.spell,
          slug: invalid8.id.slug,
          displayName: invalid8.name);

      // Valid: both Level 6 and Level 7 arcanums pass
      final resultValid = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 13,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [ref6, ref7],
        spellsPrepared: const [],
        edition: DmRulesEdition.v2024,
        resolver: resolver,
      );
      expect(resultValid.isValid, isTrue);

      // Invalid: Level 8 spell exceeds mysticArcanumLevel 7 for Level 13 Warlock
      final resultInvalid = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'warlock',
        targetClassLevel: 13,
        castingAbilityModifier: 4,
        cantrips: const [],
        spellsKnown: [ref6, ref7, ref8],
        spellsPrepared: const [],
        edition: DmRulesEdition.v2024,
        resolver: resolver,
      );
      expect(resultInvalid.isValid, isFalse);
      expect(resultInvalid.errors.first,
          contains('can only cast up to Level 5 spells'));
    });

    test(
        'validateSpellAllocations accepts class-warlock-mystic-arcanum grant key',
        () {
      const character = Character(
        id: EntityId(slug: 'warlock-hero', ruleset: RulesetVersion.v2024),
        name: 'Warlock Hero',
        speciesRef: EntityReference(
            refType: EntityType.species,
            slug: 'tiefling',
            displayName: 'Tiefling'),
        baseScores: AbilityScores(
            strength: 8,
            dexterity: 14,
            constitution: 14,
            intelligence: 10,
            wisdom: 12,
            charisma: 18),
        resources:
            CharacterResourcePool(currentHp: 50, currentHitDice: {'d8': 11}),
        progression: CharacterProgression(classes: [
          ClassLevelProgression(
            classRef: EntityReference(
                refType: EntityType.classDefinition,
                slug: 'warlock',
                displayName: 'Warlock'),
            level: 11,
            hitDie: 'd8',
            isStartingClass: true,
          ),
        ]),
        allocatedSpells: {
          'class-warlock-mystic-arcanum': [
            EntityReference<Spell>(
                refType: EntityType.spell,
                slug: 'eyebite',
                displayName: 'Eyebite'),
          ],
        },
      );

      final res = SpellAllocationValidator.validateSpellAllocations(
          character, const []);
      expect(res.isValid, isTrue);
      expect(res.errors, isEmpty);
    });

    test(
        'Cleric Life Domain always-prepared spells are exempt from maxSpellsPrepared validation',
        () {
      final limits = SpellAllocationValidator.getLimitsForClass(
        classSlug: 'cleric',
        subclassSlug: 'life_domain',
        classLevel: 3,
        abilityModifier: 3,
      );
      // Level 3 + 3 WIS = 6 prepared spells quota
      expect(limits.maxSpellsPrepared, 6);
      // Life domain grants 4 spells at level 3 (Bless, Cure Wounds, Lesser Restoration, Spiritual Weapon)
      expect(limits.alwaysPreparedSubclassCount, 4);

      // Character prepares 6 regular spells + 4 domain spells = 10 total
      final regularPrepared = List.generate(
        6,
        (i) => EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'reg-spell-$i',
            displayName: 'Reg Spell $i'),
      );
      final domainSpells = [
        const EntityReference<Spell>(
            refType: EntityType.spell, slug: 'bless', displayName: 'Bless'),
        const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'cure-wounds',
            displayName: 'Cure Wounds'),
        const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'lesser-restoration',
            displayName: 'Lesser Restoration'),
        const EntityReference<Spell>(
            refType: EntityType.spell,
            slug: 'spiritual-weapon',
            displayName: 'Spiritual Weapon'),
      ];

      final result = SpellAllocationValidator.validateSpellSelection(
        targetClassSlug: 'cleric',
        targetClassLevel: 3,
        castingAbilityModifier: 3,
        subclassSlug: 'life_domain',
        cantrips: const [],
        spellsKnown: const [],
        spellsPrepared: [...regularPrepared, ...domainSpells],
        alwaysPreparedSpellIds: [
          'bless',
          'cure-wounds',
          'lesser-restoration',
          'spiritual-weapon'
        ],
        edition: DmRulesEdition.v2024,
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });
}
