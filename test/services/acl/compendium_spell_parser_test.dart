import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';

void main() {
  group('Community Compendium & Homebrew Spell Parser Tests', () {
    late CompendiumSpellParser parser;

    setUp(() {
      parser = CompendiumSpellParser();
    });

    test('parses full mechanical spell with 1-letter school code and nested duration', () {
      final raw = {
        'name': 'Solar Flare',
        'source': 'HOMEBREW',
        'page': 142,
        'level': 3,
        'school': 'V', // Evocation
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 120}
        },
        'components': {
          'v': true,
          's': true,
          'm': {'text': 'a prism and a piece of amber', 'cost': 5000, 'consume': false}
        },
        'duration': [
          {
            'type': 'timed',
            'duration': {'type': 'minute', 'amount': 1},
            'concentration': true
          }
        ],
        'entries': [
          'A radiant burst detonates at a point you can see. Each creature in a 20-foot-radius sphere takes {@damage 8d6|radiant} damage, or half on a successful {@dc 15} Dexterity saving throw.',
          'The area is filled with sunlight.'
        ],
        'entriesHigherLevel': [
          'When you cast this spell using a spell slot of 4th level or higher, the damage increases by {@scaledamage 8d6|8d6|1d6} for each slot level above 3rd.'
        ],
        'damageInflict': ['radiant'],
        'savingThrow': ['dexterity'],
        'spellAttack': ['R'],
        'areaTags': ['S'],
        'miscTags': ['THP'],
        'classes': {
          'fromClassList': [
            {'name': 'Cleric', 'source': 'PHB'},
            {'name': 'Wizard', 'source': 'PHB'}
          ]
        },
        'customAuthorTag': 'Archmage Morden'
      };

      final spell = parser.parseSpell(raw);

      expect(spell.name, equals('Solar Flare'));
      expect(spell.id.slug, equals('solar-flare'));
      expect(spell.id.ruleset, equals(RulesetVersion.homebrew));
      expect(spell.level, equals(3));
      expect(spell.school, equals('Evocation'));
      expect(spell.castingTime.cost, equals(1));
      expect(spell.castingTime.actionType, equals(ActionType.action));
      expect(spell.range, equals('120 feet'));
      expect(spell.components.v, isTrue);
      expect(spell.components.s, isTrue);
      expect(spell.components.m, isTrue);
      expect(spell.components.materialCostGp, equals(50));
      expect(spell.components.consumesMaterial, isFalse);
      expect(spell.duration.requiresConcentration, isTrue);
      expect(spell.duration.durationSeconds, equals(60));
      expect(spell.descriptionMarkdown, contains('**`8d6 radiant`**'));
      expect(spell.descriptionMarkdown, contains('DC 15'));
      expect(spell.higherLevelsMarkdown, contains('*(scales: 1d6)*'));
      expect(spell.damageMath.length, equals(1));
      expect(spell.damageMath.first.diceFormula, equals('8d6'));
      expect(spell.damageMath.first.damageType, equals(DamageType.radiant));

      // 0% data loss verification
      expect(spell.customProperties['customAuthorTag'], equals('Archmage Morden'));
      expect(spell.customProperties['page'], equals(142));
      expect(spell.customProperties['savingThrow'], equals(['dexterity']));
      expect(spell.customProperties['classes']['fromClassList'].length, equals(2));
    });

    test('correctly resolves all 1-letter school abbreviations', () {
      final schools = {
        'A': 'Abjuration',
        'C': 'Conjuration',
        'D': 'Divination',
        'E': 'Enchantment',
        'I': 'Illusion',
        'N': 'Necromancy',
        'T': 'Transmutation',
        'V': 'Evocation',
      };

      for (final entry in schools.entries) {
        final spell = parser.parseSpell({
          'name': 'Test Spell ${entry.key}',
          'school': entry.key,
        });
        expect(spell.school, equals(entry.value));
      }
    });

    test('maps 2024 source tag to v2024 ruleset version', () {
      final spell = parser.parseSpell({
        'name': 'Healing Word',
        'source': 'SRD52',
        'level': 1,
      });

      expect(spell.id.ruleset, equals(RulesetVersion.v2024));
    });
  });
}
