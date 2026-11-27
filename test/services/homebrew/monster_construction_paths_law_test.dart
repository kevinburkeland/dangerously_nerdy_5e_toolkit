import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/field_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_field.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_span.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_monster_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/monster_builder_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/dart_directive_reader.dart';
import '../../support/monster_golden_serializer.dart';

/// Complete inventory of `Monster(` / `Monster.singleEdition(` /
/// `MinionStatBlock(` / `MonsterStatBlock(` construction call sites under
/// `lib/` outside bundled bestiary and summon preset data files.
///
/// Groups:
/// - `'path'`: builds a new monster from user or import input (pinned by path law).
/// - `'converter'`: legacy domain-to-codex converter (deleted in Step 6).
const Map<String, String> kMonsterConstructionSiteInventory = {
  'lib/widgets/homebrew/monster_builder_dialog.dart': 'path',
  'lib/services/acl/compendium_monster_parser.dart': 'path',
  'lib/services/importers/community_compendium_adapters.dart': 'path',
  'lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart':
      'path',
  'lib/models/domain/minion_instance.dart': 'fallback_baseline',
};

final RegExp _kMonsterOrStatBlockCtorRe = RegExp(
  r'(?<![A-Za-z0-9_$.])(?:Monster|MinionStatBlock|MonsterStatBlock)(?:\s*\.\s*singleEdition)?\s*\(',
);

final RegExp _kCtorDeclarationRe = RegExp(
  r'(?:const\s+|factory\s+)?(?:Monster|MinionStatBlock|MonsterStatBlock)(?:\s*\.\s*singleEdition)?\s*\(\s*\{',
);

bool _hasNonDeclarationCtorCall(String strippedSource) {
  for (final match in _kMonsterOrStatBlockCtorRe.allMatches(strippedSource)) {
    final lineStart = strippedSource.lastIndexOf('\n', match.start) + 1;
    final lineEndIdx = strippedSource.indexOf('\n', match.end);
    final lineEnd = lineEndIdx == -1 ? strippedSource.length : lineEndIdx;
    final line = strippedSource.substring(lineStart, lineEnd).trimLeft();
    // Skip constructor declarations inside the declaring class itself
    // (e.g. `const MinionStatBlock({` with no `return`, `=`, `:`, or `,` before it).
    if (_kCtorDeclarationRe.hasMatch(line) &&
        !line.startsWith('return ') &&
        !line.contains('=')) {
      continue;
    }
    return true;
  }
  return false;
}

/// Scans in-memory Dart sources for Monster / StatBlock construction sites
/// outside bundled bestiary and summon data directories and enforces 1-to-1
/// parity with [inventory].
List<String> checkMonsterConstructionInventory({
  required Map<String, String> sourcesByPath,
  required Map<String, String> inventory,
}) {
  final foundPaths = <String>{};
  final errors = <String>[];

  final sortedPaths = sourcesByPath.keys.toList()..sort();
  for (final path in sortedPaths) {
    if (path.startsWith('lib/models/monster_codex/bestiary/') ||
        path.startsWith('lib/models/srd_summons/spells/') ||
        path.startsWith('lib/models/srd_summons/magic_items/')) {
      continue;
    }
    final stripped =
        stripCommentsAndStringsPreservingNewlines(sourcesByPath[path]!);
    if (_hasNonDeclarationCtorCall(stripped)) {
      foundPaths.add(path);
      if (!inventory.containsKey(path)) {
        errors.add(
          'Unlisted Monster/StatBlock construction site in $path '
          '(add it to kMonsterConstructionSiteInventory with its group)',
        );
      }
    }
  }

  for (final path in inventory.keys) {
    if (!foundPaths.contains(path)) {
      errors.add(
        'Stale inventory entry $path no longer constructs Monster/StatBlock',
      );
    }
  }

  return errors;
}

Map<String, dynamic> _syncAndSerializeMonster(Monster m) {
  MonsterCodexLibrary.setHomebrewMonsters([m]);
  final item = MonsterCodexLibrary.getMonsterById(m.id.slug);
  expect(item, isNotNull, reason: 'Monster ${m.id.slug} missing after sync');
  return jsonDecode(jsonEncode({
    'domainMonster': serializeDomainMonster(m),
    'codexView': serializeMonsterForGolden(item!),
  })) as Map<String, dynamic>;
}

