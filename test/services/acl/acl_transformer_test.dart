import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_tag_transformer.dart';

void main() {
  group('EntryTagTransformer Tests', () {
    late EntryTagTransformer transformer;

    setUp(() {
      transformer = EntryTagTransformer();
    });

    test('parses simple text entries without tags', () {
      final entries = ['A simple fireball explodes in the area.'];
      final result = transformer.transformEntries(entries);

      expect(result.markdown, equals('A simple fireball explodes in the area.'));
      expect(result.extractedMath, isEmpty);
      expect(result.extractedRefs, isEmpty);
    });

    test('extracts dice math and damage tags accurately', () {
      final entries = [
        'A target takes {@damage 8d6|fire} damage on a failed save, or half on success.',
        'You also roll {@dice 1d20+5} to hit.'
      ];
      final result = transformer.transformEntries(entries);

      expect(
        result.markdown,
        contains('A target takes **`8d6 fire`** damage on a failed save'),
      );
      expect(result.markdown, contains('roll **`1d20+5`** to hit'));
      expect(result.extractedMath.length, equals(1));
      expect(result.extractedMath.first.diceFormula, equals('8d6'));
      expect(result.extractedMath.first.damageType, equals(DamageType.fire));
    });

    test('extracts spell and item reference pointers', () {
      final entries = [
        'The creature can cast {@spell mage armor|phb} at will.',
        'It carries a {@item potion of healing}.'
      ];
      final result = transformer.transformEntries(entries);

      expect(result.extractedRefs.length, equals(2));

      final spellRef = result.extractedRefs[0];
      expect(spellRef.refType, equals(EntityType.spell));
      expect(spellRef.slug, equals('mage-armor'));
      expect(spellRef.rulesetPreferred, equals(RulesetVersion.v2014));

      final itemRef = result.extractedRefs[1];
      expect(itemRef.refType, equals(EntityType.equipment));
      expect(itemRef.slug, equals('potion-of-healing'));
    });

    test('recursively processes nested lists and tables into markdown', () {
      final entries = [
        {
          'type': 'list',
          'items': [
            'First item with {@dice 1d4}',
            'Second item with {@condition poisoned}'
          ]
        },
        {
          'type': 'table',
          'colLabels': ['d6', 'Effect'],
          'rows': [
            ['1', 'Fire damage {@damage 1d6|fire}'],
            ['2', 'Cold damage {@damage 1d6|cold}']
          ]
        }
      ];

      final result = transformer.transformEntries(entries);

      expect(result.markdown, contains('- First item with **`1d4`**'));
      expect(result.markdown, contains('- Second item with **poisoned**'));
      expect(result.markdown, contains('| d6 | Effect |'));
      expect(result.markdown, contains('| 1 | Fire damage **`1d6 fire`** |'));
      expect(result.markdown, contains('| 2 | Cold damage **`1d6 cold`** |'));
      expect(result.extractedMath.length, equals(2));
    });
  });
}
