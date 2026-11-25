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
      }
    });
  });
}
