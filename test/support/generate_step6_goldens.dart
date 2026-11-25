import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../test_doubles/hive_test_harness.dart';
import 'builder_golden_harness.dart';
import 'level_up_golden_harness.dart';

/// Explicit opt-in generator for Step 6 builder and level-up golden fixtures.
/// Run with:
///   UPDATE_STEP6_GOLDENS=1 flutter test test/support/generate_step6_goldens.dart
void main() {
  final hive = HiveTestHarness();

  setUp(() async {
    await hive.setUpInMemory();
  });

  tearDown(() async {
    await hive.tearDown();
  });

  testWidgets('generate Step 6 builder and level-up goldens', (tester) async {
    if (Platform.environment['UPDATE_STEP6_GOLDENS'] != '1') {
      fail('Set UPDATE_STEP6_GOLDENS=1 to regenerate Step 6 golden fixtures.');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const encoder = JsonEncoder.withIndent('  ');

    // 1. Builder goldens (Fix 6.1)
    final builderSpecs = buildAllBuilderGoldenSpecs();
    final builderRecords = <String, Map<String, dynamic>>{};
    for (final spec in builderSpecs) {
      builderRecords[spec.buildKey] = await runBuilderGoldenSpec(tester, spec);
    }
    final builderFile = File('test/fixtures/builder_goldens/builder_goldens.json');
    builderFile.parent.createSync(recursive: true);
    builderFile.writeAsStringSync('${encoder.convert({
      'buildCount': builderRecords.length,
      'builds': builderRecords,
    })}\n');
    stdout.writeln('Wrote ${builderRecords.length} builder goldens to ${builderFile.path}');
    final paladin2024 = builderRecords['2024_paladin'];
    stdout.writeln('2024 Paladin guidedSteps: ${paladin2024?['guidedSteps']}');
    stdout.writeln('2024 Paladin visibleStepTitles: ${paladin2024?['visibleStepTitles']}');

    // 2. Level-up goldens (Fix 6.2)
    final levelUpSpecs = buildAllLevelUpGoldenSpecs();
    final levelUpRecords = <String, Map<String, dynamic>>{};
    final hpDiffs = <String>[];
    final modDiffs = <String>[];

    for (final spec in levelUpSpecs) {
      final rec = await runLevelUpGoldenSpec(tester, spec);
      levelUpRecords[spec.caseKey] = rec;
      final hpShown = rec['fixedAverageHpGainShown'];
      final hpConfirmed = rec['hpGainAfterConfirm'];
      if (hpShown != hpConfirmed) {
        hpDiffs.add('${spec.caseKey}: shown=$hpShown vs confirmed=$hpConfirmed');
      }
      final modShown = rec['castingModifierShown'];
      final modImplied = rec['castingModifierImpliedByConfirmedDc'];
      if (modShown != modImplied) {
        modDiffs.add('${spec.caseKey}: shown=$modShown vs impliedByDc=$modImplied');
      }
    }

    final levelUpFile = File('test/fixtures/level_up_goldens/level_up_goldens.json');
    levelUpFile.parent.createSync(recursive: true);
    levelUpFile.writeAsStringSync('${encoder.convert({
      'caseCount': levelUpRecords.length,
      'cases': levelUpRecords,
    })}\n');
    stdout.writeln('Wrote ${levelUpRecords.length} level-up goldens to ${levelUpFile.path}');
    stdout.writeln('Preview vs Confirm HP diffs (${hpDiffs.length}):');
    for (final d in hpDiffs) {
      stdout.writeln('  HP_DIFF: $d');
    }
    stdout.writeln('Preview vs Confirm Casting Mod diffs (${modDiffs.length}):');
    for (final d in modDiffs) {
      stdout.writeln('  MOD_DIFF: $d');
    }
  });
}