IngestionCandidate _buildCandidate(
  String id,
  String rawSource,
  Map<String, dynamic> rawFields,
) {
  final fields = <String, IngestionField<dynamic>>{};
  rawFields.forEach((k, v) {
    fields[k] = IngestionField<dynamic>(
      key: k,
      label: k,
      state: IngestionFieldState.extracted,
      rawText: v.toString(),
      value: v,
    );
  });
  return IngestionCandidate(
    id: id,
    span: const SourceSpan.empty(),
    rawSource: rawSource,
    normalizedSource: rawSource,
    blocks: const [],
    identification: const CandidateIdentification(
      identifiedTypeKey: 'monster',
      confidence: 1.0,
      evidence: [],
    ),
    targetTypeKey: 'monster',
    fields: fields,
  );
}

void _collectDiffs(
  String pathKey,
  String inputId,
  String fieldPath,
  dynamic expected,
  dynamic actual,
  List<String> diffs,
) {
  if (expected is Map && actual is Map) {
    for (final k in expected.keys) {
      final fp = fieldPath.isEmpty ? '$k' : '$fieldPath.$k';
      if (!actual.containsKey(k)) {
        diffs.add(
          '$pathKey | $inputId | $fp: expected=${jsonEncode(expected[k])}, actual=<missing>',
        );
      } else {
        _collectDiffs(pathKey, inputId, fp, expected[k], actual[k], diffs);
      }
    }
    for (final k in actual.keys) {
      if (!expected.containsKey(k)) {
        final fp = fieldPath.isEmpty ? '$k' : '$fieldPath.$k';
        diffs.add(
          '$pathKey | $inputId | $fp: expected=<missing>, actual=${jsonEncode(actual[k])}',
        );
      }
    }
    return;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      diffs.add(
        '$pathKey | $inputId | $fieldPath: expected=${jsonEncode(expected)}, actual=${jsonEncode(actual)}',
      );
      return;
    }
    for (var i = 0; i < expected.length; i++) {
      _collectDiffs(
        pathKey,
        inputId,
        '$fieldPath[$i]',
        expected[i],
        actual[i],
        diffs,
      );
    }
    return;
  }
  if (expected != actual) {
    diffs.add(
      '$pathKey | $inputId | $fieldPath: expected=${jsonEncode(expected)}, actual=${jsonEncode(actual)}',
    );
  }
}

