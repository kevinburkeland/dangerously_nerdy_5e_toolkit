import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_class_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  group('CompendiumClassParser Spell & Grant Extraction Tests', () {
    late CompendiumClassParser parser;

    setUp(() {
      parser = CompendiumClassParser();
    });

    test('1. Extracts bonus spells from prepared spell map (Cleric/Druid archetype style)', () {
      final rawSubclass = {
        'name': 'Astral Domain',
        'className': 'Cleric',
        'source': 'CUSTOM',
        'additionalSpells': [
          {
            'prepared': {
              '1': ['command', 'cure wounds'],
              '3': ['augury', 'suggestion'],
              '5': ['beacon of hope', 'fireball'],
            }
          }
        ],
        'subclassFeatures': [
          'Astral Domain feature description',
        ],
      };

      final sub = parser.parseSubclass(rawSubclass);

      expect(sub.name, 'Astral Domain');
      expect(sub.classSlug, 'cleric');
      expect(sub.grants.length, 6);

      final grantSlugs = sub.grants.map((g) => g.payload['slug']).toSet();
      expect(grantSlugs, containsAll(['command', 'cure-wounds', 'augury', 'suggestion', 'beacon-of-hope', 'fireball']));

      final commandGrant = sub.grants.firstWhere((g) => g.payload['slug'] == 'command');
      expect(commandGrant.type, GrantType.bonusSpell);
      expect(commandGrant.payload['displayName'], 'command');
    });

    test('2. Extracts bonus spells from expanded & known maps with cantrips (#c) and pipes', () {
      final rawSubclass = {
        'name': 'Star Patron',
        'className': 'Warlock',
        'source': 'CUSTOM',
        'additionalSpells': [
          {
            'known': {
              '1': ['guidance#c', {'choose': 'level=0|class=Druid'}],
            },
            'expanded': {
              's1': ['burning hands', 'shield|phb'],
              's2': ['blur', 'misty step|'],
            }
          }
        ],
        'subclassFeatures': [],
      };

      final sub = parser.parseSubclass(rawSubclass);

      expect(sub.grants.length, 5); // guidance, burning hands, shield, blur, misty step
      final grantNames = sub.grants.map((g) => g.payload['displayName']).toList();
      expect(grantNames, containsAll(['guidance', 'burning hands', 'shield', 'blur', 'misty step']));

      final guidance = sub.grants.firstWhere((g) => g.payload['slug'] == 'guidance');
      expect(guidance.payload['displayName'], 'guidance');
    });

    test('3. Extracts bonus spells from nested innate ritual structures', () {
      final rawSubclass = {
        'name': 'Primal Shaman',
        'className': 'Barbarian',
        'source': 'CUSTOM',
        'additionalSpells': [
          {
            'innate': {
              '3': {
                'ritual': ['beast sense', 'speak with animals']
              },
              '10': {
                'ritual': ['commune with nature']
              }
            }
          }
        ],
        'subclassFeatures': [],
      };

      final sub = parser.parseSubclass(rawSubclass);

      expect(sub.grants.length, 3);
      final grantSlugs = sub.grants.map((g) => g.payload['slug']).toSet();
      expect(grantSlugs, containsAll(['beast-sense', 'speak-with-animals', 'commune-with-nature']));
    });

    test('4. Extracts bonus spells from class-level additionalSpells', () {
      final rawClass = {
        'name': 'Mystic Warrior',
        'hd': {'faces': 10},
        'proficiency': ['str', 'con'],
        'spellcastingAbility': 'wis',
        'additionalSpells': [
          {
            'prepared': {
              '1': ['bless', 'shield'],
            }
          }
        ],
      };

      final cls = parser.parseClass(rawClass);

      expect(cls.name, 'Mystic Warrior');
      expect(cls.grants.length, 2);
      expect(cls.grants.first.type, GrantType.bonusSpell);
      expect(cls.grants.first.payload['slug'], 'bless');
    });
  });

  group('SubclassSpellsLibrary Dynamic Homebrew Tests', () {
    setUp(() {
      SrdClassesLibrary.setCustomSubclasses([
        Subclass(
          id: const EntityId(slug: 'custom-sun-domain', ruleset: RulesetVersion.homebrew),
          name: 'Sun Domain',
          classSlug: 'cleric',
          featuresMarkdown: 'Solar radiance',
          grants: [
            FeatureGrant.bonusSpell(
              grantId: 'sub-sun-spell-daylight',
              slug: 'daylight',
              displayName: 'daylight',
            ),
            FeatureGrant.bonusSpell(
              grantId: 'sub-sun-spell-fireball',
              slug: 'fireball',
              displayName: 'fireball',
            ),
          ],
          customProperties: {
            'additionalSpells': [
              {
                'prepared': {
                  '3': ['daylight', 'fireball']
                }
              }
            ]
          },
        ),
      ]);
    });

    tearDown(() {
      SrdClassesLibrary.setCustomSubclasses([]);
    });

    test('5. SubclassSpellsLibrary resolves expanded spells from dynamic custom subclasses', () {
      final spells = SubclassSpellsLibrary.getExpandedSpells('cleric', 'custom-sun-domain');
      expect(spells, contains('daylight'));
      expect(spells, contains('fireball'));
    });

    test('6. SubclassSpellsLibrary detects always-prepared subclasses including custom prepared subclasses', () {
      expect(SubclassSpellsLibrary.isAlwaysPreparedSubclass('cleric', 'custom-sun-domain'), isTrue);
    });

    test('7. SubclassSpellsLibrary returns always-prepared spells for level', () {
      final preparedSpells = SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
        classSlug: 'cleric',
        subclassSlug: 'custom-sun-domain',
        classLevel: 5,
        edition: DmRulesEdition.v2024,
      );

      final names = preparedSpells.map((s) => s.name.toLowerCase()).toList();
      expect(names, contains('daylight'));
      expect(names, contains('fireball'));
    });
  });

  group('Compendium Tag Processing Tests', () {
    test('8. EntryNodeTransformer converts {@book} and {@variantrule} into clean text', () {
      final transformer = EntryNodeTransformer();
      final result1 = transformer.transformEntries([
        'Access to {@book Dunamancy Spells|EGW|Dunamancy Spells}.',
      ]);
      expect(result1.markdown, contains('Access to Dunamancy Spells.'));
      expect(result1.markdown, isNot(contains('{@book')));

      final result2 = transformer.transformEntries([
        'Replaces {@variantrule optional class features*, which replaces the Potent Spellcasting feature}.',
      ]);
      expect(result2.markdown, contains('optional class features*, which replaces the Potent Spellcasting feature'));
      expect(result2.markdown, isNot(contains('{@variantrule')));
    });

    test('9. CompendiumJsonIngestionPipeline.cleanRawTags cleans tags from markdown', () {
      const rawText = '> Note: This class has access to {@book Dunamancy Spells}. See {@variantrule optional features}.';
      final cleaned = CompendiumJsonIngestionPipeline.cleanRawTags(rawText);

      expect(cleaned, isNot(contains('{@book')));
      expect(cleaned, isNot(contains('{@variantrule')));
      expect(cleaned, contains('Dunamancy Spells'));
      expect(cleaned, contains('optional features'));
    });
  });
}
