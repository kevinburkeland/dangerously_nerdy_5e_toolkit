import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/feature_grant.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_background_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_feat_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_generic_entry_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_item_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_race_parser.dart';
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
        'name': 'Aarakocra Variant',
        'speed': {'walk': 30, 'fly': true},
        'size': ['M'],
        'entries': ['Bird folk.'],
      });
      expect(winged.speed, equals('30 ft. (fly 30 ft.)'));
      expect(winged.speed, isNot(contains('true ft.')));

      // Modern lineage race with flexible ASIs
      final lineage = parser.parseRace({
        'name': 'Dhampir Lineage',
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
      final resilientCon = parser.parseFeat({
        'name': 'Resilient (Constitution)',
        'ability': [
          {'con': 1}
        ],
        'entries': ['Increase your Constitution score by 1.'],
      });
      expect(resilientCon.customProperties['statIncreaseAbility'], equals('constitution'));
      expect(resilientCon.statIncreaseAmount, equals(1));
      expect(resilientCon.selectableAbilities, equals([AbilityType.constitution]));
      expect(resilientCon.grants.any((g) => g.type == GrantType.abilityScoreBoost && g.payload['ability'] == 'constitution' && g.payload['amount'] == 1), isTrue);

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

      // Background with _copy linking to Criminal and an origin feat with source pipe
      final bg = parser.parseBackground({
        'name': 'Baldur\'s Gate Criminal',
        '_copy': {'name': 'Criminal', 'source': 'PHB'},
        'originFeat': 'Alert|PHB',
        'feats': [{'feat': 'Alert|PHB'}],
      });

      expect(bg.originFeat, equals('Alert'));
      expect(bg.skillProficiencies, containsAll(['Deception', 'Stealth']));
      expect(bg.toolProficiencies, contains('Thieves\' Tools'));
      expect(bg.descriptionMarkdown, isNotEmpty);
      expect(GrantEvaluator.evaluateGrantedSkills(bg.grants).map((s) => s.displayName), containsAll(['Deception', 'Stealth']));
      expect(bg.grants.any((g) => g.type == GrantType.bonusFeat && g.payload['feat'] == 'Alert'), isTrue);
    });

    test('5. Generic Entry Parser cleans bracketed shorthand tags and extracts featureType', () {
      final parser = CompendiumGenericEntryParser();

      final maneuver = parser.parseGenericEntry({
        'name': 'Ambush',
        'featureType': ['MV', 'B'],
        'entries': ['When you make a Dexterity (Stealth) check, add the superiority die.'],
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

      final causticBrew = parser.parseSpell({
        'name': 'Tasha\'s Caustic Brew',
        'level': 1,
        'school': 'V',
        'entries': ['A stream of acid emanates from you.'],
      });
      expect(causticBrew.customProperties['classes'], containsAll(['Artificer', 'Sorcerer', 'Wizard']));

      final bladeOfDisaster = parser.parseSpell({
        'name': 'Blade of Disaster',
        'level': 9,
        'school': 'C',
        'entries': ['You create a blade-shaped planar rift.'],
      });
      expect(bladeOfDisaster.customProperties['classes'], containsAll(['Sorcerer', 'Warlock', 'Wizard']));
    });

    test('7. CompendiumJsonIngestionPipeline revitalizes HomebrewBundle and prevents empty subrace slugs', () async {
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
            'name': 'Sun Elf',
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
            'name': 'Urban Bounty Hunter Copy',
            '_copy': {'name': 'Criminal', 'source': 'PHB'},
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

      final compendium = await pipeline.ingestJsonMap(bundleJson);

      // Verify item revitalization
      expect(compendium.items.first.itemType, equals('Spellcasting Focus'));
      expect(compendium.items.first.descriptionMarkdown, isNotEmpty);

      // Verify race revitalization
      expect(compendium.races.first.speed, equals('30 ft. (fly 30 ft.)'));

      // Verify subraces: ghost subrace without raceSlug skipped, Sun Elf attached to Elf
      final elf = compendium.races.firstWhere((r) => r.id.slug == 'elf');
      expect(elf.subraces.length, equals(1));
      expect(elf.subraces.first.name, equals('Sun Elf'));
      expect(compendium.races.any((r) => r.id.slug.isEmpty || r.id.slug == 'ghost-subrace-without-base'), isFalse);

      // Verify feats revitalization
      expect(compendium.feats.first.selectableAbilities, equals([AbilityType.dexterity]));

      // Verify backgrounds revitalization
      expect(compendium.backgrounds.first.originFeat, equals('Skilled'));
      expect(compendium.backgrounds.first.skillProficiencies, contains('Deception'));

      // Verify generic entry revitalization
      expect(compendium.otherEntries.first.category, equals('Eldritch Invocation'));
    });

    test('8. CompendiumJsonIngestionPipeline revitalizes existing HomebrewBundle exports', () async {
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
            'id': {'slug': 'gate-warden', 'ruleset': 'homebrew'},
            'name': 'Gate Warden',
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

      final compendium = await pipeline.ingestJsonMap(bundleExportJson);

      // Verify revitalization across all 5 categories
      expect(compendium.items.first.itemType, equals('Spellcasting Focus'));
      expect(compendium.items.first.descriptionMarkdown, isNotEmpty);
      expect(compendium.races.first.speed, equals('30 ft. (fly 30 ft.)'));
      expect(compendium.feats.first.selectableAbilities, containsAll([AbilityType.intelligence, AbilityType.wisdom, AbilityType.charisma]));
      expect(compendium.backgrounds.first.originFeat, equals('Alert'));
      expect(compendium.otherEntries.first.category, equals('Eldritch Invocation'));
    });
  });
}