void main() {
  group('Fix 4.2 inventory bar: every Monster/StatBlock construction site in lib/',
      () {
    test('control: unlisted Monster/StatBlock call fails naming file; comment passes',
        () {
      final badSources = {
        'lib/services/unlisted_monster_importer.dart': '''
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
Monster buildOne(EntityId id) {
  return Monster.singleEdition(id: id, name: 'Test');
}
''',
      };
      final badErrors = checkMonsterConstructionInventory(
        sourcesByPath: badSources,
        inventory: const {},
      );
      expect(badErrors, hasLength(1));
      expect(
        badErrors.single,
        contains('lib/services/unlisted_monster_importer.dart'),
      );

      final commentSources = {
        'lib/services/comment_only.dart': '''
// Monster(id: id, name: 'x')
/* MonsterStatBlock(id: 'y') */
const msg = 'MinionStatBlock(';
''',
      };
      final okErrors = checkMonsterConstructionInventory(
        sourcesByPath: commentSources,
        inventory: const {},
      );
      expect(okErrors, isEmpty);
    });

    test('real bar: lib/ matches kMonsterConstructionSiteInventory with no unlisted or stale sites',
        () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final sourcesByPath = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        sourcesByPath[normalized] = entity.readAsStringSync();
      }

      final errors = checkMonsterConstructionInventory(
        sourcesByPath: sourcesByPath,
        inventory: kMonsterConstructionSiteInventory,
      );
      expect(errors, isEmpty, reason: errors.join('\n'));

      final expectedFile = File(
        'test/fixtures/construction_paths/monsters/expected_monster_paths.json',
      );
      expect(
        expectedFile.existsSync(),
        isTrue,
        reason:
            'Missing expected_monster_paths.json. Generate with UPDATE_STEP4_MONSTER_FIXTURES=1.',
      );
      final expected =
          jsonDecode(expectedFile.readAsStringSync()) as Map<String, dynamic>;
      final pathEntries = kMonsterConstructionSiteInventory.entries
          .where((e) => e.value == 'path')
          .map((e) => e.key)
          .toSet();
      expect(expected.keys.toSet(), equals(pathEntries));
    });
  });

  group('Fix 4.2 path law: every monster form and importer matches pinned codex views',
      () {
    testWidgets('all monster construction paths match expected_monster_paths.json field by field',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() {
        MonsterCodexLibrary.clearHomebrewMonsters();
        MonsterCodexLibrary.clearCaches();
      });

      const dir = 'test/fixtures/construction_paths/monsters';
      final formFile = File('$dir/monster_form_inputs.json');
      final importerFile = File('$dir/monster_importers_inputs.json');
      final expectedFile = File('$dir/expected_monster_paths.json');
      expect(formFile.existsSync(), isTrue);
      expect(importerFile.existsSync(), isTrue);
      expect(
        expectedFile.existsSync(),
        isTrue,
        reason:
            'Missing $dir/expected_monster_paths.json. Generate with UPDATE_STEP4_MONSTER_FIXTURES=1.',
      );

      final formInputs =
          jsonDecode(formFile.readAsStringSync()) as Map<String, dynamic>;
      final importerInputs =
          jsonDecode(importerFile.readAsStringSync()) as Map<String, dynamic>;
      final expectedAll =
          jsonDecode(expectedFile.readAsStringSync()) as Map<String, dynamic>;

      final actualAll = <String, Map<String, dynamic>>{};

      // 1. MonsterBuilderDialog
      final formRecords = <String, dynamic>{};
      for (final raw
          in (formInputs['monsters'] as List).cast<Map<String, dynamic>>()) {
        final inputId = raw['inputId'] as String;
        Monster? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<Monster>(
                      context: context,
                      builder: (_) => const MonsterBuilderDialog(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(
            find.byType(TextFormField).at(0), raw['name'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(1), raw['size'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(2), raw['type'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(3), raw['alignment'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(4), raw['cr'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(5), raw['ac'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(6), raw['hp'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(7), raw['hitDice'] as String);
        await tester.enterText(
            find.byType(TextFormField).at(8), raw['actionsMarkdown'] as String);

        await tester.ensureVisible(find.text('Save Monster'));
        await tester.tap(find.text('Save Monster'));
        await tester.pumpAndSettle();

        expect(saved, isNotNull, reason: 'Failed saving form input $inputId');
        formRecords[inputId] = _syncAndSerializeMonster(saved!);
      }
      actualAll['lib/widgets/homebrew/monster_builder_dialog.dart'] =
          formRecords;

      // 2. CompendiumMonsterParser
      final aclParser = CompendiumMonsterParser();
      final aclRecords = <String, dynamic>{};
      for (final entry in (importerInputs['compendiumMonsters'] as List)
          .cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        MonsterCodexLibrary.clearHomebrewMonsters();
        final monster = aclParser.parseMonster(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        aclRecords[id] = _syncAndSerializeMonster(monster);
      }
      actualAll['lib/services/acl/compendium_monster_parser.dart'] = aclRecords;

      // 3. CommunityCompendiumAdapters
      final adapters = CommunityCompendiumAdapters();
      final commRecords = <String, dynamic>{};
      for (final entry in (importerInputs['communityMonsters'] as List)
          .cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final monster = adapters.parseMonster(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        commRecords[id] = _syncAndSerializeMonster(monster);
      }
      actualAll['lib/services/importers/community_compendium_adapters.dart'] =
          commRecords;

      // 4. Dnd5eIngestionCapability
      const cap = Dnd5eIngestionCapability();
      final ingRecords = <String, dynamic>{};
      for (final entry in (importerInputs['ingestionMonsters'] as List)
          .cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final res = cap.convertCandidate(
          _buildCandidate(
            id,
            entry['rawSource'] as String,
            Map<String, dynamic>.from(entry['fields'] as Map),
          ),
        );
        expect(res.isSuccess, isTrue,
            reason: 'Failed ingestion $id: ${res.errors}');
        ingRecords[id] = _syncAndSerializeMonster(res.entity! as Monster);
      }
      actualAll[
              'lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart'] =
          ingRecords;

      final diffs = <String>[];
      for (final pathKey in expectedAll.keys) {
        final expPath = expectedAll[pathKey] as Map<String, dynamic>;
        final actPath = actualAll[pathKey] ?? {};
        for (final inputId in expPath.keys) {
          _collectDiffs(
            pathKey,
            inputId,
            '',
            expPath[inputId],
            actPath[inputId],
            diffs,
          );
        }
      }

      expect(
        diffs,
        isEmpty,
        reason: 'Monster construction path mismatches (${diffs.length}):\n'
            '${diffs.join('\n')}',
      );
    });
  });
}
