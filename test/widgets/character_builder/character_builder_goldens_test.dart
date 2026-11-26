import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/builder_golden_harness.dart';
import '../../support/step6_normalizer.dart';
import '../../test_doubles/hive_test_harness.dart';

const _fixturePath = 'test/fixtures/builder_goldens/builder_goldens.json';

void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    await hive.setUpInMemory();
  });

  tearDown(() async {
    await hive.tearDown();
  });

  group('Fix 6.1: CharacterBuilderScreen goldens for every SRD class in both editions',
      () {
    testWidgets('matches recorded builder goldens field by field', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final file = File(_fixturePath);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'Missing golden fixture $_fixturePath. Generate explicitly with UPDATE_STEP6_GOLDENS=1.',
      );

      final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final expectedBuilds =
          (decoded['builds'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();

      final specs = buildAllBuilderGoldenSpecs();
      expect(expectedBuilds.length, equals(specs.length));

      for (final spec in specs) {
        final expected = expectedBuilds[spec.buildKey];
        expect(expected, isNotNull,
            reason: 'Missing buildKey ${spec.buildKey} in $_fixturePath');

        final actual = await runBuilderGoldenSpec(tester, spec);
        final diff = firstJsonDiff(expected, actual, spec.buildKey);
        expect(diff, isNull, reason: 'Builder golden mismatch: $diff');

        // Fix 2.1 guard: for every spell-picking build, the number of cantrips
        // and 1st-level spells held by the created Character must equal the
        // counts the spells step showed on screen.
        if (spec.pickSpells) {
          final charMap = actual['character'] as Map<String, dynamic>;
          final heldCantrips = (charMap['cantrips'] as List<dynamic>? ?? const []);
          final heldKnown = (charMap['spellsKnown'] as List<dynamic>? ?? const []);
          final heldPrepared = (charMap['spellsPrepared'] as List<dynamic>? ?? const []);
          final shownCantrips = actual['cantripsOfferedCount'] as int?;
          final shownSpells = actual['spellsOfferedCount'] as int?;

          expect(
            shownCantrips,
            isNotNull,
            reason: '${spec.buildKey}: spells step must report cantrips count',
          );
          expect(
            shownSpells,
            isNotNull,
            reason: '${spec.buildKey}: spells step must report 1st-level spells count',
          );
          final pickedCantrips =
              (actual['pickedCantrips'] as List<dynamic>? ?? const []);
          expect(
            heldCantrips.length,
            equals(pickedCantrips.length),
            reason:
                '${spec.buildKey}: Character cantrips (${heldCantrips.length}) must equal picked cantrips (${pickedCantrips.length})',
          );
          if (pickedCantrips.isNotEmpty || shownCantrips == 0) {
            expect(
              heldCantrips.length,
              equals(shownCantrips),
              reason:
                  '${spec.buildKey}: Character cantrips (${heldCantrips.length}) must equal screen cantrip count ($shownCantrips)',
            );
          }
          expect(
            heldPrepared.length,
            equals(shownSpells),
            reason:
                '${spec.buildKey}: Character spellsPrepared (${heldPrepared.length}) must equal screen spell count ($shownSpells)',
          );
          expect(
            heldKnown.length,
            equals(shownSpells),
            reason:
                '${spec.buildKey}: Character spellsKnown (${heldKnown.length}) must equal screen spell count ($shownSpells)',
          );
        }
      }
    });
  });
}
