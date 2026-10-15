import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

void main() {
  group('Pass 6 Law Test: S1 Spell Level Resolution Law', () {
    test('Every SRD spell in SpellbookLibrary.srdSpells resolves correctly without prior lookup', () {
      const allSrdSpells = SpellbookLibrary.srdSpells;
      expect(allSrdSpells, isNotEmpty);

      int cantripsCount = 0;
      int leveledCount = 0;

      for (final spell in allSrdSpells) {
        // Construct character holding a level-less reference to this spell
        final char = Character(
          id: EntityId(slug: 's1-${spell.id}', ruleset: RulesetVersion.v2024),
          name: 'Law Test Caster',
          speciesRef: const EntityReference<DomainEntity>.empty(
            refType: EntityType.species,
            slug: 'human',
            displayName: 'Human',
          ),
          allocatedSpells: {
            'spells': [
              EntityReference<Spell>.empty(
                refType: EntityType.spell,
                slug: spell.id,
                displayName: spell.name,
              ),
            ],
          },
        );

        if (spell.level == 0) {
          cantripsCount++;
          expect(
            char.cantrips.length,
            equals(1),
            reason: '${spell.name} (${spell.id}) has level 0 so it must be recognized as a cantrip',
          );
          expect(
            char.spellsKnown.length,
            equals(0),
            reason: '${spell.name} (${spell.id}) has level 0 so it must not be in leveled spellsKnown',
          );
        } else {
          leveledCount++;
          expect(
            char.cantrips.length,
            equals(0),
            reason: '${spell.name} (${spell.id}) has level ${spell.level} so it must not be recognized as a cantrip',
          );
          expect(
            char.spellsKnown.length,
            equals(1),
            reason: '${spell.name} (${spell.id}) has level ${spell.level} so it must be in leveled spellsKnown',
          );
        }
      }

      expect(cantripsCount, greaterThan(20));
      expect(leveledCount, greaterThan(200));
    });
  });
}
