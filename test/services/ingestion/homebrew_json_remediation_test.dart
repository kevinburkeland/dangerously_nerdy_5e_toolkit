import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_background_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_feat_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_generic_entry_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_item_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_race_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  group('Homebrew JSON Remediation & Pipeline Enhancement Tests', () {
    test('1. Item Parser decodes shorthand codes, compound pipes, generates fallback MD, and extracts grants', () {
      final parser = CompendiumItemParser();

      // Mundane focus with shorthand code and no entries
      final focus = parser.parseItem({
        'name': 'Arcane Focus, Orb',
        'type': 'SCF',
        'scfType': 'arcane',
        'value': 2000,
        'weight': 3,
        'source': 'PHB',
      });
      expect(focus.itemType, equals('Spellcasting Focus'));
      expect(focus.rarity.toLowerCase(), equals('none'));
      expect(focus.descriptionMarkdown, contains('Type:** Spellcasting Focus'));
      expect(focus.descriptionMarkdown, contains('Value:** 20 gp'));
      expect(focus.descriptionMarkdown, contains('Weight:** 3 lb.'));

      // Magic rod with compound type RD|DMG and bonus weapon / spell attack grants
      final rod = parser.parseItem({
        'name': 'Rod of the Pact Keeper, +2',
        'type': 'RD|DMG',
        'rarity': 'rare',
        'reqAttune': true,
        'bonusSpellAttack': '+2',
        'bonusSpellSaveDc': '+2',
        'entries': [
          'While holding this rod, you gain a +2 bonus to spell attack rolls and to the saving throw DCs of your warlock spells.',
        ],
      });
      expect(rod.itemType, equals('Rod'));
      expect(rod.rarity.toLowerCase(), equals('rare'));
      expect(rod.requiresAttunement, isTrue);
      expect(rod.grants.any((g) => g.payload['stat'] == 'spell_attack' && g.payload['flat'] == 2), isTrue);
      expect(rod.grants.any((g) => g.payload['stat'] == 'spell_save_dc' && g.payload['flat'] == 2), isTrue);

      // Armor with AC bonus and resistance
      final armor = parser.parseItem({
        'name': 'Shield of Warmth',
        'type': 'S',
        'bonusAc': '+1',
        'resist': ['cold'],
        'entries': ['While holding this shield, you have resistance to cold damage.'],
      });
      expect(armor.grants.any((g) => g.type == GrantType.acFormula && g.payload['amount'] == 1), isTrue);
      expect(GrantEvaluator.evaluateResistances(armor.grants), contains('cold'));
    });

    test('2. Race Parser resolves boolean fly speed, modern lineage ASIs, grants, and subrace slug resolution', () {
      final parser = CompendiumRaceParser();

      // Winged race with boolean fly speed
      final winged = parser.parseRace({
        'name': 'Avian Kin Variant',
        'speed': {'walk': 30, 'fly': true},
        'size': ['M'],
        'entries': ['Bird folk.'],
      });
      expect(winged.speed, equals('30 ft. (fly 30 ft.)'));
      expect(winged.speed, isNot(contains('true ft.')));

      // Modern lineage race with flexible ASIs
      final lineage = parser.parseRace({
        'name': 'Gothic Lineage',
        'lineage': 'VRGR',
        'speed': 35,
        'darkvision': 60,
        'resist': ['necrotic'],
        'entries': ['Half vampire creature.'],
      });
      expect(lineage.flexibleAbilityCount, equals(2));
      expect(GrantEvaluator.evaluateDarkvisionFeet(lineage.grants), equals(60));
      expect(GrantEvaluator.evaluateResistances(lineage.grants), contains('necrotic'));

      // Subrace resolving raceSlug from _copy
      final subrace = parser.parseSubrace({
        'name': 'High Elf Variant',
        '_copy': {'name': 'Elf', 'source': 'PHB'},
        'entries': ['A graceful high elf.'],
      });
      expect(subrace.raceSlug, equals('elf'));
      expect(subrace.raceSlug, isNotEmpty);
    });

    test('3. Feat Parser parses 5eTools ability mapping for FeatAsiExtension and extracts grants', () {
      final parser = CompendiumFeatParser();

      // Static single ability feat
      final tenaciousCon = parser.parseFeat({
        'name': 'Tenacious (Constitution)',
        'ability': [
          {'con': 1}
        ],
        'entries': ['Increase your Constitution score by 1.'],
      });
      expect(tenaciousCon.customProperties['statIncreaseAbility'], equals('constitution'));
      expect(tenaciousCon.statIncreaseAmount, equals(1));
      expect(tenaciousCon.selectableAbilities, equals([AbilityType.constitution]));
      expect(tenaciousCon.grants.any((g) => g.type == GrantType.abilityScoreBoost && g.payload['ability'] == 'constitution' && g.payload['amount'] == 1), isTrue);

      // Choose pool ability feat (Actor: Cha +1)
      final actor = parser.parseFeat({
        'name': 'Actor',
        'ability': [
          {
            'choose': {
              'from': ['cha'],
              'count': 1,
              'amount': 1,
            }
          }
        ],
        'entries': ['Skilled at mimicry and drama.'],
      });
      expect(actor.selectableAbilities, equals([AbilityType.charisma]));
      expect(actor.statIncreaseAmount, equals(1));

      // Tough feat HP grant
      final tough = parser.parseFeat({
        'name': 'Tough',
        'category': 'Origin',
        'entries': ['Your hit point maximum increases by an amount equal to twice your level.'],
      });
      expect(tough.category, equals('Origin'));
      expect(tough.grants.any((g) => g.type == GrantType.hpModifier && g.payload['perLevel'] == 2), isTrue);
    });

    test('4. Background Parser resolves _copy against SRD base backgrounds and cleans origin feats', () {
      final parser = CompendiumBackgroundParser();

      // Background with _copy linking to Acolyte and an origin feat with source pipe
      final bg = parser.parseBackground({
        'name': 'Temple Initiate',
        '_copy': {'name': 'Acolyte', 'source': 'PHB'},
        'originFeat': 'Alert|PHB',
        'feats': [{'feat': 'Alert|PHB'}],
      });

      expect(bg.originFeat, equals('Alert'));
      expect(bg.skillProficiencies, containsAll(['Insight', 'Religion']));
      expect(bg.descriptionMarkdown, isNotEmpty);
      expect(GrantEvaluator.evaluateGrantedSkills(bg.grants).map((s) => s.displayName), containsAll(['Insight', 'Religion']));
      expect(bg.grants.any((g) => g.type == GrantType.bonusFeat && g.payload['feat'] == 'Alert'), isTrue);
    });

    test('5. Generic Entry Parser cleans bracketed shorthand tags and extracts featureType', () {
      final parser = CompendiumGenericEntryParser();

      final maneuver = parser.parseGenericEntry({
        'name': 'Trip Attack',
        'featureType': ['MV', 'B'],
        'entries': ['When you make a weapon attack, add the superiority die.'],
      });
      expect(maneuver.category, equals('Maneuver'));

      final invocation = parser.parseGenericEntry({
        'name': 'Agonizing Blast',
        'category': '[EI]',
        'entries': ['Add your Charisma modifier to the damage of eldritch blast.'],
      });
      expect(invocation.category, equals('Eldritch Invocation'));
    });

    test('6. Spell Parser infers expansion spell classes when classes field is missing or empty', () {
      final parser = CompendiumSpellParser();

      final boomingBlade = parser.parseSpell({
        'name': 'Booming Blade',
        'level': 0,
        'school': 'V',
        'entries': ['You brandish the weapon used in the spell\'s casting.'],
      });
      expect(boomingBlade.customProperties['classes'], containsAll(['Artificer', 'Sorcerer', 'Warlock', 'Wizard']));

      final bladeOfDisaster = parser.parseSpell({
        'name': 'Blade of Disaster',
        'level': 9,
        'school': 'C',
        'entries': ['You create a blade-shaped planar rift.'],
      });
      expect(bladeOfDisaster.customProperties['classes'], containsAll(['Sorcerer', 'Warlock', 'Wizard']));
    });

    test('7. CompendiumJsonIngestionPipeline revitalizes HomebrewBundle and prevents empty subrace slugs', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final bundleJson = {
        'items': [
          {
            'name': 'Holy Symbol, Amulet',
            'type': 'SCF',
            'scfType': 'holy',
            'value': 500,
          }
        ],
        'races': [
          {
            'name': 'Winged Variant',
            'speed': {'walk': 30, 'fly': true},
          }
        ],
        'subraces': [
          {
            'name': 'Wood Elf Variant',
            '_copy': {'name': 'Elf', 'source': 'PHB'},
          },
          {
            'name': 'Ghost Subrace without Base',
            // Missing _copy and raceName
          }
        ],
        'feats': [
          {
            'name': 'Mobile',
            'ability': [{'choose': {'from': ['dex'], 'count': 1, 'amount': 1}}],
          }
        ],
        'backgrounds': [
          {
            'name': 'Bounty Hunter Copy',
            '_copy': {'name': 'Acolyte', 'source': 'PHB'},
            'originFeat': 'Skilled|PHB',
          }
        ],
        'otherEntries': [
          {
            'name': 'Repelling Blast',
            'featureType': ['EI'],
          }
        ],
      };

      final compendium = pipeline.ingestJsonMap(bundleJson);

      // Verify item revitalization
      expect(compendium.items.first.itemType, equals('Spellcasting Focus'));
      expect(compendium.items.first.descriptionMarkdown, isNotEmpty);

      // Verify race revitalization
      expect(compendium.races.first.speed, equals('30 ft. (fly 30 ft.)'));

      // Verify subraces: ghost subrace without raceSlug skipped, Wood Elf Variant attached to Elf
      final elf = compendium.races.firstWhere((r) => r.id.slug == 'elf');
      expect(elf.subraces.length, equals(1));
      expect(elf.subraces.first.name, equals('Wood Elf Variant'));
      expect(compendium.races.any((r) => r.id.slug.isEmpty || r.id.slug == 'ghost-subrace-without-base'), isFalse);

      // Verify feats revitalization
      expect(compendium.feats.first.selectableAbilities, equals([AbilityType.dexterity]));

      // Verify backgrounds revitalization
      expect(compendium.backgrounds.first.originFeat, equals('Skilled'));
      expect(compendium.backgrounds.first.skillProficiencies, contains('Insight'));

      // Verify generic entry revitalization
      expect(compendium.otherEntries.first.category, equals('Eldritch Invocation'));
    });

    test('8. CompendiumJsonIngestionPipeline revitalizes existing HomebrewBundle exports', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final bundleExportJson = {
        'schemaVersion': 1,
        'appVersion': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'bundleName': 'Test Bundle',
        'items': [
          {
            'id': {'slug': 'crystal-focus', 'ruleset': 'homebrew'},
            'name': 'Crystal Focus',
            'itemType': 'SCF',
            'rarity': 'Common',
            'descriptionMarkdown': '',
            'customProperties': {'scfType': 'arcane', 'value': 1000},
          }
        ],
        'races': [
          {
            'id': {'slug': 'fairy-race', 'ruleset': 'homebrew'},
            'name': 'Fairy Race',
            'traitsMarkdown': '',
            'speed': '30 ft.',
            'customProperties': {'speed': {'walk': 30, 'fly': true}},
          }
        ],
        'feats': [
          {
            'id': {'slug': 'telekinetic', 'ruleset': 'homebrew'},
            'name': 'Telekinetic',
            'descriptionMarkdown': 'Learn mage hand.',
            'category': 'General',
            'customProperties': {
              'ability': [
                {
                  'choose': {'from': ['int', 'wis', 'cha'], 'count': 1, 'amount': 1}
                }
              ]
            },
          }
        ],
        'backgrounds': [
          {
            'id': {'slug': 'citadel-warden', 'ruleset': 'homebrew'},
            'name': 'Citadel Warden',
            'descriptionMarkdown': '',
            'customProperties': {
              '_copy': {'name': 'Guard', 'source': 'PHB'},
              'originFeat': 'Alert|PHB',
            }
          }
        ],
        'otherEntries': [
          {
            'id': {'slug': 'repelling-blast', 'ruleset': 'homebrew'},
            'name': 'Repelling Blast',
            'category': '[EI]',
            'descriptionMarkdown': '',
            'customProperties': {'featureType': ['EI']},
          }
        ],
      };

      final compendium = pipeline.ingestJsonMap(bundleExportJson);

      // Verify revitalization across all 5 categories
      expect(compendium.items.first.itemType, equals('Spellcasting Focus'));
      expect(compendium.items.first.descriptionMarkdown, isNotEmpty);
      expect(compendium.races.first.speed, equals('30 ft. (fly 30 ft.)'));
      expect(compendium.feats.first.selectableAbilities, containsAll([AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma]));
      expect(compendium.backgrounds.first.originFeat, equals('Alert'));
      expect(compendium.otherEntries.first.category, equals('Eldritch Invocation'));
    });

    test('9. _copy monster revitalization inherits base stats, extracts markdown actions, and applies replaceArr', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final bundleJson = {
        'schemaVersion': 1,
        'monsters': [
          {
            'name': 'Troglodyte',
            'armorClass': 11,
            'hitPoints': 13,
            'challengeRating': '1/4',
            'actionsMarkdown': '''**Speed:** walk 30ft.

| STR | DEX | CON | INT | WIS | CHA |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 14 (+2) | 10 (+0) | 14 (+2) | 6 (-2) | 10 (+0) | 6 (-2) |

### Traits
**Chameleon Skin**: Advantage on Stealth checks.

**Stench**: Poison stench aura.

### Actions
**Multiattack**: The troglodyte makes three attacks: one with its bite and two with its claws.

**Bite**: Melee Weapon Attack: +4 to hit. Hit: 4 (1d4 + 2) piercing damage.

**Claw**: Melee Weapon Attack: +4 to hit. Hit: 4 (1d4 + 2) slashing damage.''',
            'customProperties': {'speed': '30 ft.'},
          },
          {
            'name': 'Armored Troglodyte',
            'armorClass': 14,
            'hitPoints': 10,
            'challengeRating': '0',
            'actionsMarkdown': '''**Speed:** 30 ft.

| STR | DEX | CON | INT | WIS | CHA |
|:---:|:---:|:---:|:---:|:---:|:---:|
| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |''',
            'customProperties': {
              '_copy': {
                'name': 'Troglodyte',
                'source': 'MM',
                '_mod': {
                  'action': [
                    {
                      'mode': 'replaceArr',
                      'replace': 'Multiattack',
                      'items': {
                        'name': 'Multiattack',
                        'entries': ['The troglodyte makes two attacks with its longsword.'],
                      },
                    },
                    {
                      'mode': 'replaceArr',
                      'replace': 'Claw',
                      'items': {
                        'name': 'Longsword',
                        'entries': ['{@atk mw} {@hit 4} to hit. {@h}6 ({@damage 1d8 + 2}) slashing damage.'],
                      },
                    },
                  ],
                },
              },
            },
          },
        ],
      };

      final result = pipeline.ingestJsonMap(bundleJson);
      final armored = result.monsters.firstWhere((m) => m.name == 'Armored Troglodyte');

      expect(armored.armorClass, equals(14)); // Custom override
      expect(armored.hitPoints, equals(13)); // Inherited base HP
      expect(armored.challengeRating, equals('1/4')); // Inherited base CR
      expect(armored.actionsMarkdown, contains('14 (+2)')); // Inherited STR 14
      expect(armored.actionsMarkdown, contains('Chameleon Skin')); // Inherited trait
      expect(armored.actionsMarkdown, contains('Longsword')); // Replaced action
      expect(armored.actionsMarkdown, contains('two attacks with its longsword')); // Replaced Multiattack
    });

    test('10. EntryNodeTransformer and Monster Parser infer damageType from trailing text and action context', () {
      final transformer = EntryNodeTransformer();
      const text = 'Bite. {@atk mw} {@hit 5} to hit. {@h}5 ({@damage 1d4 + 3}) bludgeoning damage plus 2 ({@damage 1d4}) fire damage.';
      final result = transformer.transformEntries(text);

      expect(result.extractedMath.length, equals(2));
      expect(result.extractedMath[0].damageType, equals(DamageType.bludgeoning));
      expect(result.extractedMath[1].damageType, equals(DamageType.fire));
      expect(result.markdown, isNot(contains('bludgeoning bludgeoning')));
    });

    test('11. CompendiumSpellParser resolves classes for XGE/EGW/FTD expansion spells', () {
      final parser = CompendiumSpellParser();

      final horridWilting = parser.parseSpell({
        'name': "Abi-Dalzim's Horrid Wilting",
        'level': 8,
        'school': 'N',
        'entries': ['A sphere of deadly energy drains water.'],
      });
      expect(horridWilting.customProperties['classes'], containsAll(['Sorcerer', 'Wizard']));

      final catnap = parser.parseSpell({
        'name': 'Catnap',
        'level': 3,
        'school': 'E',
        'entries': ['Creatures fall into a sleep resembling a short rest.'],
      });
      expect(catnap.customProperties['classes'], containsAll(['Artificer', 'Bard', 'Sorcerer', 'Wizard']));

      final darkStar = parser.parseSpell({
        'name': 'Dark Star',
        'level': 8,
        'school': 'V',
        'entries': ['This spell creates a sphere of crushing gravity.'],
      });
      expect(darkStar.customProperties['classes'], contains('Wizard'));
    });

    test('12. Item revitalization cleans rechargeAmount and unparsed description tags', () {
      final pipeline = CompendiumJsonIngestionPipeline();

      final bundleJson = {
        'items': [
          {
            'name': 'Abracadabrus',
            'type': 'Wondrous Item',
            'rarity': 'Rare',
            'descriptionMarkdown': '> **Note:** Paired with {@item Silver Horn of Valhalla}',
            'customProperties': {
              'rechargeAmount': '{@dice 1d20}',
            },
          }
        ],
      };

      final result = pipeline.ingestJsonMap(bundleJson);
      final item = result.items.first;

      expect(item.customProperties['rechargeAmount'], equals('1d20'));
      expect(item.descriptionMarkdown, contains('Silver Horn of Valhalla'));
      expect(item.descriptionMarkdown, isNot(contains('{@item')));
    });

    test('13. Spell Parser and Ingestion revitalize distance and geometry when rangeDistanceFeet is 0 but text has range', () {
      final parser = CompendiumSpellParser();

      // Case A: 5etools object range with point and 150 feet
      final astralRay = parser.parseSpell({
        'name': 'Astral Ray',
        'level': 2,
        'school': 'V',
        'range': {
          'type': 'point',
          'distance': {'type': 'feet', 'amount': 150}
        },
        'entries': ['You fire a ray of astral power.'],
      });
      expect(astralRay.rangeDistanceFeet, equals(150));
      expect(astralRay.rangeType, equals('ranged'));

      // Case B: Geometry range - line 100 feet
      final voidLance = parser.parseSpell({
        'name': 'Void Lance',
        'level': 3,
        'school': 'V',
        'range': {
          'type': 'line',
          'distance': {'type': 'feet', 'amount': 100}
        },
        'entries': ['A beam of void energy 100 feet long and 5 feet wide shoots forth.'],
      });
      expect(voidLance.rangeDistanceFeet, equals(100));
      expect(voidLance.rangeType, equals('line'));

      // Case C: Pipeline revitalization of a bundle with string range
      final pipeline = CompendiumJsonIngestionPipeline();
      final bundleJson = {
        'spells': [
          {
            'name': 'Gravity Pulse',
            'level': 1,
            'school': 'V',
            'range': '30 feet',
            'rangeDistanceFeet': 0,
            'entries': ['A wave of gravitational force ripples outward 30 feet.'],
          }
        ]
      };
      final result = pipeline.ingestJsonMap(bundleJson);
      final pulse = result.spells.first;
      expect(pulse.rangeDistanceFeet, equals(30));
    });

    test('14. Feat Parser extracts nested daily/ritual bonus spells, skill choices, and tool proficiencies', () {
      final parser = CompendiumFeatParser();

      final featJson = {
        'name': 'Arcane Tinkerer',
        'additionalSpells': [
          {
            'innate': {
              '1': {
                'daily': {
                  '1e': ['detect magic'],
                },
                '_': ['light'],
              },
            },
          },
        ],
        'skillProficiencies': [
          {
            'choose': {
              'from': ['arcana', 'investigation', 'history'],
              'count': 1,
            }
          }
        ],
        'toolProficiencies': [
          {
            'tinkers tools': true,
          }
        ]
      };

      final feat = parser.parseFeat(featJson);
      expect(feat.name, equals('Arcane Tinkerer'));

      // Bonus spells extracted recursively
      final bonusSpells = feat.grants.where((g) => g.type == GrantType.bonusSpell).toList();
      final spellNames = bonusSpells.map((g) => g.payload['slug']).toList();
      expect(spellNames, contains('detect-magic'));
      expect(spellNames, contains('light'));

      // Skill choice extracted
      final skillChoices = feat.grants.where((g) => g.type == GrantType.bonusSkillChoice).toList();
      expect(skillChoices, isNotEmpty);
      expect(skillChoices.first.payload['pool'], containsAll(['arcana', 'investigation', 'history']));
      expect(skillChoices.first.payload['count'], equals(1));

      // Tool proficiency extracted
      final toolProf = feat.grants.where((g) => g.type == GrantType.proficiency).toList();
      expect(toolProf.any((g) => (g.payload['proficiency']?.toString() ?? '').toLowerCase().contains('tinkers tools')), isTrue);
    });

    test('15. Background Parser and Ingestion pipeline inherit skills, tools, and origin feat from base when empty lists are provided', () {
      final parser = CompendiumBackgroundParser();

      // Ingesting a background that copies Acolyte with empty arrays
      final childBg = parser.parseBackground({
        'name': 'Temple Pilgrim',
        '_copy': {'name': 'Acolyte', 'source': 'PHB'},
        'skillProficiencies': [],
        'toolProficiencies': [],
        'languageProficiencies': [],
        'originFeat': null,
      });

      // Should have inherited from Acolyte base
      expect(childBg.skillProficiencies, containsAll(['Insight', 'Religion']));
      expect(childBg.toolProficiencies, contains('Calligrapher\'s Supplies'));
      expect(childBg.languages, contains('Celestial'));
      expect(childBg.originFeat, equals('Magic Initiate (Cleric)'));

      // Pipeline verification ensures revitalized bundle preserves inherited properties
      final pipeline = CompendiumJsonIngestionPipeline();
      final bundleJson = {
        'backgrounds': [
          {
            'name': 'Shrine Keeper',
            '_copy': {'name': 'Acolyte', 'source': 'PHB'},
            'skillProficiencies': [],
            'toolProficiencies': [],
          }
        ]
      };
      final result = pipeline.ingestJsonMap(bundleJson);
      final shrineKeeper = result.backgrounds.first;
      expect(shrineKeeper.skillProficiencies, containsAll(['Insight', 'Religion']));
      expect(shrineKeeper.toolProficiencies, contains('Calligrapher\'s Supplies'));
    });

    test('16. SubclassSpellsLibrary resolveFilterSpells matches source=EGW and Dunamancy spell tags', () {
      const chronoSpell = SpellItem(
        id: 'temporal-shunt',
        name: 'Temporal Shunt',
        level: 5,
        school: SpellSchool.transmutation,
        rules2014: SpellEditionDetails(
          castingTime: '1 reaction',
          range: '120 feet',
          components: 'V, S',
          duration: '1 round',
          description: ['You target the triggering creature and shunt it through time.'],
          classes: [SpellClass.wizard],
        ),
        rules2024: SpellEditionDetails(
          castingTime: '1 reaction',
          range: '120 feet',
          components: 'V, S',
          duration: '1 round',
          description: ['You target the triggering creature and shunt it through time.'],
          classes: [SpellClass.wizard],
        ),
        tags: ['dft', 'source:egw'],
      );

      const normalSpell = SpellItem(
        id: 'custom-spark',
        name: 'Custom Spark',
        level: 1,
        school: SpellSchool.evocation,
        rules2014: SpellEditionDetails(
          castingTime: '1 action',
          range: '30 feet',
          components: 'V, S',
          duration: 'Instantaneous',
          description: ['A burst of sparks.'],
          classes: [SpellClass.wizard],
        ),
        rules2024: SpellEditionDetails(
          castingTime: '1 action',
          range: '30 feet',
          components: 'V, S',
          duration: 'Instantaneous',
          description: ['A burst of sparks.'],
          classes: [SpellClass.wizard],
        ),
        tags: ['phb'],
      );

      SpellbookLibrary.setHomebrewSpells([chronoSpell, normalSpell]);
      addTearDown(() => SpellbookLibrary.setHomebrewSpells([]));

      final matched = SubclassSpellsLibrary.resolveFilterSpells('source=EGW');

      expect(matched.map((s) => s.id), contains('temporal-shunt'));
      expect(matched.map((s) => s.id), isNot(contains('custom-spark')));
    });

    test('17. Feat Parser and Feat.fromMap extract bonus spells from nested choose/from structures and auto-heal empty grants', () {
      final parser = CompendiumFeatParser();

      // Feat with nested choose from list
      final featJson = {
        'name': 'Arcane Apprentice',
        'additionalSpells': [
          {
            'innate': {
              '1': {
                'daily': {
                  '1e': [
                    {
                      'choose': {
                        'from': ['shield', 'mage armor', 'feather fall'],
                        'count': 1,
                      }
                    }
                  ],
                },
              },
            },
          },
        ],
      };

      final parsed = parser.parseFeat(featJson);
      final bonusSpells = parsed.grants.where((g) => g.type == GrantType.bonusSpell).toList();
      final slugs = bonusSpells.map((g) => g.payload['slug']).toList();
      expect(slugs, contains('shield'));
      expect(slugs, contains('mage-armor'));
      expect(slugs, contains('feather-fall'));

      // Deserialization with Feat.fromMap auto-heals when grants list was empty in pack JSON
      final serializedMap = {
        'id': {'slug': 'arcane-apprentice', 'ruleset': 'homebrew'},
        'name': 'Arcane Apprentice',
        'grants': [],
        'customProperties': {
          'additionalSpells': featJson['additionalSpells'],
        },
      };

      final fromMapFeat = Feat.fromMap(serializedMap);
      expect(fromMapFeat.grants, isNotEmpty);
      expect(fromMapFeat.grants.map((g) => g.payload['slug']), contains('shield'));
    });

    test('18. Spell.toMap losslessly preserves classes and revitalized rangeDistanceFeet for round-trip exports', () {
      final spellMap = {
        'name': 'Cosmic Flare',
        'level': 4,
        'school': 'V',
        'range': '150 feet',
        'rangeDistanceFeet': 0,
        'customProperties': {
          'classes': ['Sorcerer', 'Wizard'],
        },
      };

      final spell = Spell.fromMap(spellMap);
      expect(spell.rangeDistanceFeet, equals(150));

      final exported = spell.toMap();
      expect(exported['classes'], containsAll(['Sorcerer', 'Wizard']));
      expect(exported['rangeDistanceFeet'], equals(150));
    });

    test('19. Background Parser resolves in-bundle background copies and applies SRD 5.1 customization fallback when base is external', () {
      final parser = CompendiumBackgroundParser();

      // Case A: Resolving base background from in-bundle lookup
      final customBase = parser.parseBackground({
        'name': 'Guild Artisan Base',
        'skillProficiencies': ['Insight', 'Persuasion'],
        'toolProficiencies': ['Smith\'s Tools'],
      });

      final childWithInBundleBase = parser.parseBackground(
        {
          'name': 'City Smith Variant',
          '_copy': {'name': 'Guild Artisan Base'},
          'skillProficiencies': [],
          'toolProficiencies': [],
        },
        localLookup: {'guild-artisan-base': customBase},
      );

      expect(childWithInBundleBase.skillProficiencies, containsAll(['Insight', 'Persuasion']));
      expect(childWithInBundleBase.toolProficiencies, contains('Smith\'s Tools'));

      // Case B: Copying un-imported base applies SRD 5.1 "Customizing a Background" rule (Choose 2 skills)
      final childWithExternalBase = parser.parseBackground({
        'name': 'Wanderer Variant',
        '_copy': {'name': 'External Unimported Base'},
        'skillProficiencies': [],
        'toolProficiencies': [],
      });

      expect(childWithExternalBase.skillProficiencies, contains('Choose 2'));
      final skillChoice = childWithExternalBase.grants.where((g) => g.type == GrantType.bonusSkillChoice).toList();
      expect(skillChoice, isNotEmpty);
      expect(skillChoice.first.payload['count'], equals(2));
    });
  });
}


