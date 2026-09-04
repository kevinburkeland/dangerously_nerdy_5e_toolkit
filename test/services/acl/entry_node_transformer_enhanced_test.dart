import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/entry_node_transformer.dart';

void main() {
  group('EntryNodeTransformer Enhanced Tags and Cleaning Tests', () {
    late EntryNodeTransformer transformer;

    setUp(() {
      transformer = EntryNodeTransformer();
    });

    test('parses zero-argument tags like {@h}, {@hom}, {@hitYourSpellAttack}, and {@recharge}', () {
      const input = 'Claw. {@atk mw} {@hit 5} to hit. {@h}10 ({@damage 2d6}) slashing damage. {@hom}5 slashing damage.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('*Hit:* 10'));
      expect(result.markdown, contains('*Hit or Miss:* 5'));
      expect(result.markdown, isNot(contains('{@h}')));
      expect(result.markdown, isNot(contains('{@hom}')));
    });

    test('parses {@hitYourSpellAttack} cleanly', () {
      const input = 'Spell Strike. {@atk ms} {@hitYourSpellAttack} to hit.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('**`+your spell attack modifier`** to hit'));
      expect(result.markdown, isNot(contains('{@hitYourSpellAttack}')));
    });

    test('parses {@recharge} with and without arguments', () {
      final res1 = transformer.transformEntries('Breath Weapon {@recharge}');
      expect(res1.markdown, contains('*(Recharge 6)*'));

      final res2 = transformer.transformEntries('Fire Breath {@recharge 5}');
      expect(res2.markdown, contains('*(Recharge 5–6)*'));

      final res3 = transformer.transformEntries('Belch Fire {@recharge 4}');
      expect(res3.markdown, contains('*(Recharge 4–6)*'));
    });

    test('does NOT inject the word "untyped" into damage descriptions', () {
      const input = 'takes {@damage 2d6} necrotic damage on a failed save.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('takes **`2d6`** necrotic damage'));
      expect(result.markdown, isNot(contains('untyped')));
    });

    test('correctly retains damage type in tag when explicitly specified', () {
      const input = 'takes {@damage 4d8|fire} damage.';
      final result = transformer.transformEntries(input);

      expect(result.markdown, contains('**`4d8 fire`**'));
      expect(result.extractedMath.first.damageType, equals(DamageType.fire));
    });

    test('processes tags in table colLabels and captions', () {
      final tableNode = {
        'type': 'table',
        'caption': 'Roll on {@table Wild Magic}',
        'colLabels': ['{@dice d8}', 'Damage Type'],
        'rows': [
          [1, 'Acid'],
          [2, 'Cold'],
        ],
      };

      final result = transformer.transformEntries(tableNode);
      expect(result.markdown, contains('**Roll on **Wild Magic****'));
      expect(result.markdown, contains('| **`d8`** | Damage Type |'));
      expect(result.markdown, isNot(contains('{@dice')));
      expect(result.markdown, isNot(contains('{@table')));
    });
  });
}
