import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';

void main() {
  group('Cantrip Allocation Routing & Spellbook Definition Querying Tests', () {
    test('Non-cantrip named grant keys correctly route 0th-level spells to cantrips getter', () {
      const thaumaturgyRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'thaumaturgy',
        displayName: 'Thaumaturgy',
      );
      const sacredFlameRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'sacred-flame',
        displayName: 'Sacred Flame',
      );
      const blessRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'bless',
        displayName: 'Bless',
      );

      const character = Character(
        id: EntityId(slug: 'tiefling_cleric', ruleset: RulesetVersion.v2024),
        name: 'Tiefling Cleric',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'tiefling', displayName: 'Tiefling'),
        baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
        progression: CharacterProgression(classes: []),
        resources: CharacterResourcePool(),
        allocatedSpells: {
          'infernal_legacy': [thaumaturgyRef],
          'celestial_bloodline': [sacredFlameRef],
          'domain_spells': [blessRef],
        },
      );

      // thaumaturgy and sacred-flame are level 0 (Cantrips), so they must be in cantrips getter
      expect(character.cantrips.map((s) => s.slug), containsAll(['thaumaturgy', 'sacred-flame']));
      expect(character.cantrips.map((s) => s.slug), isNot(contains('bless')));

      // bless is level 1, so it must be in spellsKnown and NOT cantrips
      expect(character.spellsKnown.map((s) => s.slug), contains('bless'));
      expect(character.spellsKnown.map((s) => s.slug), isNot(contains('thaumaturgy')));
      expect(character.spellsKnown.map((s) => s.slug), isNot(contains('sacred-flame')));
    });

    test('Natively granted cantrips and spellsKnown are merged without duplicates', () {
      const lightRef = EntityReference<Spell>(
        refType: EntityType.spell,
        slug: 'light',
        displayName: 'Light',
      );

      const character = Character(
        id: EntityId(slug: 'aasimar_wizard', ruleset: RulesetVersion.v2024),
        name: 'Aasimar Wizard',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'aasimar', displayName: 'Aasimar'),
        baseScores: AbilityScores(strength: 10, dexterity: 10, constitution: 10, intelligence: 10, wisdom: 10, charisma: 10),
        progression: CharacterProgression(classes: []),
        resources: CharacterResourcePool(),
        cantrips: [lightRef],
        allocatedSpells: {
          'species_traits': [lightRef],
        },
      );

      // Ensure no duplicate 'light' cantrip is emitted
      expect(character.cantrips.length, equals(1));
      expect(character.cantrips.first.slug, equals('light'));
    });
  });
}
