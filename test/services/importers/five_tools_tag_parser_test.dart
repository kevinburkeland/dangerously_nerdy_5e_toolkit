import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/five_tools_tag_parser.dart';

void main() {
  group('FiveToolsTagParser', () {
    late FiveToolsTagParser parser;

    setUp(() {
      parser = FiveToolsTagParser();
    });

    test('detects 2014 ruleset provenance', () {
      expect(parser.detectRuleset('PHB'), equals(RulesetVersion.v2014));
      expect(parser.detectRuleset('SRD'), equals(RulesetVersion.v2014));
      expect(parser.detectRuleset('MM'), equals(RulesetVersion.v2014));
      expect(parser.detectRuleset('DMG'), equals(RulesetVersion.v2014));
      expect(parser.detectRuleset('2014'), equals(RulesetVersion.v2014));
    });

    test('detects 2024 ruleset provenance', () {
      expect(parser.detectRuleset('XPHB'), equals(RulesetVersion.v2024));
      expect(parser.detectRuleset('SRD52'), equals(RulesetVersion.v2024));
      expect(parser.detectRuleset('XDMG'), equals(RulesetVersion.v2024));
      expect(parser.detectRuleset('XMM'), equals(RulesetVersion.v2024));
      expect(parser.detectRuleset('2024'), equals(RulesetVersion.v2024));
    });

    test('detects custom / homebrew source', () {
      expect(parser.detectRuleset('KoboldPress'), equals(RulesetVersion.homebrew));
      expect(parser.detectRuleset('MCDM'), equals(RulesetVersion.homebrew));
    });

    test('strips damage tags and extracts evaluation math', () {
      const input = 'Deals {@damage 8d6|fire} damage on a failed save.';
      final result = parser.parseEntries(input);

      expect(result.cleanMarkdown, equals('Deals 8d6 damage on a failed save.'));
      expect(result.extractedMath.length, equals(1));
      expect(result.extractedMath.first.diceFormula, equals('8d6'));
      expect(result.extractedMath.first.damageType, equals(DamageType.fire));
    });

    test('parses spell references with source scoping', () {
      const input = 'Can cast {@spell Fireball|PHB} and {@spell Counterspell|XPHB}.';
      final result = parser.parseEntries(input);

      expect(result.cleanMarkdown, equals('Can cast Fireball and Counterspell.'));
      expect(result.extractedReferences.length, equals(2));
      expect(result.extractedReferences[0].slug, equals('fireball'));
      expect(result.extractedReferences[0].rulesetPreferred, equals(RulesetVersion.v2014));
      expect(result.extractedReferences[1].slug, equals('counterspell'));
      expect(result.extractedReferences[1].rulesetPreferred, equals(RulesetVersion.v2024));
    });

    test('parses monster and item references', () {
      const input = 'Summons a {@creature Goblin|MM} wielding a {@item Longsword|PHB}.';
      final result = parser.parseEntries(input);

      expect(result.cleanMarkdown, equals('Summons a Goblin wielding a Longsword.'));
      expect(result.extractedReferences.length, equals(2));
      expect(result.extractedReferences[0].refType, equals(EntityType.monster));
      expect(result.extractedReferences[1].refType, equals(EntityType.equipment));
    });

    test('parses nested sections, lists, and tables', () {
      final entries = [
        'Introduction text.',
        {
          'type': 'section',
          'name': 'Special Actions',
          'entries': [
            'Sub-action info.',
            {
              'type': 'list',
              'items': [
                'Option 1: {@damage 1d8|radiant}',
                'Option 2: {@damage 1d8|necrotic}',
              ],
            },
          ],
        },
        {
          'type': 'table',
          'caption': 'Dice Matrix',
          'colLabels': ['d6', 'd8'],
          'rows': [
            ['1-3', '4-8'],
          ],
        },
      ];

      final result = parser.parseEntries(entries);
      expect(result.cleanMarkdown, contains('# Special Actions'));
      expect(result.cleanMarkdown, contains('- Option 1: 1d8'));
      expect(result.cleanMarkdown, contains('| d6 | d8 |'));
      expect(result.cleanMarkdown, contains('| 1-3 | 4-8 |'));
      expect(result.extractedMath.length, equals(2));
    });
  });
}
