import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew_persistence_service.dart';

void main() {
  group('Homebrew Backup Comprehensive Ingestion Tests', () {
    test('ingests backup bundle and validates zero unparsed tags and revitalized _copy monsters', () {
      final bundleMap = {
        'schemaVersion': 1,
        'spells': [
          {
            'id': {'slug': 'astral-smite', 'ruleset': 'v2014'},
            'name': 'Astral Smite',
            'level': 2,
            'school': 'Evocation',
            'castingTime': {'cost': 1, 'actionType': 'bonusAction'},
            'range': 'Self',
            'components': {'v': true, 's': false, 'm': false},
            'duration': {'type': 'concentration', 'durationSeconds': 60, 'requiresConcentration': true},
            'descriptionMarkdown': 'Your weapon glows with astral fury dealing {@damage 2d6} damage on hit.',
            'higherLevelsMarkdown': 'Deals {@scaledamage 2d6|2d6|1d6} additional damage per higher slot.',
            'customProperties': {
              'damageInflict': ['radiant'],
              'classes': {
                'fromClassList': [
                  {'name': 'Paladin', 'source': 'PHB'},
                ],
              },
            },
          },
          {
            'id': {'slug': 'force-ray', 'ruleset': 'v2014'},
            'name': 'Force Ray',
            'level': 0,
            'school': 'Evocation',
            'castingTime': {'cost': 1, 'actionType': 'action'},
            'range': '120 feet',
            'components': {'v': true, 's': true, 'm': false},
            'duration': {'type': 'instant', 'durationSeconds': 0, 'requiresConcentration': false},
            'descriptionMarkdown': 'A beam of energy dealing **`1d10 untyped`** force damage.',
            'customProperties': {},
          },
        ],
        'monsters': [
          {
            'id': {'slug': 'animated-guardian-statue', 'ruleset': 'v2014'},
            'name': 'Animated Guardian Statue',
            'size': 'Large',
            'monsterType': 'construct',
            'alignment': 'Unaligned',
            'armorClass': 10,
            'hitPoints': 230,
            'hitDieFormula': '20d10 + 120',
            'challengeRating': '10',
            'actionsMarkdown': '**Speed:** 30 ft.\n\n| STR | DEX | CON | INT | WIS | CHA |\n|:---:|:---:|:---:|:---:|:---:|:---:|\n| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |\n\nMultiattack. {@h}Two attacks. {@recharge 5}',
            'customProperties': {
              '_copy': {'name': 'Stone Golem', 'source': 'MM'},
              'languages': 'understands the languages of its creator',
            },
          },
          {
            'id': {'slug': 'serpent-drake', 'ruleset': 'v2014'},
            'name': 'Serpent Drake',
            'size': 'Medium',
            'monsterType': 'dragon',
            'alignment': 'Neutral',
            'armorClass': 10,
            'hitPoints': 10,
            'hitDieFormula': '8d8',
            'challengeRating': '1/4',
            'actionsMarkdown': '**Speed:** 30 ft.\n\n| STR | DEX | CON | INT | WIS | CHA |\n|:---:|:---:|:---:|:---:|:---:|:---:|\n| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |\n\nBite. {@atk mw} {@hit 5} to hit. {@h}10 ({@damage 2d6 + 3}) piercing damage. {@hitYourSpellAttack}',
            'customProperties': {
              '_copy': {'name': 'Giant Poisonous Snake', 'source': 'MM'},
            },
          },
        ],
        'items': [],
        'classes': [],
        'subclasses': [],
        'races': [],
        'feats': [],
        'backgrounds': [],
      };

      final jsonString = jsonEncode(bundleMap);
      final pipeline = CompendiumJsonIngestionPipeline();
      final result = pipeline.ingestJsonString(jsonString);

      expect(result.spells.length, equals(2));
      expect(result.monsters.length, equals(2));

      // 1. Verify zero unparsed tags in monsters and spells
      int unparsedH = 0;
      int unparsedRecharge = 0;
      int unparsedHitSpell = 0;
      int untypedCount = 0;

      for (final m in result.monsters) {
        if (m.actionsMarkdown.contains('{@h}')) unparsedH++;
        if (m.actionsMarkdown.contains('{@recharge')) unparsedRecharge++;
        if (m.actionsMarkdown.contains('{@hitYourSpellAttack}')) unparsedHitSpell++;
        if (m.actionsMarkdown.contains('untyped')) untypedCount++;
      }

      for (final s in result.spells) {
        final fullDesc = '${s.descriptionMarkdown} ${s.higherLevelsMarkdown ?? ""}';
        if (fullDesc.contains('untyped')) untypedCount++;
        if (fullDesc.contains('{@damage')) unparsedH++;
      }

      expect(unparsedH, equals(0), reason: 'All {@h} and {@damage} tags should be transformed');
      expect(unparsedRecharge, equals(0), reason: 'All {@recharge} tags should be transformed');
      expect(unparsedHitSpell, equals(0), reason: 'All {@hitYourSpellAttack} tags should be transformed');
      expect(untypedCount, equals(0), reason: 'No "untyped" word should leak into markdown text');

      // 2. Verify _copy creature revitalization
      final statue = result.monsters.where((m) => m.name == 'Animated Guardian Statue').firstOrNull;
      expect(statue, isNotNull);
      final statueSb = statue!.toMinionStatBlock();
      // Stone Golem copy inherits AC 17, STR 22, Slam attacks, while preserving specified HP 230
      expect(statueSb.ac, equals(17));
      expect(statueSb.maxHp, equals(230));
      expect(statueSb.strScore, equals(22));
      expect(statueSb.actions.any((a) => a.name.contains('Slam')), isTrue);

      final serpent = result.monsters.where((m) => m.name == 'Serpent Drake').firstOrNull;
      expect(serpent, isNotNull);
      final serpentSb = serpent!.toMinionStatBlock();
      // Giant Poisonous Snake copy inherits DEX 18
      expect(serpentSb.dexScore, equals(18));
      expect(serpentSb.actions.any((a) => a.name.contains('Bite')), isTrue);

      // 3. Verify spell conversion to SpellItem has classes and damage types
      final smiteSpell = result.spells.where((s) => s.name == 'Astral Smite').firstOrNull;
      expect(smiteSpell, isNotNull);
      final spellItem = HomebrewPersistenceService.spellToSpellItem(smiteSpell!);
      expect(spellItem.rules2024.classes, contains(SpellClass.paladin));
    });
  });
}
