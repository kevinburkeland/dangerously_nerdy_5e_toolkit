import 'package:flutter_test/flutter_test.dart';

import '../support/arena_goldens_codec.dart';

void main() {
  group('Fix 4.2: Bundled creature damage-defense table', () {
    test('every bundled stat block x both editions x 13 SRD types + empty + zzz matches fixture',
        () {
      final expected = readJsonListFixture(kDamageDefenseTableFile);
      final actual = buildDamageDefenseTableRows();
      expect(actual.length, equals(expected.length));

      for (var i = 0; i < expected.length; i++) {
        final e = expected[i];
        final a = actual[i];
        final rowKey =
            '${e['monsterId']} (${e['edition']}, type="${e['damageType']}")';
        expect(a['monsterId'], equals(e['monsterId']), reason: rowKey);
        expect(a['edition'], equals(e['edition']), reason: rowKey);
        expect(a['damageType'], equals(e['damageType']), reason: rowKey);
        expect(
          a['colosseum'],
          equals(e['colosseum']),
          reason: 'Defense mismatch for $rowKey (colosseum)',
        );
        if (e['damageType'] == 'fire') {
          expect(
            a['floodedAbyssFire'],
            equals(e['floodedAbyssFire']),
            reason: 'Defense mismatch for $rowKey (floodedAbyssFire)',
          );
          expect(
            a['floodedAbyssChangesFire'],
            equals(e['floodedAbyssChangesFire']),
            reason: 'Defense mismatch for $rowKey (floodedAbyssChangesFire)',
          );
        }
      }
    });
  });
}
