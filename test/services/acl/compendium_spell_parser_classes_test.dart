import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('CompendiumSpellParser Classes and Damage Inference Tests', () {
    late CompendiumSpellParser parser;

    setUp(() {
      parser = CompendiumSpellParser();
    });

    test('extracts class list from 5etools fromClassList structure', () {
      final raw = {
        'name': 'Glacial Spikes',
        'source': 'HOMEBREW',
        'level': 3,
        'school': 'V',
        'time': [{'number': 1, 'unit': 'action'}],
        'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 60}},
        'components': {'v': true, 's': true},
        'duration': [{'type': 'instant'}],
        'classes': {
          'fromClassList': [
            {'name': 'Wizard', 'source': 'PHB'},
            {'name': 'Sorcerer', 'source': 'PHB'},
          ],
          'fromSubclass': [
            {
              'class': {'name': 'Druid', 'source': 'PHB'},
              'subclass': {'name': 'Circle of the Land'},
            }
          ],
        },
        'entries': [
          'Spikes of ice erupt from the ground dealing {@damage 3d8} cold damage to each creature.',
        ],
        'damageInflict': ['cold'],
        'scalingLevelDice': {
          'label': 'damage',
          'scaling': {'1': '1d8'},
        },
      };

      final spell = parser.parseSpell(raw);

      // Verify classes retained in customProperties with 0% data loss
      expect(spell.customProperties['classes']['fromClassList'], isNotEmpty);

      // Verify inferred damage type
      expect(spell.damageMath.first.damageType, equals(DamageType.cold));
      expect(spell.damageMath.first.scalingFormula, contains('1d8'));

      // Verify conversion to SpellItem
      final spellItem = HomebrewPersistenceService.spellToSpellItem(spell);
      expect(spellItem.rules2024.classes, containsAll([SpellClass.wizard, SpellClass.sorcerer, SpellClass.druid]));
      expect(spellItem.rules2024.rollFormula, equals('3d8'));
      expect(spellItem.rules2024.damageOrHealType, equals('cold'));
    });

    test('inherits classes from canonical SRD when spell classes are omitted', () {
      final raw = {
        'name': 'Eldritch Blast',
        'source': 'HOMEBREW',
        'level': 0,
        'school': 'V',
        'time': [{'number': 1, 'unit': 'action'}],
        'range': {'type': 'point', 'distance': {'type': 'feet', 'amount': 120}},
        'components': {'v': true, 's': true},
        'duration': [{'type': 'instant'}],
        'entries': [
          'A beam of crackling energy streaks toward a creature dealing {@damage 1d10} force damage.',
        ],
      };

      final spell = parser.parseSpell(raw);

      // Verify inherited Warlock class from SRD
      expect(spell.customProperties['classes'], isNotNull);
      final classes = spell.customProperties['classes'] as List;
      expect(classes.any((c) => c.toString().toLowerCase().contains('warlock')), isTrue);

      // Verify damage type inference from text
      expect(spell.damageMath.first.damageType, equals(DamageType.force));

      // Verify conversion to SpellItem retains Warlock
      final spellItem = HomebrewPersistenceService.spellToSpellItem(spell);
      expect(spellItem.rules2024.classes, contains(SpellClass.warlock));
    });
  });
}
