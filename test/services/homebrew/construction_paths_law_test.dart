import 'dart:convert';
import 'dart:io';

import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/candidate_identification.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/field_state.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_candidate.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/ingestion_field.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/models/source_span.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/dtos/spell_dto.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_item_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/importers/community_compendium_adapters.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/equipment_builder_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/spell_builder_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/catalog_golden_serializer.dart';
import '../../support/dart_directive_reader.dart';

/// Complete inventory of `Spell(` / `Spell.singleEdition(` / `EquipmentItem(` /
/// `EquipmentItem.singleEdition(` sites under `lib/` outside `lib/models/spells/`
/// and `lib/models/magic_items/items/`.
///
/// Groups:
/// - `'path'`: builds a new record from user or import input (pinned by path law).
/// - `'copy_or_update'`: copies or adapts an existing library record.
/// - `'other'`: hardcoded sample repository entries.
const Map<String, String> kConstructionSiteInventory = {
  'lib/widgets/homebrew/spell_builder_dialog.dart': 'path',
  'lib/widgets/homebrew/equipment_builder_dialog.dart': 'path',
  'lib/services/acl/compendium_item_parser.dart': 'path',
  'lib/services/acl/compendium_spell_parser.dart': 'path',
  'lib/services/importers/community_compendium_adapters.dart': 'path',
  'lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart':
      'path',
  'lib/infrastructure/dtos/spell_dto.dart': 'path',
  'lib/widgets/spellbook/spell_card.dart': 'copy_or_update',
  'lib/widgets/character_sheet/character_sheet_tabs.dart': 'copy_or_update',
  'lib/widgets/character_builder/views/builder_sample_repository.dart': 'other',
};

final RegExp _kSpellOrItemCtorRe = RegExp(
  r'(?<![A-Za-z0-9_$.])(?:Spell|EquipmentItem)(?:\s*\.\s*singleEdition)?\s*\(',
);

/// Scans in-memory Dart sources for `Spell` / `EquipmentItem` construction
/// sites outside `lib/models/spells/` and `lib/models/magic_items/items/`
/// and enforces 1-to-1 parity with [inventory].
List<String> checkConstructionInventory({
  required Map<String, String> sourcesByPath,
  required Map<String, String> inventory,
}) {
  final foundPaths = <String>{};
  final errors = <String>[];

  final sortedPaths = sourcesByPath.keys.toList()..sort();
  for (final path in sortedPaths) {
    if (path.startsWith('lib/models/spells/') ||
        path.startsWith('lib/models/magic_items/items/')) {
      continue;
    }
    final stripped =
        stripCommentsAndStringsPreservingNewlines(sourcesByPath[path]!);
    if (_kSpellOrItemCtorRe.hasMatch(stripped)) {
      foundPaths.add(path);
      if (!inventory.containsKey(path)) {
        errors.add(
          'Unlisted Spell/EquipmentItem construction site in $path '
          '(add it to kConstructionSiteInventory with its group)',
        );
      }
    }
  }

  for (final path in inventory.keys) {
    if (!foundPaths.contains(path)) {
      errors.add(
        'Stale inventory entry $path no longer constructs Spell/EquipmentItem',
      );
    }
  }

  return errors;
}

Map<String, dynamic> _syncAndSerializeSpell(Spell s) {
  SpellbookLibrary.setHomebrewSpells([s]);
  final classList2014 = <String>[];
  final classList2024 = <String>[];
  for (final cls in SpellClass.values) {
    if (SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2014)
        .any((e) => e.id.slug == s.id.slug)) {
      classList2014.add(cls.name);
    }
    if (SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2024)
        .any((e) => e.id.slug == s.id.slug)) {
      classList2024.add(cls.name);
    }
  }
  return {
    'kind': 'spell',
    'catalog': jsonDecode(jsonEncode(serializeSpellForCatalogGolden(s))),
    'classList2014': classList2014,
    'classList2024': classList2024,
  };
}

Map<String, dynamic> _syncAndSerializeItem(EquipmentItem item) {
  MagicItemLibrary.setHomebrewItems([item]);
  final fetched = MagicItemLibrary.findById(item.id.slug);
  expect(fetched, isNotNull, reason: 'Item ${item.id.slug} missing after sync');
  return {
    'kind': 'item',
    'catalog': jsonDecode(jsonEncode(serializeItemForCatalogGolden(fetched!))),
  };
}

