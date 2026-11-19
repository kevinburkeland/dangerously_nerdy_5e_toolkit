import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/character_dto.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenPath =
    'test/fixtures/character_map_goldens/app_legacy_character_goldens.json';

/// Recursively sorts all map keys so JSON serialization is deterministic.
dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
    return <String, dynamic>{
      for (final k in sortedKeys) k: _canonicalize(value[k]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

String _canonicalJson(dynamic value) =>
    const JsonEncoder.withIndent('  ').convert(_canonicalize(value));

/// Collects every Character map from the app's read-only legacy fixtures and
/// legacy_storage E1..E9 campaign/roster fixtures.
List<({String id, Map<String, dynamic> map})> _loadLegacyCharacterMaps() {
  final results = <({String id, Map<String, dynamic> map})>[];

  // 1. Standalone legacy character regression fixture
  final singleFile = File('test/fixtures/legacy_character_regression.json');
  expect(singleFile.existsSync(), isTrue);
  final singleMap =
      jsonDecode(singleFile.readAsStringSync()) as Map<String, dynamic>;
  results.add((id: 'legacy_character_regression.json', map: singleMap));

  // 2. Every character roster entry across legacy_storage E1..E9
  final legacyStorageDir = Directory('test/fixtures/legacy_storage');
  final eraDirs = legacyStorageDir
      .listSync()
      .whereType<Directory>()
      .where((d) => RegExp(r'/E\d+$').hasMatch(d.path.replaceAll('\\', '/')))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final eraDir in eraDirs) {
    final eraName = eraDir.path.replaceAll('\\', '/').split('/').last;
    final storageFile = File('${eraDir.path}/storage.json');
    if (!storageFile.existsSync()) continue;

    final storage =
        jsonDecode(storageFile.readAsStringSync()) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>?;
    final charsBox = boxes?['dn_characters_v1'] as Map<String, dynamic>?;
    final rosterRaw = charsBox?['saved_characters_roster_v1'];
    if (rosterRaw == null) continue;

    final dynamic decodedRoster =
        rosterRaw is String ? jsonDecode(rosterRaw) : rosterRaw;
    if (decodedRoster is List) {
      for (var i = 0; i < decodedRoster.length; i++) {
        final entry = decodedRoster[i];
        if (entry is Map) {
          results.add((
            id: 'legacy_storage/$eraName/storage.json#roster[$i]',
            map: Map<String, dynamic>.from(entry),
          ));
        }
      }
    }
  }

  return results;
}

Map<String, dynamic> _buildAppGoldenPayload() {
  final inputs = _loadLegacyCharacterMaps();
  final cases = <Map<String, dynamic>>[];

  for (final item in inputs) {
    final c1 = CharacterDto.fromMap(item.map).toDomain();
    final c2 = CharacterDto.fromMap(item.map).toDomain();
    final serialized = CharacterDto.fromDomain(c1).toMap();
    final roundTrip = CharacterDto.fromMap(serialized).toDomain();
    cases.add({
      'id': item.id,
      'toMap': _canonicalize(serialized),
      'roundTripEqual': roundTrip == c1,
      'separateFromMapEqual': c1 == c2 && c1.hashCode == c2.hashCode,
    });
  }

  return {
    'totalCases': cases.length,
    'cases': cases,
  };
}

void main() {
  group('Step 6 App Legacy Character Map Goldens (Fix 6.1)', () {
    test('Every legacy and campaign fixture Character map matches recorded golden', () {
      final file = File(_goldenPath);
      final actual = _buildAppGoldenPayload();
      expect(actual['totalCases'], greaterThanOrEqualTo(19));

      if (Platform.environment['GENERATE_CHARACTER_GOLDENS'] == '1') {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('${_canonicalJson(actual)}\n');
        return;
      }

      expect(file.existsSync(), isTrue,
          reason: 'Missing golden fixture at $_goldenPath');

      final expected =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(actual['totalCases'], expected['totalCases']);

      final expectedCases = expected['cases'] as List<dynamic>;
      final actualCases = actual['cases'] as List<dynamic>;
      expect(actualCases.length, expectedCases.length);
      for (var i = 0; i < expectedCases.length; i++) {
        expect(
          _canonicalJson(actualCases[i]),
          _canonicalJson(expectedCases[i]),
          reason: 'Mismatch at case ${(expectedCases[i] as Map)['id']}',
        );
      }
    });
  });
}
