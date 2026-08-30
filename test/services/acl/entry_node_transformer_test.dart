import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';

void main() {
  group('EntryNodeTransformer AST & Tag Processing Tests', () {
    late EntryNodeTransformer transformer;

    setUp(() {
      transformer = EntryNodeTransformer();
    });

    test('transforms basic string entries with inline tags to markdown and math', () {
      const input = 'Deals {@damage 2d6|fire} damage and forces a {@dc 15} saving throw.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, equals('Deals **`2d6 fire`** damage and forces a DC 15 saving throw.'));
      expect(result.extractedMath.length, equals(1));
      expect(result.extractedMath.first.diceFormula, equals('2d6'));
      expect(result.extractedMath.first.damageType, equals(DamageType.fire));
    });

    test('extracts entity references for spells, items, monsters, and feats', () {
      const input = 'Cast {@spell Fireball} or equip {@item Longsword} against a {@creature Goblin} with {@feat Alert}.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('[Fireball](ref://spell/fireball)'));
      expect(result.markdown, contains('[Longsword](ref://equipment/longsword)'));
      expect(result.markdown, contains('[Goblin](ref://monster/goblin)'));
      expect(result.markdown, contains('[Alert](ref://feat/alert)'));

      expect(result.extractedRefs.any((r) => r.slug == 'fireball' && r.refType == EntityType.spell), isTrue);
      expect(result.extractedRefs.any((r) => r.slug == 'longsword' && r.refType == EntityType.equipment), isTrue);
      expect(result.extractedRefs.any((r) => r.slug == 'goblin' && r.refType == EntityType.monster), isTrue);
      expect(result.extractedRefs.any((r) => r.slug == 'alert' && r.refType == EntityType.feat), isTrue);
    });

    test('transforms complex nested node types (section, inset, list, table)', () {
      final input = [
        {
          'type': 'section',
          'name': 'Combat Tactics',
          'entries': [
            'Basic tactics for skirmishers.',
            {
              'type': 'inset',
              'name': 'Tactical Tip',
              'entries': ['Always maintain high ground.']
            },
            {
              'type': 'list',
              'style': 'list-decimal',
              'items': ['Advance', 'Flank', 'Retreat']
            },
            {
              'type': 'table',
              'caption': 'Loot Roll',
              'colLabels': ['d6', 'Item'],
              'rows': [
                ['1', '10 gp'],
                ['2', 'Potion of Healing']
              ]
            }
          ]
        }
      ];

      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('### Combat Tactics'));
      expect(result.markdown, contains('> **Tactical Tip**'));
      expect(result.markdown, contains('> Always maintain high ground.'));
      expect(result.markdown, contains('1. Advance'));
      expect(result.markdown, contains('2. Flank'));
      expect(result.markdown, contains('3. Retreat'));
      expect(result.markdown, contains('**Loot Roll**'));
      expect(result.markdown, contains('| d6 | Item |'));
      expect(result.markdown, contains('| 1 | 10 gp |'));
      expect(result.markdown, contains('| 2 | Potion of Healing |'));
    });

    test('renders abilityGeneric / abilityScore node cleanly', () {
      final input = {
        'type': 'abilityScore',
        'name': 'Ability Score Improvement',
        'str': 2,
        'con': 1,
      };

      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('**Ability Score Improvement.** STR +2, CON +1'));
    });
  });
}