IngestionCandidate _buildCandidate(
  String id,
  String targetTypeKey,
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
    identification: CandidateIdentification(
      identifiedTypeKey: targetTypeKey,
      confidence: 1.0,
      evidence: const [],
    ),
    targetTypeKey: targetTypeKey,
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
        diffs.add('$pathKey | $inputId | $fp: expected=${jsonEncode(expected[k])}, actual=<missing>');
      } else {
        _collectDiffs(pathKey, inputId, fp, expected[k], actual[k], diffs);
      }
    }
    for (final k in actual.keys) {
      if (!expected.containsKey(k)) {
        final fp = fieldPath.isEmpty ? '$k' : '$fieldPath.$k';
        diffs.add('$pathKey | $inputId | $fp: expected=<missing>, actual=${jsonEncode(actual[k])}');
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
      _collectDiffs(pathKey, inputId, '$fieldPath[$i]', expected[i], actual[i], diffs);
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
  group('Fix 2.3 inventory bar: every Spell/EquipmentItem construction site in lib/', () {
    test('control: unlisted EquipmentItem.singleEdition fails naming file; comment passes', () {
      final badSources = {
        'lib/services/unlisted_importer.dart': '''
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
EquipmentItem buildOne(EntityId id) {
  return EquipmentItem.singleEdition(
    id: id,
    name: 'Test',
    itemType: 'Weapon',
    rarity: 'Rare',
    requiresAttunement: false,
    descriptionMarkdown: 'Sharp.',
  );
}
''',
      };
      final badErrors = checkConstructionInventory(
        sourcesByPath: badSources,
        inventory: const {},
      );
      expect(badErrors, hasLength(1));
      expect(badErrors.single, contains('lib/services/unlisted_importer.dart'));

      final commentSources = {
        'lib/services/comment_only.dart': '''
// EquipmentItem.singleEdition(id: id, name: 'x')
/* EquipmentItem.singleEdition(id: id, name: 'y') */
const msg = 'EquipmentItem.singleEdition(';
''',
      };
      final okErrors = checkConstructionInventory(
        sourcesByPath: commentSources,
        inventory: const {},
      );
      expect(okErrors, isEmpty);
    });

    test('real bar: lib/ matches kConstructionSiteInventory with no unlisted or stale sites', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final sourcesByPath = <String, String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final normalized = entity.path.replaceAll('\\', '/');
        sourcesByPath[normalized] = entity.readAsStringSync();
      }

      final errors = checkConstructionInventory(
        sourcesByPath: sourcesByPath,
        inventory: kConstructionSiteInventory,
      );
      expect(errors, isEmpty, reason: errors.join('\n'));

      final expected = jsonDecode(
        File('test/fixtures/construction_paths/expected_before_merge.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final pathEntries = kConstructionSiteInventory.entries
          .where((e) => e.value == 'path')
          .map((e) => e.key)
          .toSet();
      expect(expected.keys.toSet(), equals(pathEntries));
    });
  });

  group('Fix 2.3 path law: every form and importer keeps pre-merge catalog view and class lists', () {
    testWidgets('all construction paths match expected_before_merge.json field by field',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      addTearDown(() {
        SpellbookLibrary.setHomebrewSpells(const []);
        MagicItemLibrary.setHomebrewItems(const []);
      });

      final formsJson = jsonDecode(
        File('test/fixtures/construction_paths/homebrew_forms_inputs.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final importersJson = jsonDecode(
        File('test/fixtures/construction_paths/importers_and_dtos_inputs.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      final expectedAll = jsonDecode(
        File('test/fixtures/construction_paths/expected_before_merge.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;

      final actualAll = <String, Map<String, dynamic>>{};

      // 1. EquipmentBuilderDialog
      final eqRecords = <String, dynamic>{};
      for (final raw in (formsJson['items'] as List).cast<Map<String, dynamic>>()) {
        final inputId = raw['inputId'] as String;
        EquipmentItem? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<EquipmentItem>(
                      context: context,
                      builder: (_) => const EquipmentBuilderDialog(),
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

        await tester.enterText(find.byType(TextFormField).at(0), raw['name'] as String);
        await tester.enterText(find.byType(TextFormField).at(1), raw['itemType'] as String);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(raw['rarity'] as String).last);
        await tester.pumpAndSettle();

        if (raw['requiresAttunement'] == true) {
          await tester.tap(find.text('Requires Attunement'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextFormField).at(2), raw['description'] as String);

        await tester.tap(find.text('Save Item'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull, reason: 'Failed saving $inputId');
        eqRecords[inputId] = _syncAndSerializeItem(saved!);
      }
      actualAll['lib/widgets/homebrew/equipment_builder_dialog.dart'] = eqRecords;

      // 2. SpellBuilderDialog
      final spellFormRecords = <String, dynamic>{};
      for (final raw in (formsJson['spells'] as List).cast<Map<String, dynamic>>()) {
        final inputId = raw['inputId'] as String;
        Spell? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    saved = await showDialog<Spell>(
                      context: context,
                      builder: (_) => const SpellBuilderDialog(),
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

        await tester.enterText(find.byType(TextFormField).at(0), raw['name'] as String);

        final level = raw['level'] as int;
        final levelLabel = level == 0 ? 'Cantrip' : 'Level $level';
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(levelLabel).last);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(raw['school'] as String).last);
        await tester.pumpAndSettle();

        final actionLabel = switch (raw['actionType'] as String) {
          'bonusAction' => '1 Bonus Action',
          'reaction' => '1 Reaction',
          'minute' => '1 Minute',
          _ => '1 Action',
        };
        await tester.tap(find.byType(DropdownButtonFormField<ActionType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(actionLabel).last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(1), raw['range'] as String);

        final durLabel = switch (raw['durationType'] as String) {
          'timed' => 'Timed',
          'permanent' => 'Permanent',
          _ => 'Instantaneous',
        };
        await tester.tap(find.byType(DropdownButtonFormField<DurationType>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(durLabel).last);
        await tester.pumpAndSettle();

        if (raw['concentration'] == true) {
          await tester.tap(find.text('Concentration'));
          await tester.pumpAndSettle();
        }
        if (raw['verbal'] == false) {
          await tester.tap(find.text('V (Verbal)'));
          await tester.pumpAndSettle();
        }
        if (raw['somatic'] == false) {
          await tester.tap(find.text('S (Somatic)'));
          await tester.pumpAndSettle();
        }
        if (raw['material'] == true) {
          await tester.tap(find.text('M (Material)'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextFormField).at(2),
            raw['materialDescription'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).at(3),
            raw['diceFormula'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).at(4),
            raw['description'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).at(5),
            raw['higherLevels'] as String,
          );
        } else {
          await tester.enterText(
            find.byType(TextFormField).at(2),
            raw['diceFormula'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).at(3),
            raw['description'] as String,
          );
          await tester.enterText(
            find.byType(TextFormField).at(4),
            raw['higherLevels'] as String,
          );
        }

        final dmgDropdown = find.byType(DropdownButtonFormField<DamageType>);
        await tester.ensureVisible(dmgDropdown);
        await tester.tap(dmgDropdown);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text((raw['damageType'] as String).toUpperCase()).last,
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Save Spell'));
        await tester.tap(find.text('Save Spell'));
        await tester.pumpAndSettle();
        expect(saved, isNotNull, reason: 'Failed saving $inputId');
        spellFormRecords[inputId] = _syncAndSerializeSpell(saved!);
      }
      actualAll['lib/widgets/homebrew/spell_builder_dialog.dart'] = spellFormRecords;

      // 3. CompendiumItemParser
      final itemParser = CompendiumItemParser();
      final aclItemRecords = <String, dynamic>{};
      for (final entry
          in (importersJson['compendiumItems'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final item = itemParser.parseItem(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        aclItemRecords[id] = _syncAndSerializeItem(item);
      }
      actualAll['lib/services/acl/compendium_item_parser.dart'] = aclItemRecords;

      // 4. CompendiumSpellParser
      final spellParser = CompendiumSpellParser();
      final aclSpellRecords = <String, dynamic>{};
      for (final entry
          in (importersJson['compendiumSpells'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final spell = spellParser.parseSpell(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        aclSpellRecords[id] = _syncAndSerializeSpell(spell);
      }
      actualAll['lib/services/acl/compendium_spell_parser.dart'] = aclSpellRecords;

      // 5. CommunityCompendiumAdapters
      final adapters = CommunityCompendiumAdapters();
      final commRecords = <String, dynamic>{};
      for (final entry
          in (importersJson['communityItems'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final item = adapters.parseItem(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        commRecords[id] = _syncAndSerializeItem(item);
      }
      for (final entry
          in (importersJson['communitySpells'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final spell = adapters.parseSpell(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        commRecords[id] = _syncAndSerializeSpell(spell);
      }
      actualAll['lib/services/importers/community_compendium_adapters.dart'] =
          commRecords;

      // 6. Dnd5eIngestionCapability
      const cap = Dnd5eIngestionCapability();
      final ingRecords = <String, dynamic>{};
      for (final entry
          in (importersJson['ingestionItems'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final res = cap.convertCandidate(
          _buildCandidate(
            id,
            'item',
            entry['rawSource'] as String,
            Map<String, dynamic>.from(entry['fields'] as Map),
          ),
        );
        expect(res.isSuccess, isTrue, reason: 'Failed ingestion $id: ${res.errors}');
        ingRecords[id] = _syncAndSerializeItem(res.entity! as EquipmentItem);
      }
      for (final entry
          in (importersJson['ingestionSpells'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final res = cap.convertCandidate(
          _buildCandidate(
            id,
            'spell',
            entry['rawSource'] as String,
            Map<String, dynamic>.from(entry['fields'] as Map),
          ),
        );
        expect(res.isSuccess, isTrue, reason: 'Failed ingestion $id: ${res.errors}');
        ingRecords[id] = _syncAndSerializeSpell(res.entity! as Spell);
      }
      actualAll['lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart'] =
          ingRecords;

      // 7. SpellDto.toDomain()
      final dtoRecords = <String, dynamic>{};
      for (final entry
          in (importersJson['dtoSpells'] as List).cast<Map<String, dynamic>>()) {
        final id = entry['inputId'] as String;
        final dto = SpellDto.fromJson(
          Map<String, dynamic>.from(entry['raw'] as Map),
        );
        dtoRecords[id] = _syncAndSerializeSpell(dto.toDomain());
      }
      actualAll['lib/infrastructure/dtos/spell_dto.dart'] = dtoRecords;

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
        reason: 'Construction path catalog mismatches (${diffs.length}):\n'
            '${diffs.join('\n')}',
      );
    });
  });
}
