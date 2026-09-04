import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/spell_monster_equipment.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_monster_parser.dart';

void main() {
  group('CompendiumMonsterParser Copy Resolution & Stats Tests', () {
    late CompendiumMonsterParser parser;

    setUp(() {
      parser = CompendiumMonsterParser();
    });

    test('preserves ability scores, speed, defenses, and senses in customProperties', () {
      final raw = {
        'name': 'Ironfang Beast',
        'source': 'HOMEBREW',
        'size': 'L',
        'type': 'monstrosity',
        'alignment': 'Unaligned',
        'ac': 16,
        'hp': {'average': 85, 'formula': '10d10 + 30'},
        'speed': {'walk': 40, 'swim': 30},
        'str': 18,
        'dex': 14,
        'con': 16,
        'int': 3,
        'wis': 12,
        'cha': 7,
        'cr': '5',
        'save': {'con': '+6', 'wis': '+4'},
        'skill': {'perception': '+4', 'stealth': '+5'},
        'resist': ['cold', 'fire'],
        'immune': ['poison'],
        'conditionImmune': ['poisoned'],
        'senses': ['darkvision 60 ft.'],
        'passive': 14,
        'languages': ['understands Draconic but cannot speak'],
        'action': [
          {
            'name': 'Bite {@recharge 5}',
            'entries': ['{@atk mw} {@hit 7} to hit. {@h}15 ({@damage 2d10 + 4|piercing}) piercing damage.'],
          }
        ],
      };

      final monster = parser.parseMonster(raw);

      // Verify customProperties
      expect(monster.customProperties['speed'], equals('walk 40ft., swim 30ft.'));
      expect(monster.customProperties['str'], equals(18));
      expect(monster.customProperties['dex'], equals(14));
      expect(monster.customProperties['con'], equals(16));
      expect(monster.customProperties['int'], equals(3));
      expect(monster.customProperties['savingThrows'], equals('CON +6, WIS +4'));
      expect(monster.customProperties['skills'], equals('perception +4, stealth +5'));
      expect(monster.customProperties['damageResistances'], equals('cold, fire'));
      expect(monster.customProperties['damageImmunities'], equals('poison'));
      expect(monster.customProperties['conditionImmunities'], equals('poisoned'));
      expect(monster.customProperties['senses'], equals('darkvision 60 ft., passive Perception 14'));
      expect(monster.customProperties['languages'], equals('understands Draconic but cannot speak'));

      // Verify action name tag parsing
      expect(monster.actionsMarkdown, contains('**Bite *(Recharge 5–6)***:'));
      expect(monster.actionsMarkdown, isNot(contains('{@recharge')));
      expect(monster.actionsMarkdown, isNot(contains('{@h}')));

      // Verify conversion to MinionStatBlock
      final statBlock = monster.toMinionStatBlock();
      expect(statBlock.strScore, equals(18));
      expect(statBlock.dexScore, equals(14));
      expect(statBlock.conScore, equals(16));
      expect(statBlock.intScore, equals(3));
      expect(statBlock.speed, equals('walk 40ft., swim 30ft.'));
      expect(statBlock.savingThrows, equals('CON +6, WIS +4'));
      expect(statBlock.skills, equals('perception +4, stealth +5'));
      expect(statBlock.damageResistances, equals('cold, fire'));
      expect(statBlock.damageImmunities, equals('poison'));
      expect(statBlock.conditionImmunities, equals('poisoned'));
      expect(statBlock.senses, equals('darkvision 60 ft., passive Perception 14'));
    });

    test('resolves monster using _copy against SRD base monster with _mod', () {
      final childRaw = {
        'name': 'Animated Spider Idol',
        'source': 'HOMEBREW',
        '_copy': {
          'name': 'Stone Golem',
          'source': 'MM',
          '_mod': {
            '*': {
              'mode': 'replaceTxt',
              'replace': 'golem',
              'with': 'statue',
            },
            'trait': {
              'mode': 'appendArr',
              'items': {
                'name': 'Spider Climb',
                'entries': ['The statue can climb difficult surfaces without needing an ability check.'],
              },
            },
          },
        },
        'languages': ['understands Abyssal but cannot speak'],
      };

      final monster = parser.parseMonster(childRaw);

      // Verify Stone Golem base stats inherited
      expect(monster.armorClass, equals(17));
      expect(monster.hitPoints, equals(178));
      expect(monster.challengeRating, equals('10'));
      expect(monster.actionsMarkdown, contains('Spider Climb'));
      expect(monster.actionsMarkdown, contains('Slam'));
      expect(monster.customProperties['languages'], equals('understands Abyssal but cannot speak'));

      // Verify MinionStatBlock conversion
      final sb = monster.toMinionStatBlock();
      expect(sb.ac, equals(17));
      expect(sb.maxHp, equals(178));
      expect(sb.strScore, equals(22)); // Stone Golem STR
      expect(sb.actions.any((a) => a.name.contains('Slam')), isTrue);
      expect(sb.traits.any((t) => t.name.contains('Spider Climb') || t.description.contains('Spider Climb')), isTrue);
    });

    test('revitalizes _copy creature from backup bundle where actions were empty', () {
      // Simulates creature from ~/homebrew.json where actionsMarkdown was only table and stats were 10
      final backupMonster = Monster(
        id: const EntityId(slug: 'animated-spider-idol', ruleset: RulesetVersion.v2014),
        name: 'Animated Spider Idol',
        size: 'Large',
        monsterType: 'construct',
        alignment: 'Unaligned',
        armorClass: 10,
        hitPoints: 10,
        hitDieFormula: '10d10',
        challengeRating: '0',
        actionsMarkdown: '**Speed:** 30 ft.\n\n| STR | DEX | CON | INT | WIS | CHA |\n|:---:|:---:|:---:|:---:|:---:|:---:|\n| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |',
        customProperties: {
          '_copy': {'name': 'Stone Golem', 'source': 'MM'},
          'languages': 'understands Abyssal',
        },
      );

      final sb = backupMonster.toMinionStatBlock();
      expect(sb.ac, equals(17));
      expect(sb.maxHp, equals(178));
      expect(sb.strScore, equals(22));
      expect(sb.actions.any((a) => a.name.contains('Slam')), isTrue);
    });
  });
}
