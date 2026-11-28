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
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/homebrew/homebrew_library_sync.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/equipment_builder_dialog.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/homebrew/spell_builder_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/catalog_golden_serializer.dart';
import '../../support/seeded_spell_item_input_generator.dart';

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

Future<Map<String, dynamic>> _syncAndSerializeSpell(Spell s) async {
  final sync = HomebrewLibrarySync(
    loadCustomSpells: () async => [s],
    loadCustomMonsters: () async => const [],
    loadCustomItems: () async => const [],
    loadCustomRaces: () async => const [],
    loadCustomSubraces: () async => const [],
    loadCustomFeats: () async => const [],
    loadCustomClasses: () async => const [],
    loadCustomSubclasses: () async => const [],
    loadCustomBackgrounds: () async => const [],
    loadCustomOtherEntries: () async => const [],
    loadCustomFluff: () async => const [],
  );
  await sync.syncToLibraries();
  final synced = SpellbookLibrary.allSpells.firstWhere(
    (e) => e.id.slug == s.id.slug && e.id.ruleset == s.id.ruleset,
  );
  final classList2014 = <String>[];
  final classList2024 = <String>[];
  for (final cls in SpellClass.values) {
    if (SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2014)
        .any((e) => e.id.slug == synced.id.slug)) {
      classList2014.add(cls.name);
    }
    if (SpellbookLibrary.getSpellsByClass(cls, edition: DmRulesEdition.v2024)
        .any((e) => e.id.slug == synced.id.slug)) {
      classList2024.add(cls.name);
    }
  }
  return {
    'kind': 'spell',
    'catalog': jsonDecode(jsonEncode(serializeSpellForCatalogGolden(synced))),
    'classList2014': classList2014,
    'classList2024': classList2024,
  };
}

Map<String, dynamic> _syncAndSerializeItem(EquipmentItem item) {
  MagicItemLibrary.setHomebrewItems([item]);
  final fetched = MagicItemLibrary.findById(item.id.slug)!;
  return {
    'kind': 'item',
    'catalog': jsonDecode(jsonEncode(serializeItemForCatalogGolden(fetched))),
  };
}

void _collectDiffs(
  String pathKey,
  String inputId,
  String inputName,
  String fieldPath,
  dynamic expected,
  dynamic actual,
  List<String> diffs,
) {
  if (expected is Map && actual is Map) {
    for (final k in expected.keys) {
      final fp = fieldPath.isEmpty ? '$k' : '$fieldPath.$k';
      if (!actual.containsKey(k)) {
        diffs.add('$pathKey | seed=20261127 | $inputId ($inputName) | $fp: expected=${jsonEncode(expected[k])}, actual=<missing>');
      } else {
        _collectDiffs(pathKey, inputId, inputName, fp, expected[k], actual[k], diffs);
      }
    }
    return;
  }
  if (expected is List && actual is List) {
    if (jsonEncode(expected) != jsonEncode(actual)) {
      diffs.add(
        '$pathKey | seed=20261127 | $inputId ($inputName) | $fieldPath: expected=${jsonEncode(expected)}, actual=${jsonEncode(actual)}',
      );
    }
    return;
  }
  if (expected != actual) {
    diffs.add(
      '$pathKey | seed=20261127 | $inputId ($inputName) | $fieldPath: expected=${jsonEncode(expected)}, actual=${jsonEncode(actual)}',
    );
  }
}

