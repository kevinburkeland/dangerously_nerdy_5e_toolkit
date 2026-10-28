import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_settings_codec.dart';
import 'app_backup_settings_test_support.dart';

/// Named exclusion constant for [AppSettings] fields that are intentionally not backed up.
const Map<String, String> kExcludedAppSettingsFields = {
  'bypassedHomebrewSlugs':
      'never exported; adding it would change the backup format',
};

/// Extracts the `final` field names declared in `class AppSettings` from [sourceText].
Set<String> extractAppSettingsFieldNames(String sourceText) {
  final classMatch = RegExp(
    r'class\s+AppSettings\s*\{([\s\S]*?)^\}',
    multiLine: true,
  ).firstMatch(sourceText);
  if (classMatch == null) {
    throw StateError('class AppSettings not found in source');
  }
  final body = classMatch.group(1)!;
  final fieldRegex =
      RegExp(r'^\s*final\s+[\w<>?,\s]+\s+(\w+)\s*;', multiLine: true);
  return fieldRegex.allMatches(body).map((m) => m.group(1)!).toSet();
}

/// Compares [declaredFieldNames] against [codecKeys] plus [kExcludedAppSettingsFields],
/// returning one problem per missing or extra field name.
List<String> checkAppSettingsKeySetParity(
  Set<String> declaredFieldNames,
  Iterable<String> codecKeys,
) {
  final problems = <String>[];
  final codecKeySet = codecKeys.toSet();
  final expectedSet = {...codecKeySet, ...kExcludedAppSettingsFields.keys};

  for (final field in declaredFieldNames) {
    if (!expectedSet.contains(field)) {
      problems.add(
        'AppSettings field "$field" is neither in kAppBackupSettingsKeys nor in kExcludedAppSettingsFields',
      );
    }
  }
  for (final key in expectedSet) {
    if (!declaredFieldNames.contains(key)) {
      problems.add(
        'Codec or exclusion key "$key" is not declared on class AppSettings',
      );
    }
  }
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SR2: Codec round-trip law over seeds 0..199', () {
    for (var seed = 0; seed <= 199; seed++) {
      final s = randomSettings(seed);
      final opp = opposite(s);

      final exported = encodeAppBackupSettings(s);
      final roundTrippedMap =
          jsonDecode(jsonEncode(exported)) as Map<String, dynamic>;
      final decoded = decodeAppBackupSettings(
        roundTrippedMap,
        base: opp,
      );

      final expected = s.copyWith(
        bypassedHomebrewSlugs: opp.bypassedHomebrewSlugs,
      );
      final diff = firstSettingsDiff(expected, decoded.settings);
      expect(
        diff,
        isNull,
        reason: 'seed $seed: first differing field: $diff',
      );
      expect(
        decoded.skipped,
        isEmpty,
        reason: 'seed $seed: unexpected skip reasons: ${decoded.skipped}',
      );
      expect(
        decoded.appliedCount,
        equals(18),
        reason: 'seed $seed: expected 18 applied settings, got ${decoded.appliedCount}',
      );
    }
  });

  test('SR4: Source bar comparing AppSettings fields against kAppBackupSettingsKeys + exclusion constant', () {
    final source = File('lib/models/app_settings.dart').readAsStringSync();
    final declaredFields = extractAppSettingsFieldNames(source);
    final problems =
        checkAppSettingsKeySetParity(declaredFields, kAppBackupSettingsKeys);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('SR4c: Control: checkAppSettingsKeySetParity fails on madeUpField and missing oledPitchBlack', () {
    final source = File('lib/models/app_settings.dart').readAsStringSync();
    final declaredFields = extractAppSettingsFieldNames(source);

    final withMadeUp = {...declaredFields, 'madeUpField'};
    final problemsPlus =
        checkAppSettingsKeySetParity(withMadeUp, kAppBackupSettingsKeys);
    expect(problemsPlus, hasLength(1));
    expect(problemsPlus.single, contains('madeUpField'));

    final withoutOled = {...declaredFields}..remove('oledPitchBlack');
    final problemsMinus =
        checkAppSettingsKeySetParity(withoutOled, kAppBackupSettingsKeys);
    expect(problemsMinus, hasLength(1));
    expect(problemsMinus.single, contains('oledPitchBlack'));
  });
}
