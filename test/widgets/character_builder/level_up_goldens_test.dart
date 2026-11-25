import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../support/level_up_golden_harness.dart';
import '../../support/step6_normalizer.dart';

const _fixturePath = 'test/fixtures/level_up_goldens/level_up_goldens.json';

void main() {
  group('Fix 6.2: LevelUpWizardDialog characterization for every SRD class in both editions',
      () {
    testWidgets('matches recorded level-up goldens field by field',
        (tester) async {
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
      final expectedCases =
          (decoded['cases'] as Map<String, dynamic>).cast<String, Map<String, dynamic>>();

      final specs = buildAllLevelUpGoldenSpecs();
      expect(expectedCases.length, equals(specs.length));

      for (final spec in specs) {
        final expected = expectedCases[spec.caseKey];
        expect(expected, isNotNull,
            reason: 'Missing caseKey ${spec.caseKey} in $_fixturePath');

        final actual = await runLevelUpGoldenSpec(tester, spec);
        final diff = firstJsonDiff(expected, actual, spec.caseKey);
        expect(diff, isNull, reason: 'Level-up golden mismatch: $diff');
      }
    });
  });
}
