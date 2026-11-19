import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

void main() {
  // The other 12 pure-ruleset SpellAllocationValidator tests moved to
  // vtt-ruleset-dnd5e/test/spellcasting/spell_allocation_validator_test.dart
  // in Cleanup slice 13 (Fix 5.3). This test stays in the app because it
  // verifies the app's Dnd5eCatalog wiring of SubclassSpellsLibrary for the
  // Cleric Life Domain always-prepared spell list (4 spells at level 3).
  group('SpellAllocationValidator RAW Tests', () {
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
        (i) => EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'reg-spell-$i',
            displayName: 'Reg Spell $i'),
      );
      final domainSpells = [
        const EntityReference<Spell>.empty(
            refType: EntityType.spell, slug: 'bless', displayName: 'Bless'),
        const EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'cure-wounds',
            displayName: 'Cure Wounds'),
        const EntityReference<Spell>.empty(
            refType: EntityType.spell,
            slug: 'lesser-restoration',
            displayName: 'Lesser Restoration'),
        const EntityReference<Spell>.empty(
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
