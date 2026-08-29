import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_spell_ingestion_pipeline.dart';

void main() {
  group('CompendiumSpellIngestionPipeline Tests', () {
    late CompendiumSpellIngestionPipeline pipeline;

    setUp(() {
      pipeline = CompendiumSpellIngestionPipeline();
    });

    test('ingests 2024 spell record with full metadata and scaling entries', () {
      final rawJson = {
        'name': 'Fireball',
        'source': 'XPHB',
        'level': 3,
        'school': 'V',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 150}
        },
        'components': {
          'v': true,
          's': true,
          'm': {'text': 'a tiny ball of bat guano and sulfur', 'cost': 500, 'consume': true}
        },
        'duration': [
          {'type': 'instant'}
        ],
        'entries': [
          'A bright streak flashes from your pointing finger...',
          'Each creature in a 20-foot radius sphere must make a Dexterity saving throw. A target takes {@damage 8d6|fire} damage on a failed save.'
        ],
        'entriesHigherLevel': [
          {
            'type': 'entries',
            'name': 'Using a Higher-Level Slot',
            'entries': [
              'The damage increases by {@scaledamage 8d6|3-9|1d6} for each slot level above 3rd.'
            ]
          }
        ]
      };

      final spell = pipeline.ingestSpell(rawJson);

      expect(spell.name, equals('Fireball'));
      expect(spell.slug, equals('fireball'));
      expect(spell.ruleset, equals(RulesetVersion.v2024));
      expect(spell.level, equals(3));
      expect(spell.school, equals('Evocation'));
      expect(spell.castingTime.actionType, equals(ActionType.action));
      expect(spell.duration.type, equals(DurationType.instantaneous));
      expect(spell.range, equals('150 feet'));
      expect(spell.components.v, isTrue);
      expect(spell.components.s, isTrue);
      expect(spell.components.m, isTrue);
      expect(spell.components.materialCostGp, equals(500));
      expect(spell.components.consumesMaterial, isTrue);
      expect(spell.damageMath.length, equals(1));
      expect(spell.damageMath.first.diceFormula, equals('8d6'));
      expect(spell.damageMath.first.damageType, equals(DamageType.fire));
      expect(spell.higherLevelsMarkdown, contains('Using a Higher-Level Slot'));
    });

    test('defensively extracts damage type from root metadata if entries lack tags', () {
      final rawJson = {
        'name': 'Poison Spray',
        'source': 'PHB',
        'level': 0,
        'school': 'C',
        'time': [
          {'number': 1, 'unit': 'action'}
        ],
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 10}
        },
        'components': {'v': true, 's': true},
        'duration': [
          {'type': 'instant'}
        ],
        'damageInflict': ['poison'],
        'entries': [
          'You extend your hand toward a creature you can see within range and project a puff of noxious gas.'
        ]
      };

      final spell = pipeline.ingestSpell(rawJson);

      expect(spell.ruleset, equals(RulesetVersion.v2014));
      expect(spell.damageMath.length, equals(1));
      expect(spell.damageMath.first.damageType, equals(DamageType.poison));
    });
  });
}