void main() {
  testWidgets(
      'Fix 4.2 differential law: generated SRD-named and invented inputs match before-merge expectations',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() {
      SpellbookLibrary.setHomebrewSpells(const []);
      MagicItemLibrary.setHomebrewItems(const []);
    });

    final srdSpellNames = SpellbookLibrary.srdSpells.map((s) => s.name).toList();
    final inputs = generateSeededSpellItemInputs(srdSpellNames: srdSpellNames);
    final expectedAll = jsonDecode(
      File('test/fixtures/construction_paths/expected_before_merge_generated.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;

    final actualAll = <String, Map<String, dynamic>>{};
    final namesByKey = <String, Map<String, String>>{};

    // 1. EquipmentBuilderDialog
    final eqRecords = <String, dynamic>{};
    namesByKey['lib/widgets/homebrew/equipment_builder_dialog.dart'] = {};
    for (final raw in inputs.formItems) {
      final inputId = raw['inputId'] as String;
      namesByKey['lib/widgets/homebrew/equipment_builder_dialog.dart']![inputId] = raw['name'] as String;
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
      eqRecords[inputId] = _syncAndSerializeItem(saved!);
    }
    actualAll['lib/widgets/homebrew/equipment_builder_dialog.dart'] = eqRecords;

    // 2. SpellBuilderDialog
    final spellFormRecords = <String, dynamic>{};
    namesByKey['lib/widgets/homebrew/spell_builder_dialog.dart'] = {};
    for (final raw in inputs.formSpells) {
      final inputId = raw['inputId'] as String;
      namesByKey['lib/widgets/homebrew/spell_builder_dialog.dart']![inputId] = raw['name'] as String;
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
        await tester.enterText(find.byType(TextFormField).at(2), raw['materialDescription'] as String);
        await tester.enterText(find.byType(TextFormField).at(3), raw['diceFormula'] as String);
        await tester.enterText(find.byType(TextFormField).at(4), raw['description'] as String);
        await tester.enterText(find.byType(TextFormField).at(5), raw['higherLevels'] as String);
      } else {
        await tester.enterText(find.byType(TextFormField).at(2), raw['diceFormula'] as String);
        await tester.enterText(find.byType(TextFormField).at(3), raw['description'] as String);
        await tester.enterText(find.byType(TextFormField).at(4), raw['higherLevels'] as String);
      }
      final dmgDropdown = find.byType(DropdownButtonFormField<DamageType>);
      await tester.ensureVisible(dmgDropdown);
      await tester.tap(dmgDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text((raw['damageType'] as String).toUpperCase()).last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Spell'));
      await tester.tap(find.text('Save Spell'));
      await tester.pumpAndSettle();
      spellFormRecords[inputId] = await _syncAndSerializeSpell(saved!);
    }
    actualAll['lib/widgets/homebrew/spell_builder_dialog.dart'] = spellFormRecords;

    // 3. CompendiumItemParser
    final itemParser = CompendiumItemParser();
    final aclItems = <String, dynamic>{};
    namesByKey['lib/services/acl/compendium_item_parser.dart'] = {};
    for (final entry in inputs.compendiumItems) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['lib/services/acl/compendium_item_parser.dart']![id] = raw['name'] as String;
      aclItems[id] = _syncAndSerializeItem(itemParser.parseItem(raw));
    }
    actualAll['lib/services/acl/compendium_item_parser.dart'] = aclItems;

    // 4. CompendiumSpellParser
    final spellParser = CompendiumSpellParser();
    final aclSpells = <String, dynamic>{};
    namesByKey['lib/services/acl/compendium_spell_parser.dart'] = {};
    for (final entry in inputs.compendiumSpells) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['lib/services/acl/compendium_spell_parser.dart']![id] = raw['name'] as String;
      aclSpells[id] = await _syncAndSerializeSpell(spellParser.parseSpell(raw));
    }
    actualAll['lib/services/acl/compendium_spell_parser.dart'] = aclSpells;

    // 5. CommunityCompendiumAdapters
    final adapters = CommunityCompendiumAdapters();
    final commRecords = <String, dynamic>{};
    namesByKey['lib/services/importers/community_compendium_adapters.dart'] = {};
    for (final entry in inputs.communityItems) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['lib/services/importers/community_compendium_adapters.dart']![id] = raw['name'] as String;
      commRecords[id] = _syncAndSerializeItem(adapters.parseItem(raw));
    }
    for (final entry in inputs.communitySpells) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['lib/services/importers/community_compendium_adapters.dart']![id] = raw['name'] as String;
      commRecords[id] = await _syncAndSerializeSpell(adapters.parseSpell(raw));
    }
    actualAll['lib/services/importers/community_compendium_adapters.dart'] = commRecords;

    // 6. Dnd5eIngestionCapability
    const cap = Dnd5eIngestionCapability();
    final ingRecords = <String, dynamic>{};
    namesByKey['lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart'] = {};
    for (final entry in inputs.ingestionItems) {
      final id = entry['inputId'] as String;
      final fields = Map<String, dynamic>.from(entry['fields'] as Map);
      namesByKey['lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart']![id] = fields['name'] as String;
      final res = cap.convertCandidate(_buildCandidate(id, 'item', entry['rawSource'] as String, fields));
      ingRecords[id] = _syncAndSerializeItem(res.entity! as EquipmentItem);
    }
    for (final entry in inputs.ingestionSpells) {
      final id = entry['inputId'] as String;
      final fields = Map<String, dynamic>.from(entry['fields'] as Map);
      namesByKey['lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart']![id] = fields['name'] as String;
      final res = cap.convertCandidate(_buildCandidate(id, 'spell', entry['rawSource'] as String, fields));
      ingRecords[id] = await _syncAndSerializeSpell(res.entity! as Spell);
    }
    actualAll['lib/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart'] = ingRecords;

    // 7. SpellDto.toDomain()
    final dtoRecords = <String, dynamic>{};
    namesByKey['lib/infrastructure/dtos/spell_dto.dart'] = {};
    for (final entry in inputs.dtoSpells) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['lib/infrastructure/dtos/spell_dto.dart']![id] = raw['name'] as String;
      dtoRecords[id] = await _syncAndSerializeSpell(SpellDto.fromJson(raw).toDomain());
    }
    actualAll['lib/infrastructure/dtos/spell_dto.dart'] = dtoRecords;

    // 8. Stored old-format homebrew spell records
    final legacyRecords = <String, dynamic>{};
    namesByKey['stored_legacy_spells'] = {};
    for (final entry in inputs.storedLegacySpells) {
      final id = entry['inputId'] as String;
      final raw = Map<String, dynamic>.from(entry['raw'] as Map);
      namesByKey['stored_legacy_spells']![id] = raw['name'] as String;
      legacyRecords[id] = await _syncAndSerializeSpell(SpellDto.fromJson(raw).toDomain());
    }
    actualAll['stored_legacy_spells'] = legacyRecords;

    final diffs = <String>[];
    for (final pathKey in expectedAll.keys) {
      final expPath = expectedAll[pathKey] as Map<String, dynamic>;
      final actPath = actualAll[pathKey] ?? {};
      for (final inputId in expPath.keys) {
        final inputName = namesByKey[pathKey]?[inputId] ?? inputId;
        _collectDiffs(pathKey, inputId, inputName, '', expPath[inputId], actPath[inputId], diffs);
      }
    }

    expect(
      diffs,
      isEmpty,
      reason: 'Differential law mismatches (${diffs.length}):\n${diffs.take(50).join('\n')}',
    );
  });

  test('saving and reloading a form-made Fireball leaves its stored payload byte-identical (classes stay empty on disk)', () async {
    addTearDown(() => SpellbookLibrary.setHomebrewSpells(const []));
    final fireball = Spell.singleEdition(
      id: const EntityId(
        ruleset: RulesetVersion.homebrew,
        slug: 'fireball',
      ),
      name: 'Fireball',
      level: 3,
      school: 'Evocation',
      schoolEnum: SpellSchool.evocation,
      castingTime: const CastingTime(cost: 1, actionType: ActionType.action),
      range: '150 feet',
      components: const SpellComponents(v: true, s: true),
      duration: const SpellDuration(type: DurationType.instantaneous),
      descriptionMarkdown: 'A bright streak flashes.',
    );
    final beforeBytes = jsonEncode(SpellDto.fromDomain(fireball).toJson());
    await HomebrewLibrarySync(
      loadCustomSpells: () async => [fireball],
      loadCustomMonsters: () async => const [],
      loadCustomItems: () async => const [],
      loadCustomRaces: () async => const [],
      loadCustomSubraces: () async => const [],
      loadCustomFeats: () async => const [],
      loadCustomClasses: () async => const [],
      loadCustomSubclasses: () async => const [],
      loadCustomBackgrounds: () async => const [],
      loadCustomOtherEntries: () async => const [],
      loadCustomFluff: () async => const [],
    ).syncToLibraries();
    final afterBytes = jsonEncode(SpellDto.fromDomain(fireball).toJson());
    expect(afterBytes, equals(beforeBytes));
    final decoded = jsonDecode(afterBytes) as Map<String, dynamic>;
    expect((decoded['rules2014'] as Map?)?['classes'] ?? const [], isEmpty);
    expect((decoded['rules2024'] as Map?)?['classes'] ?? const [], isEmpty);
    expect(
      SpellbookLibrary.getSpellsByClass(SpellClass.wizard, edition: DmRulesEdition.v2014)
          .any((e) => e.id.slug == 'fireball'),
      isTrue,
    );
  });
}
