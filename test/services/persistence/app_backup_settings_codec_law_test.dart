import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_settings_codec.dart';
import 'app_backup_settings_test_support.dart';

Set<String> extractAppSettingsFieldNames(String sourceText) {
  final classMatch = RegExp(
    r'class\s+AppSettings\s*\{([\s\S]*?)^\}',
    multiLine: true,
  ).firstMatch(sourceText);
  if (classMatch == null) {
    throw StateError('class AppSettings not found in source');
  }
  final body = classMatch.group(1)!;
  final fieldRegex = RegExp(r'^\s*final\s+[\w<>?,\s]+\s+(\w+)\s*;', multiLine: true);
  return fieldRegex.allMatches(body).map((m) => m.group(1)!).toSet();
}

List<String> checkAppSettingsKeySetParity(String appSettingsSource) {
  final fieldNames = extractAppSettingsFieldNames(appSettingsSource);
  final problems = <String>[];
  final unbacked = fieldNames.difference(kAppBackupSettingsKeys);
  if (unbacked.length != 1 || !unbacked.contains('bypassedHomebrewSlugs')) {
    final unexpected = unbacked.difference(const {'bypassedHomebrewSlugs'});
    problems.add(
      'AppSettings fields not in kAppBackupSettingsKeys (expected only bypassedHomebrewSlugs): $unbacked (unexpected: $unexpected)',
    );
  }
  final extraKeys = kAppBackupSettingsKeys.difference(fieldNames);
  if (extraKeys.isNotEmpty) {
    problems.add(
      'kAppBackupSettingsKeys contains keys not on AppSettings: $extraKeys',
    );
  }
  return problems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SR2: Every single field in kAppBackupSettingsKeys is wired (18-case loop)', () {
    for (final key in kAppBackupSettingsKeys) {
      test('Field "$key" is wired through decode, writeToPrefs, and hydrateFromPrefs',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final m = encodeAppBackupSettings(const AppSettings());
        final distinctMap =
            encodeAppBackupSettings(kDistinctNonDefaultSettings);
        final singleKeyMap = <String, dynamic>{
          key: distinctMap[key],
        };
        m[key] = distinctMap[key];

        // 1. Decode single changed key onto const AppSettings()
        final decoded = decodeAppBackupSettings(
          singleKeyMap,
          base: const AppSettings(),
        );
        expect(
          decoded.appliedCount,
          equals(1),
          reason: 'Field "$key" was not counted as applied',
        );
        expect(
          decoded.skipped,
          isEmpty,
          reason: 'Field "$key" was unexpectedly skipped: ${decoded.skipped}',
        );
        expect(
          decoded.settings,
          isNot(equals(const AppSettings())),
          reason:
              'Field "$key" is not wired in decodeAppBackupSettings (settings remained const AppSettings())',
        );

        // 2. Also verify full 18-key map with only key modified differs only in key
        final decodedFromFull = decodeAppBackupSettings(
          m,
          base: const AppSettings(),
        );
        expect(decodedFromFull.appliedCount, equals(18));
        expect(decodedFromFull.skipped, isEmpty);
        expect(decodedFromFull.settings, equals(decoded.settings));

        // 3. Persist via writeToPrefs and verify hydrateFromPrefs matches
        await SettingsProvider.writeToPrefs(prefs, decoded.settings);
        final hydrated = SettingsProvider.hydrateFromPrefs(prefs);
        expect(
          hydrated,
          equals(decoded.settings),
          reason:
              'Field "$key" did not round-trip through writeToPrefs/hydrateFromPrefs',
        );
      });
    }
  });

  test('SR4: Key-set parity between AppSettings fields and kAppBackupSettingsKeys', () {
    final source = File('lib/models/app_settings.dart').readAsStringSync();
    final problems = checkAppSettingsKeySetParity(source);
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('SR4c: Control: injecting final bool unbackedField; into AppSettings fails parity check', () {
    final source = File('lib/models/app_settings.dart').readAsStringSync();
    final injected = source.replaceFirst(
      'class AppSettings {',
      'class AppSettings {\n  final bool unbackedField;',
    );
    final problems = checkAppSettingsKeySetParity(injected);
    expect(problems, isNotEmpty);
    expect(problems.join('\n'), contains('unbackedField'));
  });
}
