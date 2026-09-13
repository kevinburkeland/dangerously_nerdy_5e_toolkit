import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/homebrew_other_category.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/monster_codex_data.dart';
import '../../models/magic_items/magic_item_library.dart';
import '../../models/spellbook_data.dart';
import '../../models/tables/rollable_table.dart';
import '../../models/tables/srd_tables_library.dart';
import '../acl/compendium_background_parser.dart';
import '../acl/compendium_class_parser.dart';
import '../acl/compendium_feat_parser.dart';
import '../acl/compendium_generic_entry_parser.dart';
import '../acl/compendium_item_parser.dart';
import '../acl/compendium_monster_parser.dart';
import '../acl/compendium_race_parser.dart';
import '../acl/compendium_spell_parser.dart';
import '../acl/homebrew_merge_resolver.dart';
import '../acl/srd_equivalence_index.dart';
import '../importers/community_compendium_adapters.dart';
import '../ingestion/compendium_json_ingestion_pipeline.dart';
import '../fluff/entity_fluff_service.dart';
import '../logging_service.dart';
import '../repository/layered_priority_repository.dart';
import '../../domain/homebrew/models/homebrew_entity.dart';
import '../../domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import 'app_database_service.dart';

/// Service managing persistent storage and repository hydration for user-created homebrew and campaign overrides.
class HomebrewPersistenceService {
  static const String _keyHomebrewSpells = 'dn_homebrew_spells_v1';
  static const String _keyHomebrewMonsters = 'dn_homebrew_monsters_v1';
  static const String _keyHomebrewItems = 'dn_homebrew_items_v1';
  static const String _keyHomebrewClasses = 'dn_homebrew_classes_v1';
  static const String _keyHomebrewSubclasses = 'dn_homebrew_subclasses_v1';
  static const String _keyHomebrewRaces = 'dn_homebrew_races_v1';
  static const String _keyHomebrewSubraces = 'dn_homebrew_subraces_v1';
  static const String _keyHomebrewFeats = 'dn_homebrew_feats_v1';
  static const String _keyHomebrewBackgrounds = 'dn_homebrew_backgrounds_v1';
  static const String _keyHomebrewOther = 'dn_homebrew_other_v1';
  static const String _keyHomebrewFluff = 'dn_homebrew_fluff_v1';
  static const String _keyCampaignOverrides = 'dn_campaign_overrides_v1';

  // Raw payload keys — store original source JSON for lossless re-parsing
  static const String _keyHomebrewSpellsRaw     = 'dn_homebrew_spells_raw_v1';
  static const String _keyHomebrewMonstersRaw   = 'dn_homebrew_monsters_raw_v1';
  static const String _keyHomebrewItemsRaw      = 'dn_homebrew_items_raw_v1';
  static const String _keyHomebrewClassesRaw    = 'dn_homebrew_classes_raw_v1';
  static const String _keyHomebrewSubclassesRaw = 'dn_homebrew_subclasses_raw_v1';
  static const String _keyHomebrewRacesRaw      = 'dn_homebrew_races_raw_v1';
  static const String _keyHomebrewSubracesRaw   = 'dn_homebrew_subraces_raw_v1';
  static const String _keyHomebrewFeatsRaw      = 'dn_homebrew_feats_raw_v1';
  static const String _keyHomebrewBackgroundsRaw = 'dn_homebrew_backgrounds_raw_v1';
  static const String _keyHomebrewOtherRaw      = 'dn_homebrew_other_raw_v1';
  static const String _keyHomebrewFluffRaw      = 'dn_homebrew_fluff_raw_v1';

  static final HomebrewPersistenceService _instance =
      HomebrewPersistenceService._internal();
  factory HomebrewPersistenceService() => _instance;
  HomebrewPersistenceService._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;

  Future<List<String>> _loadStringList(String key) async {
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrew, key);
        if (dbVal is List) {
          return dbVal.map((e) => e.toString()).toList();
        }
      }
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? <String>[];
      if (list.isNotEmpty && _db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
        await _db.put(AppDatabaseService.boxHomebrew, key, list);
      }
      return list;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load string list for $key');
      return [];
    }
  }

  Future<void> _saveStringList(String key, List<String> list) async {
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrew)) {
        await _db.put(AppDatabaseService.boxHomebrew, key, list);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(key, list);
      } catch (_) {
        // Suppress quota exceeded in SharedPreferences
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to save string list for $key');
    }
  }


  /// Loads all custom spells from persistent storage.
  Future<List<Spell>> loadCustomSpells() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewSpells);
      final items = <Spell>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Spell.fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted spell skipped in loadCustomSpells');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew spells');
      return [];
    }
  }

  /// Saves a custom spell to persistent storage, optionally storing [rawPayload].
  Future<void> saveCustomSpell(Spell spell, {Map<String, dynamic>? rawPayload}) async {
    final spells = await loadCustomSpells();
    final idx = spells.indexWhere(
      (s) => s.id.slug == spell.id.slug && s.id.ruleset == spell.id.ruleset,
    );
    if (idx != -1) {
      spells[idx] = spell;
    } else {
      spells.add(spell);
    }
    await _saveStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewSpellsRaw, spell.id.slug, rawPayload);
    }
  }

  /// Batch saves multiple custom spells to persistent storage.
  Future<void> saveCustomSpellsBatch(
    List<Spell> newSpells, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newSpells.isEmpty) return;
    final spells = await loadCustomSpells();
    final slugIndex = <String, int>{
      for (int i = 0; i < spells.length; i++)
        '${spells[i].id.slug}_${spells[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newSpells.length; i++) {
      final spell = newSpells[i];
      final key = '${spell.id.slug}_${spell.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        spells[idx] = spell;
      } else {
        slugIndex[key] = spells.length;
        spells.add(spell);
      }
    }
    await _saveStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newSpells.length && i < rawPayloads.length; i++) {
        payloadMap[newSpells[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewSpellsRaw, payloadMap);
    }
  }

  /// Deletes a custom spell by slug.
  Future<void> deleteCustomSpell(String slug) async {
    final spells = await loadCustomSpells();
    spells.removeWhere((s) => s.id.slug == slug);
    await _saveStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewSpellsRaw, slug);
  }

  /// Loads all custom monsters from persistent storage.
  Future<List<Monster>> loadCustomMonsters() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewMonsters);
      final items = <Monster>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Monster.fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted monster skipped in loadCustomMonsters');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew monsters');
      return [];
    }
  }

  /// Synchronizes all loaded homebrew entities into global runtime libraries.
  Future<void> syncToLibraries() async {
    final spells = await loadCustomSpells();
    final spellItems = spells.map(spellToSpellItem).toList();
    SpellbookLibrary.setHomebrewSpells(spellItems);

    final monsters = await loadCustomMonsters();
    MonsterCodexLibrary.setHomebrewMonsters(monsters);

    final items = await loadCustomItems();
    final magicItems = items.map(equipmentItemToMagicItem).toList();
    MagicItemLibrary.setHomebrewItems(magicItems);

    final races = await loadCustomRaces();
    SrdSpeciesLibrary.setCustomSpecies(races);

    final customSubraces = <Subrace>[];
    for (final r in races) {
      customSubraces.addAll(r.subraces);
    }
    final standaloneSubs = await loadCustomSubraces();
    for (final s in standaloneSubs) {
      if (!customSubraces.any((sub) => sub.id.slug == s.id.slug)) {
        customSubraces.add(s);
      }
    }
    SrdSpeciesLibrary.setCustomSubraces(customSubraces);

    final feats = await loadCustomFeats();
    final revitalizedFeats = feats.map((f) {
      if (f.customProperties['selectableAbilities'] == null ||
          (f.customProperties['selectableAbilities'] is List &&
              (f.customProperties['selectableAbilities'] as List).isEmpty)) {
        final rawAbility = f.customProperties['ability'] ?? f.customProperties['abilities'];
        if (rawAbility != null) {
          final parsed = FeatAsiExtension.parseFeatAbilityData(rawAbility);
          if (parsed.selectableAbilities.isNotEmpty) {
            final updatedCp = Map<String, dynamic>.from(f.customProperties);
            updatedCp['selectableAbilities'] =
                parsed.selectableAbilities.map((a) => a.name).toList();
            updatedCp['statIncreaseAmount'] = parsed.amount;
            if (parsed.selectableAbilities.length == 1) {
              updatedCp['statIncreaseAbility'] =
                  parsed.selectableAbilities.first.name;
            }
            return f.copyWith(customProperties: updatedCp);
          }
        }
      }
      return f;
    }).toList();
    SrdFeatsLibrary.setCustomFeats(revitalizedFeats);

    final classes = await loadCustomClasses();
    final revitalizedClasses = classes.map((c) {
      if (c.grants.isEmpty) {
        final addSpells = c.customProperties['additionalSpells'] ?? c.customProperties['spells'];
        if (addSpells != null) {
          final grants = FeatureGrant.extractBonusSpells(addSpells, 'class', c.id.slug);
          if (grants.isNotEmpty) return c.copyWith(grants: grants);
        }
      }
      return c;
    }).toList();
    SrdClassesLibrary.setCustomClasses(revitalizedClasses);

    final subclasses = await loadCustomSubclasses();
    final revitalizedSubclasses = subclasses.map((s) {
      if (s.grants.isEmpty) {
        final addSpells = s.customProperties['additionalSpells'] ?? s.customProperties['subclassSpells'];
        if (addSpells != null) {
          final grants = FeatureGrant.extractBonusSpells(addSpells, 'subclass', s.id.slug);
          if (grants.isNotEmpty) return s.copyWith(grants: grants);
        }
      }
      return s;
    }).toList();
    SrdClassesLibrary.setCustomSubclasses(revitalizedSubclasses);

    final backgrounds = await loadCustomBackgrounds();
    SrdBackgroundsLibrary.setCustomBackgrounds(backgrounds);

    final others = await loadCustomOtherEntries();
    _hydrateCustomOtherSubsystems(others);

    final customFluff = await loadCustomFluff();
    if (customFluff.isNotEmpty) {
      EntityFluffService().batchRegisterFluff(customFluff);
    }
  }

  /// Converts a generic [HomebrewCompendiumEntry] to a rollable [RollableTable].
  static RollableTable compendiumEntryToRollableTable(HomebrewCompendiumEntry entry) {
    final raw = entry.customProperties;
    final entries = <TableEntry>[];

    String cleanTableLabel(String text) {
      return CompendiumJsonIngestionPipeline.cleanRawTags(text)
          .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '')
          .replaceAll(RegExp(r'\*\*|`'), '')
          .trim();
    }

    final rawRows = raw['rows'] is List ? (raw['rows'] as List) : null;
    final colLabels = raw['colLabels'] is List ? (raw['colLabels'] as List) : null;

    String? inferredDice;
    if (colLabels != null && colLabels.isNotEmpty) {
      final firstCol = colLabels.first.toString().trim().toLowerCase();
      if (RegExp(r'^\d*d\d+$').hasMatch(firstCol)) {
        inferredDice = firstCol.startsWith('d') ? '1$firstCol' : firstCol;
      }
    }

    if (rawRows != null && rawRows.isNotEmpty) {
      int currentRollIndex = 1;
      for (final r in rawRows) {
        if (r is List && r.isNotEmpty) {
          final rangeCol = r[0];
          int min = currentRollIndex;
          int max = currentRollIndex;
          String label = '';

          if (rangeCol is List && rangeCol.isNotEmpty) {
            min = int.tryParse(rangeCol[0].toString()) ?? currentRollIndex;
            max = rangeCol.length > 1 ? (int.tryParse(rangeCol[1].toString()) ?? min) : min;
            label = r.length > 1 ? r.sublist(1).join(' - ') : rangeCol.join(' - ');
          } else if (rangeCol is int) {
            min = rangeCol;
            max = rangeCol;
            label = r.length > 1 ? r.sublist(1).join(' - ') : '$rangeCol';
          } else if (rangeCol is String) {
            final trimmed = rangeCol.trim();
            final match = RegExp(r'^(\d+)(?:[-–—](\d+))?$').firstMatch(trimmed);
            if (match != null) {
              min = int.tryParse(match.group(1)!) ?? currentRollIndex;
              max = match.group(2) != null ? (int.tryParse(match.group(2)!) ?? min) : min;
              label = r.length > 1 ? r.sublist(1).join(' - ') : trimmed;
            } else {
              label = r.join(' - ');
            }
          } else {
            label = r.join(' - ');
          }

          entries.add(TableEntry(
            minRoll: min,
            maxRoll: max,
            label: cleanTableLabel(label),
          ));
          currentRollIndex = max + 1;
        } else if (r != null) {
          entries.add(TableEntry(
            minRoll: currentRollIndex,
            maxRoll: currentRollIndex,
            label: cleanTableLabel(r.toString()),
          ));
          currentRollIndex++;
        }
      }
    }

    // Fallback: parse markdown table rows from descriptionMarkdown if entries is empty
    if (entries.isEmpty && entry.descriptionMarkdown.isNotEmpty) {
      final lines = entry.descriptionMarkdown.split('\n');
      int rowIdx = 1;
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isEmpty) continue;
        if (cells.any((c) => c.contains('---'))) continue;
        if (rowIdx == 1 && (cells[0].toLowerCase().contains('roll') || cells[0].toLowerCase().startsWith('d'))) {
          if (inferredDice == null && RegExp(r'^\d*d\d+$').hasMatch(cells[0].toLowerCase())) {
            inferredDice = cells[0].toLowerCase().startsWith('d') ? '1${cells[0].toLowerCase()}' : cells[0].toLowerCase();
          }
          continue;
        }

        final firstCell = cells[0];
        final match = RegExp(r'^(\d+)(?:[-–—](\d+))?$').firstMatch(firstCell);
        if (match != null) {
          final min = int.tryParse(match.group(1)!) ?? rowIdx;
          final max = match.group(2) != null ? (int.tryParse(match.group(2)!) ?? min) : min;
          final label = cells.length > 1 ? cells.sublist(1).join(' - ') : firstCell;
          entries.add(TableEntry(minRoll: min, maxRoll: max, label: cleanTableLabel(label)));
          rowIdx = max + 1;
        } else {
          entries.add(TableEntry(minRoll: rowIdx, maxRoll: rowIdx, label: cleanTableLabel(cells.join(' - '))));
          rowIdx++;
        }
      }
    }

    if (entries.isEmpty) {
      entries.add(TableEntry(
        minRoll: 1,
        maxRoll: 1,
        label: cleanTableLabel(entry.name),
        description: entry.descriptionMarkdown.isNotEmpty ? CompendiumJsonIngestionPipeline.cleanRawTags(entry.descriptionMarkdown) : null,
      ));
    }

    int maxRoll = 1;
    for (final e in entries) {
      if (e.maxRoll > maxRoll) maxRoll = e.maxRoll;
    }
    int sides = maxRoll;
    if (inferredDice != null) {
      final m = RegExp(r'd(\d+)').firstMatch(inferredDice);
      if (m != null) sides = int.tryParse(m.group(1)!) ?? maxRoll;
    }
    if (sides < 1) sides = 1;
    final formula = inferredDice ?? '1d$sides';

    return RollableTable(
      id: entry.id.slug,
      name: CompendiumJsonIngestionPipeline.cleanRawTags(entry.name),
      category: TableCategory.custom,
      diceFormula: formula,
      diceSides: sides,
      diceCount: 1,
      description: entry.descriptionMarkdown.isNotEmpty ? CompendiumJsonIngestionPipeline.cleanRawTags(entry.descriptionMarkdown) : 'Homebrew rollable table.',
      entries: entries,
    );
  }

  /// Converts a generic [HomebrewCompendiumEntry] to a [DmReferenceItem].
  static DmReferenceItem compendiumEntryToDmReferenceItem(HomebrewCompendiumEntry entry) {
    final cat = HomebrewOtherCategory.classify(
      category: entry.category,
      name: entry.name,
      customProperties: entry.customProperties,
    );

    DmCategory dmCat;
    String subCategory;

    switch (cat) {
      case HomebrewOtherCategory.trapsAndHazards:
        dmCat = DmCategory.environment;
        subCategory = entry.category.toLowerCase().contains('trap') ? 'Traps' : 'Hazards';
      case HomebrewOtherCategory.conditionsAndDiseases:
        dmCat = DmCategory.conditions;
        subCategory = entry.category.toLowerCase().contains('disease') ? 'Diseases' : 'Conditions';
      case HomebrewOtherCategory.deities:
        dmCat = DmCategory.exploration;
        subCategory = 'Pantheon & Deities';
      case HomebrewOtherCategory.vehicles:
        dmCat = DmCategory.exploration;
        subCategory = 'Vehicles & Travel';
      case HomebrewOtherCategory.charmsAndRewards:
        dmCat = DmCategory.magicAndResting;
        subCategory = 'Charms & Rewards';
      case HomebrewOtherCategory.characterOptions:
      case HomebrewOtherCategory.invocationsAndPacts:
      case HomebrewOtherCategory.infusions:
        dmCat = DmCategory.actions;
        subCategory = entry.category;
      case HomebrewOtherCategory.tables:
        dmCat = DmCategory.tables;
        subCategory = 'Codex Tables';
      case HomebrewOtherCategory.rulesAndReference:
        final catLower = entry.category.toLowerCase();
        if (catLower.contains('action') || catLower.contains('combat')) {
          dmCat = DmCategory.actions;
          subCategory = 'Combat Actions';
        } else {
          dmCat = DmCategory.exploration;
          subCategory = 'Rules & Variants';
        }
    }

    final rawLines = CompendiumJsonIngestionPipeline.cleanRawTags(entry.descriptionMarkdown)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final summary = rawLines.isNotEmpty ? rawLines.first : entry.name;
    final rules = rawLines.isNotEmpty ? rawLines : [entry.name];

    return DmReferenceItem(
      id: entry.id.slug,
      title: CompendiumJsonIngestionPipeline.cleanRawTags(entry.name),
      category: dmCat,
      subCategory: subCategory,
      summary: summary,
      rules2014: rules,
      rules2024: rules,
      tags: ['Homebrew', entry.category, subCategory],
      isChangedIn2024: false,
      extraData: entry.customProperties,
    );
  }

  /// Synchronizes runtime registries for generic compendium items:
  /// - Feature Options (Invocations, Pacts, Infusions, Character Options)
  /// - Rollable Tables (TableIndexScreen / SrdTablesLibrary)
  /// - DM Reference Items (RulesCompendiumScreen / DmScreenLibrary)
  ///
  /// Only entries with [isEnabled] == true are registered into the active runtime toolkit.
  static void _hydrateCustomOtherSubsystems(List<HomebrewCompendiumEntry> others) {
    final activeOthers = others.where((e) => e.isEnabled).toList();

    final customPactBoons = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final name = e.name.toLowerCase();
          return cat.contains('pact boon') || cat.contains('pb') || name.startsWith('pact of the');
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomPactBoons(customPactBoons);

    final customInvocations = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final isPactBoon = cat.contains('pact boon') || cat.contains('pb') || e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          return cat.contains('invocation') ||
              cat == 'ei' ||
              cat.startsWith('ei:') ||
              e.customProperties['featureType']?.toString().toUpperCase() == 'EI';
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomInvocations(customInvocations);

    final customInfusions = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final isPactBoon = cat.contains('pact boon') || cat.contains('pb') || e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          final isInvocation = cat.contains('invocation') ||
              cat.contains('ei') ||
              e.customProperties['featureType']?.toString().toUpperCase().contains('EI') == true;
          if (isInvocation) return false;
          return cat.contains('infusion') ||
              cat.contains('ai') ||
              e.customProperties['featureType']?.toString().toUpperCase().contains('AI') == true ||
              e.customProperties['featureType']?.toString().toUpperCase().contains('INF') == true;
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomInfusions(customInfusions);

    final customCharOptions = activeOthers
        .where((e) {
          final classified = HomebrewOtherCategory.classify(
            category: e.category,
            name: e.name,
            customProperties: e.customProperties,
          );
          return classified == HomebrewOtherCategory.characterOptions;
        })
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
              customProperties: e.customProperties,
            ))
        .toList();
    SrdFeatureOptions.setCustomCharacterOptions(customCharOptions);

    final customTables = activeOthers
        .where((e) =>
            HomebrewOtherCategory.classify(
              category: e.category,
              name: e.name,
              customProperties: e.customProperties,
            ) ==
            HomebrewOtherCategory.tables)
        .map(compendiumEntryToRollableTable)
        .toList();
    SrdTablesLibrary.setCustomTables(customTables);

    final customRefItems = activeOthers
        .where((e) {
          final classified = HomebrewOtherCategory.classify(
            category: e.category,
            name: e.name,
            customProperties: e.customProperties,
          );
          return classified == HomebrewOtherCategory.trapsAndHazards ||
              classified == HomebrewOtherCategory.conditionsAndDiseases ||
              classified == HomebrewOtherCategory.deities ||
              classified == HomebrewOtherCategory.vehicles ||
              classified == HomebrewOtherCategory.charmsAndRewards ||
              classified == HomebrewOtherCategory.rulesAndReference;
        })
        .map(compendiumEntryToDmReferenceItem)
        .toList();
    DmScreenLibrary.setCustomItems(customRefItems);
  }

  /// Converts an [EquipmentItem] domain entity to a [MagicItem] for [MagicItemLibrary].
  static MagicItem equipmentItemToMagicItem(EquipmentItem item) {
    final typeStr = item.itemType.toLowerCase();
    final ItemCategory category;
    if (typeStr.contains('weapon')) {
      category = ItemCategory.weapon;
    } else if (typeStr.contains('armor') || typeStr.contains('shield')) {
      category = ItemCategory.armor;
    } else if (typeStr.contains('potion') || typeStr.contains('elixir') || typeStr.contains('oil')) {
      category = ItemCategory.potion;
    } else if (typeStr.contains('ring')) {
      category = ItemCategory.ring;
    } else if (typeStr.contains('rod')) {
      category = ItemCategory.rod;
    } else if (typeStr.contains('scroll')) {
      category = ItemCategory.scroll;
    } else if (typeStr.contains('staff') || typeStr.contains('stave')) {
      category = ItemCategory.staff;
    } else if (typeStr.contains('wand')) {
      category = ItemCategory.wand;
    } else if (typeStr.contains('gem')) {
      category = ItemCategory.gemstone;
    } else if (typeStr.contains('art')) {
      category = ItemCategory.artObject;
    } else if (typeStr.contains('trinket')) {
      category = ItemCategory.trinket;
    } else if (typeStr.contains('gear') || typeStr.contains('tool') || typeStr.contains('adventuring')) {
      category = ItemCategory.adventuringGear;
    } else {
      category = ItemCategory.wondrousItem;
    }

    final rarityStr = item.rarity.toLowerCase();
    final ItemRarity rarity;
    if (rarityStr.contains('artifact')) {
      rarity = ItemRarity.artifact;
    } else if (rarityStr.contains('legendary')) {
      rarity = ItemRarity.legendary;
    } else if (rarityStr.contains('very rare') || rarityStr.contains('very_rare')) {
      rarity = ItemRarity.veryRare;
    } else if (rarityStr.contains('rare')) {
      rarity = ItemRarity.rare;
    } else if (rarityStr.contains('uncommon')) {
      rarity = ItemRarity.uncommon;
    } else if (rarityStr.contains('common')) {
      rarity = ItemRarity.common;
    } else {
      rarity = ItemRarity.nonmagical;
    }

    final rawJson = item.customProperties['rawJson'] as Map?;
    final costStr = rawJson?['value']?.toString() ?? item.customProperties['cost']?.toString();
    final attunementReq = item.requiresAttunement ? (rawJson?['reqAttune']?.toString() ?? 'Requires Attunement') : null;

    final editionDetails = ItemEditionDetails(
      summary: item.descriptionMarkdown.isNotEmpty
          ? item.descriptionMarkdown.split('\n').first
          : item.name,
      description: item.descriptionMarkdown,
    );

    return MagicItem(
      id: item.id.slug.isNotEmpty ? item.id.slug : item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      name: item.name,
      category: category,
      rarity: rarity,
      cost: costStr,
      requiresAttunement: item.requiresAttunement,
      attunementRequirement: attunementReq,
      rules2014: editionDetails,
      rules2024: editionDetails,
      tags: [item.itemType, item.rarity, if (item.requiresAttunement) 'attunement'],
    );
  }

  /// Converts a [Spell] domain entity to a [SpellItem] for [SpellbookLibrary].
  static SpellItem spellToSpellItem(Spell s) {
    final school = SpellSchool.values.firstWhere(
      (e) => e.name.toLowerCase() == s.school.toLowerCase(),
      orElse: () => SpellSchool.evocation,
    );
    final compList = <String>[];
    if (s.components.v) compList.add('V');
    if (s.components.s) compList.add('S');
    if (s.components.m) {
      final desc = s.components.materialDescription;
      compList.add(desc != null && desc.isNotEmpty ? 'M ($desc)' : 'M');
    }

    final durationText = s.duration.rawText ??
        (s.duration.type == DurationType.instantaneous
            ? 'Instantaneous'
            : (s.duration.type == DurationType.permanent
                ? 'Permanent'
                : (s.duration.type == DurationType.special
                    ? 'Special'
                    : '${s.duration.durationSeconds} seconds')));

    final extractedClasses = <SpellClass>[];
    final rawClasses = s.customProperties['classes'] ??
        (s.customProperties['customProperties'] is Map
            ? (s.customProperties['customProperties'] as Map)['classes']
            : null);
    final candidates = <dynamic>[];
    if (rawClasses is List) {
      candidates.addAll(rawClasses);
    } else if (rawClasses is Map) {
      if (rawClasses['fromClassList'] is List) {
        candidates.addAll(rawClasses['fromClassList'] as List);
      }
      if (rawClasses['fromClassListVariant'] is List) {
        candidates.addAll(rawClasses['fromClassListVariant'] as List);
      }
      if (rawClasses['fromSubclass'] is List) {
        for (final sub in (rawClasses['fromSubclass'] as List)) {
          if (sub is Map && sub['class'] != null) {
            candidates.add(sub['class']);
          }
        }
      }
    }

    for (final c in candidates) {
      if (c is SpellClass) {
        if (!extractedClasses.contains(c)) extractedClasses.add(c);
        continue;
      }
      final name = (c is Map && c['name'] != null ? c['name'] : c)
          .toString()
          .replaceFirst('SpellClass.', '')
          .toLowerCase()
          .trim();
      final match = SpellClass.values.where((sc) => sc.name.toLowerCase() == name || sc.label.toLowerCase() == name).firstOrNull;
      if (match != null && !extractedClasses.contains(match)) {
        extractedClasses.add(match);
      }
    }

    // Fallback: If classes list is empty, consult SRD and known expansion spell indexes
    if (extractedClasses.isEmpty) {
      final fallbackNames = CompendiumSpellParser().extractClassesForSpell(s.id.slug, s.name, s.id.ruleset);
      for (final fn in fallbackNames) {
        final match = SpellClass.values.where((sc) => sc.name.toLowerCase() == fn.toLowerCase() || sc.label.toLowerCase() == fn.toLowerCase()).firstOrNull;
        if (match != null && !extractedClasses.contains(match)) {
          extractedClasses.add(match);
        }
      }
    }

    // Determine ritual status
    final isRitual = s.customProperties['meta']?['ritual'] == true ||
        s.customProperties['ritual'] == true;

    // Determine saving throw
    String? savingThrow;
    final rawSt = s.customProperties['savingThrow'];
    if (rawSt is List && rawSt.isNotEmpty) {
      savingThrow = rawSt.map((e) => e.toString().trim()).join(', ');
    } else if (rawSt is String && rawSt.isNotEmpty) {
      savingThrow = rawSt.trim();
    }

    // Extract tags
    final tags = <String>[];
    if (s.customProperties['areaTags'] is List) {
      for (final t in (s.customProperties['areaTags'] as List)) {
        tags.add(t.toString());
      }
    }
    if (s.customProperties['miscTags'] is List) {
      for (final t in (s.customProperties['miscTags'] as List)) {
        tags.add(t.toString());
      }
    }
    if (s.customProperties['source'] != null) {
      tags.add(s.customProperties['source'].toString());
    }
    if (s.customProperties['otherSources'] is List) {
      for (final item in (s.customProperties['otherSources'] as List)) {
        if (item is Map && item['source'] != null) {
          tags.add(item['source'].toString());
        } else if (item != null) {
          tags.add(item.toString());
        }
      }
    }
    if (s.customProperties['referenceSources'] is List) {
      for (final item in (s.customProperties['referenceSources'] as List)) {
        tags.add(item.toString());
      }
    }
    final lowerTags = tags.map((t) => t.toLowerCase()).toSet();
    if (lowerTags.contains('dft') || lowerTags.contains('sgt') || lowerTags.contains('sct')) {
      if (!lowerTags.contains('dunamancy')) tags.add('dunamancy');
      if (!lowerTags.contains('egw')) tags.add('egw');
    }

    final editionDetails = SpellEditionDetails(
      castingTime: s.castingTime.cost > 0
          ? '${s.castingTime.cost} ${s.castingTime.actionType.name}'
          : '1 Action',
      range: s.range.isNotEmpty ? s.range : 'Self',
      components: compList.join(', '),
      duration: durationText,
      concentration: s.duration.requiresConcentration,
      ritual: isRitual,
      savingThrow: savingThrow,
      description: [s.descriptionMarkdown],
      higherLevels: s.higherLevelsMarkdown,
      classes: extractedClasses,
      rollFormula: s.damageMath.isNotEmpty ? s.damageMath.first.diceFormula : null,
      damageOrHealType: s.damageMath.isNotEmpty ? s.damageMath.first.damageType.name : null,
    );

    return SpellItem(
      id: s.id.slug,
      name: s.name,
      level: s.level,
      school: school,
      rules2014: editionDetails,
      rules2024: editionDetails,
      tags: tags,
    );
  }

  /// Saves a custom monster to persistent storage and updates MonsterCodexLibrary.
  Future<void> saveCustomMonster(Monster monster, {Map<String, dynamic>? rawPayload}) async {
    final monsters = await loadCustomMonsters();
    final idx = monsters.indexWhere(
      (m) => m.id.slug == monster.id.slug && m.id.ruleset == monster.id.ruleset,
    );
    if (idx != -1) {
      monsters[idx] = monster;
    } else {
      monsters.add(monster);
    }
    await _saveStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewMonstersRaw, monster.id.slug, rawPayload);
    }
    MonsterCodexLibrary.addHomebrewMonster(monster);
  }

  /// Batch saves multiple custom monsters to persistent storage and updates MonsterCodexLibrary.
  Future<void> saveCustomMonstersBatch(
    List<Monster> newMonsters, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newMonsters.isEmpty) return;
    final monsters = await loadCustomMonsters();
    final slugIndex = <String, int>{
      for (int i = 0; i < monsters.length; i++)
        '${monsters[i].id.slug}_${monsters[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newMonsters.length; i++) {
      final monster = newMonsters[i];
      final key = '${monster.id.slug}_${monster.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        monsters[idx] = monster;
      } else {
        slugIndex[key] = monsters.length;
        monsters.add(monster);
      }
      MonsterCodexLibrary.addHomebrewMonster(monster);
    }
    await _saveStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newMonsters.length && i < rawPayloads.length; i++) {
        payloadMap[newMonsters[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewMonstersRaw, payloadMap);
    }
  }

  /// Deletes a custom monster by slug and updates MonsterCodexLibrary.
  Future<void> deleteCustomMonster(String slug) async {
    final monsters = await loadCustomMonsters();
    monsters.removeWhere((m) => m.id.slug == slug);
    await _saveStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewMonstersRaw, slug);
    MonsterCodexLibrary.removeHomebrewMonster(slug);
  }

  /// Loads all custom items from persistent storage.
  Future<List<EquipmentItem>> loadCustomItems() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewItems);
      final items = <EquipmentItem>[];
      for (final jsonStr in rawList) {
        try {
          items.add(EquipmentItem.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted item skipped in loadCustomItems');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew items');
      return [];
    }
  }

  /// Saves a custom item to persistent storage.
  Future<void> saveCustomItem(EquipmentItem item, {Map<String, dynamic>? rawPayload}) async {
    final items = await loadCustomItems();
    final idx = items.indexWhere(
      (i) => i.id.slug == item.id.slug && i.id.ruleset == item.id.ruleset,
    );
    if (idx != -1) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    await _saveStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewItemsRaw, item.id.slug, rawPayload);
    }
  }

  /// Batch saves multiple custom items to persistent storage.
  Future<void> saveCustomItemsBatch(
    List<EquipmentItem> newItems, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newItems.isEmpty) return;
    final items = await loadCustomItems();
    final slugIndex = <String, int>{
      for (int i = 0; i < items.length; i++)
        '${items[i].id.slug}_${items[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      final key = '${item.id.slug}_${item.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        items[idx] = item;
      } else {
        slugIndex[key] = items.length;
        items.add(item);
      }
    }
    await _saveStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newItems.length && i < rawPayloads.length; i++) {
        payloadMap[newItems[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewItemsRaw, payloadMap);
    }
  }

  /// Deletes a custom item by slug.
  Future<void> deleteCustomItem(String slug) async {
    final items = await loadCustomItems();
    items.removeWhere((i) => i.id.slug == slug);
    await _saveStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewItemsRaw, slug);
  }

  /// Loads all custom classes from persistent storage.
  Future<List<CharacterClass>> loadCustomClasses() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewClasses);
      final classes = <CharacterClass>[];
      for (final jsonStr in rawList) {
        try {
          classes.add(CharacterClass.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted class skipped in loadCustomClasses');
        }
      }
      return classes;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew classes');
      return [];
    }
  }

  /// Saves a custom class to persistent storage and runtime library.
  Future<void> saveCustomClass(CharacterClass characterClass, {Map<String, dynamic>? rawPayload}) async {
    final classes = await loadCustomClasses();
    final idx = classes.indexWhere(
      (c) => c.id.slug == characterClass.id.slug && c.id.ruleset == characterClass.id.ruleset,
    );
    if (idx != -1) {
      classes[idx] = characterClass;
    } else {
      classes.add(characterClass);
    }
    await _saveStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewClassesRaw, characterClass.id.slug, rawPayload);
    }
    SrdClassesLibrary.addCustomClass(characterClass);
  }

  /// Batch saves multiple custom classes to persistent storage and runtime library.
  Future<void> saveCustomClassesBatch(
    List<CharacterClass> newClasses, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newClasses.isEmpty) return;
    final classes = await loadCustomClasses();
    final slugIndex = <String, int>{
      for (int i = 0; i < classes.length; i++)
        '${classes[i].id.slug}_${classes[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newClasses.length; i++) {
      final c = newClasses[i];
      final key = '${c.id.slug}_${c.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        classes[idx] = c;
      } else {
        slugIndex[key] = classes.length;
        classes.add(c);
      }
      SrdClassesLibrary.addCustomClass(c);
    }
    await _saveStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newClasses.length && i < rawPayloads.length; i++) {
        payloadMap[newClasses[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewClassesRaw, payloadMap);
    }
  }

  /// Deletes a custom class by slug and runtime library.
  Future<void> deleteCustomClass(String slug) async {
    final classes = await loadCustomClasses();
    classes.removeWhere((c) => c.id.slug == slug);
    await _saveStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewClassesRaw, slug);
    SrdClassesLibrary.removeCustomClass(slug);
  }

  /// Loads all custom subclasses from persistent storage.
  Future<List<Subclass>> loadCustomSubclasses() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewSubclasses);
      final items = <Subclass>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Subclass.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted subclass skipped in loadCustomSubclasses');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew subclasses');
      return [];
    }
  }

  /// Saves a custom subclass to persistent storage.
  Future<void> saveCustomSubclass(Subclass subclass, {Map<String, dynamic>? rawPayload}) async {
    final subs = await loadCustomSubclasses();
    final idx = subs.indexWhere(
      (s) => s.id.slug == subclass.id.slug && s.id.ruleset == subclass.id.ruleset,
    );
    if (idx != -1) {
      subs[idx] = subclass;
    } else {
      subs.add(subclass);
    }
    await _saveStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewSubclassesRaw, subclass.id.slug, rawPayload);
    }
    SrdClassesLibrary.addCustomSubclass(subclass);
  }

  /// Batch saves multiple custom subclasses to persistent storage.
  Future<void> saveCustomSubclassesBatch(
    List<Subclass> newSubclasses, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newSubclasses.isEmpty) return;
    final subs = await loadCustomSubclasses();
    final slugIndex = <String, int>{
      for (int i = 0; i < subs.length; i++)
        '${subs[i].id.slug}_${subs[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newSubclasses.length; i++) {
      final s = newSubclasses[i];
      final key = '${s.id.slug}_${s.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        subs[idx] = s;
      } else {
        slugIndex[key] = subs.length;
        subs.add(s);
      }
    }
    await _saveStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newSubclasses.length && i < rawPayloads.length; i++) {
        payloadMap[newSubclasses[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewSubclassesRaw, payloadMap);
    }
    for (final s in newSubclasses) {
      SrdClassesLibrary.addCustomSubclass(s);
    }
  }

  /// Deletes a custom subclass by slug and runtime library.
  Future<void> deleteCustomSubclass(String slug) async {
    final subs = await loadCustomSubclasses();
    final toRemove = subs
        .where((s) =>
            s.id.slug == slug ||
            s.id.slug.endsWith('-$slug') ||
            (s.classSlug.isNotEmpty && s.id.slug == '${s.classSlug}-$slug'))
        .toList();
    for (final s in toRemove) {
      subs.remove(s);
      await _deleteRawPayload(_keyHomebrewSubclassesRaw, s.id.slug);
      SrdClassesLibrary.removeCustomSubclass(s.id.slug);
    }
    await _saveStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewSubclassesRaw, slug);
    SrdClassesLibrary.removeCustomSubclass(slug);
  }

  /// Loads all custom races from persistent storage.
  Future<List<Race>> loadCustomRaces() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewRaces);
      final items = <Race>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Race.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted race skipped in loadCustomRaces');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew races');
      return [];
    }
  }

  /// Saves a custom race to persistent storage and runtime library.
  Future<void> saveCustomRace(Race race, {Map<String, dynamic>? rawPayload}) async {
    final races = await loadCustomRaces();
    final idx = races.indexWhere(
      (r) => r.id.slug == race.id.slug && r.id.ruleset == race.id.ruleset,
    );
    if (idx != -1) {
      races[idx] = race;
    } else {
      races.add(race);
    }
    await _saveStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewRacesRaw, race.id.slug, rawPayload);
    }
    SrdSpeciesLibrary.addCustomSpecies(race);
  }

  /// Batch saves multiple custom races to persistent storage and runtime library.
  Future<void> saveCustomRacesBatch(
    List<Race> newRaces, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newRaces.isEmpty) return;
    final races = await loadCustomRaces();
    final slugIndex = <String, int>{
      for (int i = 0; i < races.length; i++)
        '${races[i].id.slug}_${races[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newRaces.length; i++) {
      final r = newRaces[i];
      final key = '${r.id.slug}_${r.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        final existing = races[idx];
        final subMap = <String, Subrace>{
          for (final s in existing.subraces) s.id.slug: s,
          for (final s in r.subraces) s.id.slug: s,
        };
        races[idx] = r.copyWith(
          traitsMarkdown: r.traitsMarkdown.isNotEmpty ? r.traitsMarkdown : existing.traitsMarkdown,
          subraces: subMap.values.toList(),
        );
      } else {
        slugIndex[key] = races.length;
        races.add(r);
      }
      SrdSpeciesLibrary.addCustomSpecies(r);
    }
    await _saveStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newRaces.length && i < rawPayloads.length; i++) {
        payloadMap[newRaces[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewRacesRaw, payloadMap);
    }
  }

  /// Deletes a custom race by slug and runtime library.
  Future<void> deleteCustomRace(String slug) async {
    final races = await loadCustomRaces();
    races.removeWhere((r) => r.id.slug == slug);
    await _saveStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewRacesRaw, slug);
    SrdSpeciesLibrary.removeCustomSpecies(slug);
  }

  /// Loads all custom standalone subraces from persistent storage.
  Future<List<Subrace>> loadCustomSubraces() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewSubraces);
      final items = <Subrace>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Subrace.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted subrace skipped in loadCustomSubraces');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew subraces');
      return [];
    }
  }

  /// Saves a custom subrace to persistent storage and runtime library.
  Future<void> saveCustomSubrace(Subrace subrace, {Map<String, dynamic>? rawPayload}) async {
    final subs = await loadCustomSubraces();
    final idx = subs.indexWhere(
      (s) => s.id.slug == subrace.id.slug && s.id.ruleset == subrace.id.ruleset,
    );
    if (idx != -1) {
      subs[idx] = subrace;
    } else {
      subs.add(subrace);
    }
    await _saveStringList(
      _keyHomebrewSubraces,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewSubracesRaw, subrace.id.slug, rawPayload);
    }
    SrdSpeciesLibrary.addCustomSubrace(subrace);
  }

  /// Batch saves multiple custom subraces to persistent storage and runtime library.
  Future<void> saveCustomSubracesBatch(
    List<Subrace> newSubraces, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newSubraces.isEmpty) return;
    final subs = await loadCustomSubraces();
    final slugIndex = <String, int>{
      for (int i = 0; i < subs.length; i++)
        '${subs[i].id.slug}_${subs[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newSubraces.length; i++) {
      final s = newSubraces[i];
      final key = '${s.id.slug}_${s.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        subs[idx] = s;
      } else {
        slugIndex[key] = subs.length;
        subs.add(s);
      }
      SrdSpeciesLibrary.addCustomSubrace(s);
    }
    await _saveStringList(
      _keyHomebrewSubraces,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newSubraces.length && i < rawPayloads.length; i++) {
        payloadMap[newSubraces[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewSubracesRaw, payloadMap);
    }
  }

  /// Deletes a custom subrace by slug and runtime library.
  Future<void> deleteCustomSubrace(String slug) async {
    final subs = await loadCustomSubraces();
    subs.removeWhere((s) => s.id.slug == slug);
    await _saveStringList(
      _keyHomebrewSubraces,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewSubracesRaw, slug);
    SrdSpeciesLibrary.removeCustomSubrace(slug);
  }

  /// Loads all custom feats from persistent storage.
  Future<List<Feat>> loadCustomFeats() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewFeats);
      final items = <Feat>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Feat.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted feat skipped in loadCustomFeats');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew feats');
      return [];
    }
  }

  /// Saves a custom feat to persistent storage and runtime library.
  Future<void> saveCustomFeat(Feat feat, {Map<String, dynamic>? rawPayload}) async {
    final feats = await loadCustomFeats();
    final idx = feats.indexWhere(
      (f) => f.id.slug == feat.id.slug && f.id.ruleset == feat.id.ruleset,
    );
    if (idx != -1) {
      feats[idx] = feat;
    } else {
      feats.add(feat);
    }
    await _saveStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewFeatsRaw, feat.id.slug, rawPayload);
    }
    SrdFeatsLibrary.addCustomFeat(feat);
  }

  /// Batch saves multiple custom feats to persistent storage and runtime library.
  Future<void> saveCustomFeatsBatch(
    List<Feat> newFeats, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newFeats.isEmpty) return;
    final feats = await loadCustomFeats();
    final slugIndex = <String, int>{
      for (int i = 0; i < feats.length; i++)
        '${feats[i].id.slug}_${feats[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newFeats.length; i++) {
      final f = newFeats[i];
      final key = '${f.id.slug}_${f.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        feats[idx] = f;
      } else {
        slugIndex[key] = feats.length;
        feats.add(f);
      }
      SrdFeatsLibrary.addCustomFeat(f);
    }
    await _saveStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newFeats.length && i < rawPayloads.length; i++) {
        payloadMap[newFeats[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewFeatsRaw, payloadMap);
    }
  }

  /// Deletes a custom feat by slug and runtime library.
  Future<void> deleteCustomFeat(String slug) async {
    final feats = await loadCustomFeats();
    feats.removeWhere((f) => f.id.slug == slug);
    await _saveStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewFeatsRaw, slug);
    SrdFeatsLibrary.removeCustomFeat(slug);
  }

  /// Loads all custom backgrounds from persistent storage.
  Future<List<Background>> loadCustomBackgrounds() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewBackgrounds);
      final items = <Background>[];
      for (final jsonStr in rawList) {
        try {
          items.add(Background.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted background skipped in loadCustomBackgrounds');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew backgrounds');
      return [];
    }
  }

  /// Saves a custom background to persistent storage and runtime library.
  Future<void> saveCustomBackground(Background background, {Map<String, dynamic>? rawPayload}) async {
    final backgrounds = await loadCustomBackgrounds();
    final idx = backgrounds.indexWhere(
      (b) => b.id.slug == background.id.slug && b.id.ruleset == background.id.ruleset,
    );
    if (idx != -1) {
      backgrounds[idx] = background;
    } else {
      backgrounds.add(background);
    }
    await _saveStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewBackgroundsRaw, background.id.slug, rawPayload);
    }
    SrdBackgroundsLibrary.addCustomBackground(background);
  }

  /// Batch saves multiple custom backgrounds to persistent storage and runtime library.
  Future<void> saveCustomBackgroundsBatch(
    List<Background> newBackgrounds, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newBackgrounds.isEmpty) return;
    final backgrounds = await loadCustomBackgrounds();
    final slugIndex = <String, int>{
      for (int i = 0; i < backgrounds.length; i++)
        '${backgrounds[i].id.slug}_${backgrounds[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < newBackgrounds.length; i++) {
      final b = newBackgrounds[i];
      final key = '${b.id.slug}_${b.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        backgrounds[idx] = b;
      } else {
        slugIndex[key] = backgrounds.length;
        backgrounds.add(b);
      }
      SrdBackgroundsLibrary.addCustomBackground(b);
    }
    await _saveStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newBackgrounds.length && i < rawPayloads.length; i++) {
        payloadMap[newBackgrounds[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewBackgroundsRaw, payloadMap);
    }
  }

  /// Deletes a custom background by slug and runtime library.
  Future<void> deleteCustomBackground(String slug) async {
    final backgrounds = await loadCustomBackgrounds();
    backgrounds.removeWhere((b) => b.id.slug == slug);
    await _saveStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewBackgroundsRaw, slug);
    SrdBackgroundsLibrary.removeCustomBackground(slug);
  }

  /// Loads all custom generic entries (tables, rules, etc.) from persistent storage.
  Future<List<HomebrewCompendiumEntry>> loadCustomOtherEntries() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewOther);
      final items = <HomebrewCompendiumEntry>[];
      for (final jsonStr in rawList) {
        try {
          final entry = HomebrewCompendiumEntry.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map));
          if (!entry.name.startsWith('[{') && entry.name.length <= 500 && entry.id.slug.length <= 200) {
            items.add(entry);
          }
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted other entry skipped in loadCustomOtherEntries');
        }
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew custom entries');
      return [];
    }
  }

  /// Saves a generic compendium entry to persistent storage.
  Future<void> saveCustomOtherEntry(HomebrewCompendiumEntry entry, {Map<String, dynamic>? rawPayload}) async {
    if (entry.name.startsWith('[{') || entry.name.length > 500 || entry.id.slug.length > 200) return;
    final entries = await loadCustomOtherEntries();
    final idx = entries.indexWhere((e) => e.id.slug == entry.id.slug);
    if (idx != -1) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    await _saveStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewOtherRaw, entry.id.slug, rawPayload);
    }
    _hydrateCustomOtherSubsystems(entries);
  }

  /// Batch saves multiple generic compendium entries to persistent storage.
  Future<void> saveCustomOtherEntriesBatch(
    List<HomebrewCompendiumEntry> newEntries, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    final validNew = newEntries.where((e) => !e.name.startsWith('[{') && e.name.length <= 500 && e.id.slug.length <= 200).toList();
    if (validNew.isEmpty) return;
    final entries = await loadCustomOtherEntries();
    final slugIndex = <String, int>{
      for (int i = 0; i < entries.length; i++)
        '${entries[i].id.slug}_${entries[i].id.ruleset.name}': i,
    };
    for (int i = 0; i < validNew.length; i++) {
      final entry = validNew[i];
      final key = '${entry.id.slug}_${entry.id.ruleset.name}';
      final idx = slugIndex[key];
      if (idx != null) {
        entries[idx] = entry;
      } else {
        slugIndex[key] = entries.length;
        entries.add(entry);
      }
    }
    await _saveStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newEntries.length && i < rawPayloads.length; i++) {
        payloadMap[newEntries[i].id.slug] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewOtherRaw, payloadMap);
    }
    _hydrateCustomOtherSubsystems(entries);
  }

  /// Deletes a generic compendium entry by slug.
  Future<void> deleteCustomOtherEntry(String slug) async {
    final entries = await loadCustomOtherEntries();
    entries.removeWhere((e) => e.id.slug == slug);
    await _saveStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewOtherRaw, slug);
    _hydrateCustomOtherSubsystems(entries);
  }

  /// Toggles or sets the [isEnabled] active flag on an individual homebrew compendium entry (rule, table, etc.).
  ///
  /// Persists the updated collection and re-synchronizes runtime libraries so disabled rules are excluded.
  /// Returns the updated [isEnabled] state (or false if slug was not found).
  Future<bool> toggleOtherEntryEnabled(String slug, {bool? isEnabled}) async {
    final entries = await loadCustomOtherEntries();
    final idx = entries.indexWhere((e) => e.id.slug == slug);
    if (idx == -1) return false;

    final target = entries[idx];
    final newEnabled = isEnabled ?? !target.isEnabled;
    entries[idx] = target.copyWith(isEnabled: newEnabled);

    await _saveStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );

    _hydrateCustomOtherSubsystems(entries);
    return newEnabled;
  }

  /// Returns a map of counts for each granular [HomebrewOtherCategory] stored
  /// in the generic compendium collection.
  Future<Map<HomebrewOtherCategory, int>> loadOtherCategoryCounts() async {
    final entries = await loadCustomOtherEntries();
    final counts = <HomebrewOtherCategory, int>{
      for (final cat in HomebrewOtherCategory.values) cat: 0,
    };
    for (final e in entries) {
      final cat = HomebrewOtherCategory.classify(
        category: e.category,
        name: e.name,
        customProperties: e.customProperties,
      );
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }

  /// Prunes specified [HomebrewOtherCategory] subcategories from persistent storage
  /// while preserving all other custom entries and their raw payloads.
  ///
  /// Returns the number of entities removed.
  Future<int> clearOtherEntriesByCategories(Set<HomebrewOtherCategory> categories) async {
    if (categories.isEmpty) return 0;
    final allOthers = await loadCustomOtherEntries();
    if (allOthers.isEmpty) return 0;

    final remaining = <HomebrewCompendiumEntry>[];
    final removedSlugs = <String>{};

    for (final entry in allOthers) {
      final cat = HomebrewOtherCategory.classify(
        category: entry.category,
        name: entry.name,
        customProperties: entry.customProperties,
      );
      if (categories.contains(cat)) {
        removedSlugs.add(entry.id.slug);
      } else {
        remaining.add(entry);
      }
    }

    if (removedSlugs.isEmpty) return 0;

    // Save updated parsed list
    final prefs = await SharedPreferences.getInstance();
    final remainingJson = remaining.map((e) => json.encode(e.toMap())).toList();
    await _db.put(AppDatabaseService.boxHomebrew, _keyHomebrewOther, remainingJson);
    await prefs.setStringList(_keyHomebrewOther, remainingJson);

    // Prune removed slugs from raw payloads
    for (final slug in removedSlugs) {
      await _deleteRawPayload(_keyHomebrewOtherRaw, slug, prefs);
    }

    // Clean up runtime feature options if invocations or infusions were removed
    if (categories.contains(HomebrewOtherCategory.invocationsAndPacts)) {
      for (final slug in removedSlugs) {
        SrdFeatureOptions.removeCustomInvocation(slug);
      }
    }
    if (categories.contains(HomebrewOtherCategory.infusions)) {
      for (final slug in removedSlugs) {
        SrdFeatureOptions.removeCustomInfusion(slug);
      }
    }

    _hydrateCustomOtherSubsystems(remaining);

    return removedSlugs.length;
  }

  /// Batch deletes multiple custom entities by [slugs] for the given [EntityType].
  /// Returns the number of entities removed.
  Future<int> deleteCustomEntitiesBatch(EntityType type, List<String> slugs) async {
    if (slugs.isEmpty) return 0;
    final slugSet = slugs.toSet();
    int count = 0;

    switch (type) {
      case EntityType.spell:
        final spells = await loadCustomSpells();
        final initialLen = spells.length;
        spells.removeWhere((s) => slugSet.contains(s.id.slug));
        count = initialLen - spells.length;
        await _saveStringList(_keyHomebrewSpells, spells.map((s) => json.encode(s.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewSpellsRaw, slug);
        }

      case EntityType.monster:
        final monsters = await loadCustomMonsters();
        final initialLen = monsters.length;
        monsters.removeWhere((m) => slugSet.contains(m.id.slug));
        count = initialLen - monsters.length;
        await _saveStringList(_keyHomebrewMonsters, monsters.map((m) => json.encode(m.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewMonstersRaw, slug);
          MonsterCodexLibrary.removeHomebrewMonster(slug);
        }

      case EntityType.equipment:
        final items = await loadCustomItems();
        final initialLen = items.length;
        items.removeWhere((i) => slugSet.contains(i.id.slug));
        count = initialLen - items.length;
        await _saveStringList(_keyHomebrewItems, items.map((i) => json.encode(i.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewItemsRaw, slug);
        }

      case EntityType.classDefinition:
        final classes = await loadCustomClasses();
        final initialLen = classes.length;
        classes.removeWhere((c) => slugSet.contains(c.id.slug));
        count = initialLen - classes.length;
        await _saveStringList(_keyHomebrewClasses, classes.map((c) => json.encode(c.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewClassesRaw, slug);
          SrdClassesLibrary.removeCustomClass(slug);
        }

      case EntityType.subclass:
        final subs = await loadCustomSubclasses();
        final initialLen = subs.length;
        subs.removeWhere((s) => slugSet.contains(s.id.slug));
        count = initialLen - subs.length;
        await _saveStringList(_keyHomebrewSubclasses, subs.map((s) => json.encode(s.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewSubclassesRaw, slug);
        }

      case EntityType.species:
        final races = await loadCustomRaces();
        final initialLen = races.length;
        races.removeWhere((r) => slugSet.contains(r.id.slug));
        count = initialLen - races.length;
        await _saveStringList(_keyHomebrewRaces, races.map((r) => json.encode(r.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewRacesRaw, slug);
          SrdSpeciesLibrary.removeCustomSpecies(slug);
        }

      case EntityType.feat:
        final feats = await loadCustomFeats();
        final initialLen = feats.length;
        feats.removeWhere((f) => slugSet.contains(f.id.slug));
        count = initialLen - feats.length;
        await _saveStringList(_keyHomebrewFeats, feats.map((f) => json.encode(f.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewFeatsRaw, slug);
          SrdFeatsLibrary.removeCustomFeat(slug);
        }

      case EntityType.background:
        final bgs = await loadCustomBackgrounds();
        final initialLen = bgs.length;
        bgs.removeWhere((b) => slugSet.contains(b.id.slug));
        count = initialLen - bgs.length;
        await _saveStringList(_keyHomebrewBackgrounds, bgs.map((b) => json.encode(b.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewBackgroundsRaw, slug);
          SrdBackgroundsLibrary.removeCustomBackground(slug);
        }

      case EntityType.custom:
        final others = await loadCustomOtherEntries();
        final initialLen = others.length;
        others.removeWhere((o) => slugSet.contains(o.id.slug));
        count = initialLen - others.length;
        await _saveStringList(_keyHomebrewOther, others.map((o) => json.encode(o.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewOtherRaw, slug);
        }

      default:
        break;
    }

    SrdEquivalenceIndex().invalidate();
    return count;
  }

  /// Loads all custom fluff/lore from persistent storage.
  Future<List<EntityFluff>> loadCustomFluff() async {
    try {
      final rawList = await _loadStringList(_keyHomebrewFluff);
      final items = <EntityFluff>[];
      for (final jsonStr in rawList) {
        try {
          items.add(EntityFluff.fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map)));
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Corrupted fluff skipped in loadCustomFluff');
        }
      }
      if (items.isEmpty && EntityFluffService().fluffCount > 0) {
        return EntityFluffService().getAllFluff();
      }
      return items;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew fluff');
      return EntityFluffService().getAllFluff();
    }
  }

  /// Batch saves fluff entries to persistent storage and updates runtime [EntityFluffService].
  Future<void> saveCustomFluffBatch(
    List<EntityFluff> newFluff, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newFluff.isEmpty) return;
    EntityFluffService().batchRegisterFluff(newFluff);
    final allFluff = EntityFluffService().getAllFluff();
    await _saveStringList(
      _keyHomebrewFluff,
      allFluff.map((f) => json.encode(f.toMap())).toList(),
    );
    if (rawPayloads != null) {
      final payloadMap = <String, Map<String, dynamic>>{};
      for (int i = 0; i < newFluff.length && i < rawPayloads.length; i++) {
        payloadMap['${newFluff[i].entityType}_${newFluff[i].slug}'] = rawPayloads[i];
      }
      await _saveRawPayloadsBatch(_keyHomebrewFluffRaw, payloadMap);
    }
  }

  /// Exports saved homebrew entities into a portable [HomebrewBundle].
  Future<HomebrewBundle> exportHomebrewBundle({
    String? bundleName,
    String? author,
    String? description,
    Set<EntityType>? categories,
  }) async {
    final includeSpells = categories == null || categories.contains(EntityType.spell);
    final includeMonsters = categories == null || categories.contains(EntityType.monster);
    final includeItems = categories == null || categories.contains(EntityType.equipment);
    final includeClasses = categories == null || categories.contains(EntityType.classDefinition);
    final includeSubclasses = categories == null || categories.contains(EntityType.subclass);
    final includeRaces = categories == null || categories.contains(EntityType.species);
    final includeFeats = categories == null || categories.contains(EntityType.feat);
    final includeBackgrounds = categories == null || categories.contains(EntityType.background);
    final includeOther = categories == null || categories.contains(EntityType.custom);

    final races = includeRaces ? await loadCustomRaces() : const <Race>[];
    final standaloneSubs = await loadCustomSubraces();
    final subracesMap = <String, Subrace>{
      for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
      for (final s in standaloneSubs) s.id.slug: s,
      for (final r in races)
        for (final s in r.subraces) s.id.slug: s,
    };
    final subraces = subracesMap.values.toList();
    final fluffList = EntityFluffService().getAllFluff().isNotEmpty
        ? EntityFluffService().getAllFluff()
        : await loadCustomFluff();

    return HomebrewBundle(
      appVersion: '1.0.0',
      exportedAt: DateTime.now(),
      bundleName: bundleName,
      author: author,
      description: description,
      spells: includeSpells ? await loadCustomSpells() : const [],
      monsters: includeMonsters ? await loadCustomMonsters() : const [],
      items: includeItems ? await loadCustomItems() : const [],
      classes: includeClasses ? await loadCustomClasses() : const [],
      subclasses: includeSubclasses ? await loadCustomSubclasses() : const [],
      races: races,
      subraces: subraces,
      feats: includeFeats ? await loadCustomFeats() : const [],
      backgrounds: includeBackgrounds ? await loadCustomBackgrounds() : const [],
      otherEntries: includeOther ? await loadCustomOtherEntries() : const [],
      fluff: fluffList,
    );
  }

  /// Exports saved homebrew entities across all active registries into a comprehensive
  /// dictionary with sibling arrays (`races`, `subraces`, `classes`, `subclasses`, `backgrounds`, `feats`, `items`, `spells`, `monsters`, `fluff`).
  Future<Map<String, dynamic>> exportBundle({
    String? bundleName,
    String? author,
    String? description,
    Set<EntityType>? categories,
  }) async {
    final includeSpells = categories == null || categories.contains(EntityType.spell);
    final includeMonsters = categories == null || categories.contains(EntityType.monster);
    final includeItems = categories == null || categories.contains(EntityType.equipment);
    final includeClasses = categories == null || categories.contains(EntityType.classDefinition);
    final includeSubclasses = categories == null || categories.contains(EntityType.subclass);
    final includeRaces = categories == null || categories.contains(EntityType.species);
    final includeFeats = categories == null || categories.contains(EntityType.feat);
    final includeBackgrounds = categories == null || categories.contains(EntityType.background);
    final includeOther = categories == null || categories.contains(EntityType.custom);

    final spells = includeSpells ? await loadCustomSpells() : const <Spell>[];
    final monsters = includeMonsters ? await loadCustomMonsters() : const <Monster>[];
    final items = includeItems ? await loadCustomItems() : const <EquipmentItem>[];
    final classes = includeClasses ? await loadCustomClasses() : const <CharacterClass>[];
    final subclasses = includeSubclasses ? await loadCustomSubclasses() : const <Subclass>[];
    final races = includeRaces ? await loadCustomRaces() : const <Race>[];
    final standaloneSubs = await loadCustomSubraces();
    final exportSubracesMap = <String, Subrace>{
      for (final s in SrdSpeciesLibrary.customSubraces) s.id.slug: s,
      for (final s in standaloneSubs) s.id.slug: s,
      for (final r in races)
        for (final s in r.subraces) s.id.slug: s,
    };
    final subraces = exportSubracesMap.values.toList();
    final feats = includeFeats ? await loadCustomFeats() : const <Feat>[];
    final backgrounds = includeBackgrounds ? await loadCustomBackgrounds() : const <Background>[];
    final otherEntries = includeOther ? await loadCustomOtherEntries() : const <HomebrewCompendiumEntry>[];
    final fluffList = EntityFluffService().getAllFluff().isNotEmpty
        ? EntityFluffService().getAllFluff()
        : await loadCustomFluff();

    return {
      'schemaVersion': 1,
      'appVersion': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      if (bundleName != null) 'bundleName': bundleName,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      'spells': spells.map((s) => s.toMap()).toList(),
      'monsters': monsters.map((m) => m.toMap()).toList(),
      'items': items.map((i) => i.toMap()).toList(),
      'classes': classes.map((c) => c.toMap()).toList(),
      'subclasses': subclasses.map((s) => s.toMap()).toList(),
      'races': races.map((r) => r.toMap()).toList(),
      'subraces': subraces.map((s) => s.toMap()).toList(),
      'backgrounds': backgrounds.map((b) => b.toMap()).toList(),
      'feats': feats.map((f) => f.toMap()).toList(),
      if (otherEntries.isNotEmpty)
        'otherEntries': otherEntries.map((o) => o.toMap()).toList(),
      if (fluffList.isNotEmpty)
        'fluff': fluffList.map((f) => f.toMap()).toList(),
    };
  }

  /// Imports an analyzed and resolved [ImportAnalysisResult], writing entities to storage
  /// according to user-selected collision resolutions, and syncs runtime libraries immediately.
  ///
  /// [onProgress] is called after every entity write with (saved, total).
  Future<void> importResolvedBundle(
    ImportAnalysisResult resolution, {
    void Function(int saved, int total, String phase)? onProgress,
  }) async {
    // Pre-count total selected entities for accurate progress reporting
    final total = resolution.selectedCount;
    int saved = 0;

    void tick(String phase) {
      saved++;
      onProgress?.call(saved, total, phase);
    }
    // 1. Spells
    final existingSpells = await loadCustomSpells();
    final spellSlugs = existingSpells.map((s) => s.id.slug).toSet();
    final spellIndex = <String, int>{
      for (int i = 0; i < existingSpells.length; i++)
        '${existingSpells[i].id.slug}_${existingSpells[i].id.ruleset.name}': i,
    };
    bool spellsModified = false;
    for (final item in resolution.spells) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Spell toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, spellSlugs);
        spellSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = spellIndex[key];
      if (idx != null) {
        existingSpells[idx] = toSave;
      } else {
        spellIndex[key] = existingSpells.length;
        existingSpells.add(toSave);
      }
      spellsModified = true;
      tick('Spells');
    }
    if (spellsModified) {
      await _saveStringList(
        _keyHomebrewSpells,
        existingSpells.map((s) => json.encode(s.toMap())).toList(),
      );
    }

    // 2. Monsters
    final existingMonsters = await loadCustomMonsters();
    final monsterSlugs = existingMonsters.map((m) => m.id.slug).toSet();
    final monsterIndex = <String, int>{
      for (int i = 0; i < existingMonsters.length; i++)
        '${existingMonsters[i].id.slug}_${existingMonsters[i].id.ruleset.name}': i,
    };
    bool monstersModified = false;
    for (final item in resolution.monsters) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Monster toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, monsterSlugs);
        monsterSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = monsterIndex[key];
      if (idx != null) {
        existingMonsters[idx] = toSave;
      } else {
        monsterIndex[key] = existingMonsters.length;
        existingMonsters.add(toSave);
      }
      monstersModified = true;
      tick('Monsters');
    }
    if (monstersModified) {
      await _saveStringList(
        _keyHomebrewMonsters,
        existingMonsters.map((m) => json.encode(m.toMap())).toList(),
      );
    }

    // 3. Items
    final existingItems = await loadCustomItems();
    final itemSlugs = existingItems.map((i) => i.id.slug).toSet();
    final itemIndex = <String, int>{
      for (int i = 0; i < existingItems.length; i++)
        '${existingItems[i].id.slug}_${existingItems[i].id.ruleset.name}': i,
    };
    bool itemsModified = false;
    for (final item in resolution.items) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      EquipmentItem toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, itemSlugs);
        itemSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = itemIndex[key];
      if (idx != null) {
        existingItems[idx] = toSave;
      } else {
        itemIndex[key] = existingItems.length;
        existingItems.add(toSave);
      }
      itemsModified = true;
      tick('Items');
    }
    if (itemsModified) {
      await _saveStringList(
        _keyHomebrewItems,
        existingItems.map((i) => json.encode(i.toMap())).toList(),
      );
    }

    // 4. Classes
    final existingClasses = await loadCustomClasses();
    final classSlugs = existingClasses.map((c) => c.id.slug).toSet();
    final classIndex = <String, int>{
      for (int i = 0; i < existingClasses.length; i++)
        '${existingClasses[i].id.slug}_${existingClasses[i].id.ruleset.name}': i,
    };
    bool classesModified = false;
    for (final item in resolution.classes) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      CharacterClass toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, classSlugs);
        classSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = classIndex[key];
      if (idx != null) {
        existingClasses[idx] = toSave;
      } else {
        classIndex[key] = existingClasses.length;
        existingClasses.add(toSave);
      }
      classesModified = true;
      tick('Classes');
    }
    if (classesModified) {
      await _saveStringList(
        _keyHomebrewClasses,
        existingClasses.map((c) => json.encode(c.toMap())).toList(),
      );
    }

    // 5. Subclasses
    final existingSubclasses = await loadCustomSubclasses();
    final subSlugs = existingSubclasses.map((s) => s.id.slug).toSet();
    final subIndex = <String, int>{
      for (int i = 0; i < existingSubclasses.length; i++)
        '${existingSubclasses[i].id.slug}_${existingSubclasses[i].id.ruleset.name}': i,
    };
    bool subclassesModified = false;
    for (final item in resolution.subclasses) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Subclass toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, subSlugs);
        subSlugs.add(newSlug);
        toSave = Subclass(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
          classSlug: toSave.classSlug,
          shortName: '${toSave.shortName} (Copy)',
          featuresMarkdown: toSave.featuresMarkdown,
          customProperties: toSave.customProperties,
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = subIndex[key];
      if (idx != null) {
        existingSubclasses[idx] = toSave;
      } else {
        subIndex[key] = existingSubclasses.length;
        existingSubclasses.add(toSave);
      }
      subclassesModified = true;
      tick('Subclasses');
    }
    if (subclassesModified) {
      await _saveStringList(
        _keyHomebrewSubclasses,
        existingSubclasses.map((s) => json.encode(s.toMap())).toList(),
      );
    }

    // 6. Races
    final existingRaces = await loadCustomRaces();
    final raceSlugs = existingRaces.map((r) => r.id.slug).toSet();
    final raceIndex = <String, int>{
      for (int i = 0; i < existingRaces.length; i++)
        '${existingRaces[i].id.slug}_${existingRaces[i].id.ruleset.name}': i,
    };
    bool racesModified = false;
    for (final item in resolution.races) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Race toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, raceSlugs);
        raceSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = raceIndex[key];
      if (idx != null) {
        existingRaces[idx] = toSave;
      } else {
        raceIndex[key] = existingRaces.length;
        existingRaces.add(toSave);
      }
      racesModified = true;
      tick('Races & Species');
    }
    if (racesModified) {
      await _saveStringList(
        _keyHomebrewRaces,
        existingRaces.map((r) => json.encode(r.toMap())).toList(),
      );
    }

    // 7. Feats
    final existingFeats = await loadCustomFeats();
    final featSlugs = existingFeats.map((f) => f.id.slug).toSet();
    final featIndex = <String, int>{
      for (int i = 0; i < existingFeats.length; i++)
        '${existingFeats[i].id.slug}_${existingFeats[i].id.ruleset.name}': i,
    };
    bool featsModified = false;
    for (final item in resolution.feats) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Feat toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, featSlugs);
        featSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = featIndex[key];
      if (idx != null) {
        existingFeats[idx] = toSave;
      } else {
        featIndex[key] = existingFeats.length;
        existingFeats.add(toSave);
      }
      featsModified = true;
      tick('Feats');
    }
    if (featsModified) {
      await _saveStringList(
        _keyHomebrewFeats,
        existingFeats.map((f) => json.encode(f.toMap())).toList(),
      );
    }

    // 8. Backgrounds
    final existingBgs = await loadCustomBackgrounds();
    final bgSlugs = existingBgs.map((b) => b.id.slug).toSet();
    final bgIndex = <String, int>{
      for (int i = 0; i < existingBgs.length; i++)
        '${existingBgs[i].id.slug}_${existingBgs[i].id.ruleset.name}': i,
    };
    bool bgsModified = false;
    for (final item in resolution.backgrounds) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      Background toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, bgSlugs);
        bgSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = bgIndex[key];
      if (idx != null) {
        existingBgs[idx] = toSave;
      } else {
        bgIndex[key] = existingBgs.length;
        existingBgs.add(toSave);
      }
      bgsModified = true;
      tick('Backgrounds');
    }
    if (bgsModified) {
      await _saveStringList(
        _keyHomebrewBackgrounds,
        existingBgs.map((b) => json.encode(b.toMap())).toList(),
      );
    }

    // 9. Other entries
    final existingOthers = await loadCustomOtherEntries();
    final otherSlugs = existingOthers.map((o) => o.id.slug).toSet();
    final otherIndex = <String, int>{
      for (int i = 0; i < existingOthers.length; i++)
        '${existingOthers[i].id.slug}_${existingOthers[i].id.ruleset.name}': i,
    };
    bool othersModified = false;
    for (final item in resolution.otherEntries) {
      if (!item.isSelected) continue;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.keepLocal) {
        continue;
      }

      HomebrewCompendiumEntry toSave = item.incomingEntity;
      if (item.disposition == ImportDisposition.collision &&
          item.resolution == CollisionResolution.duplicateRename) {
        final newSlug = HomebrewMergeResolver.generateUniqueSlug(toSave.id.slug, otherSlugs);
        otherSlugs.add(newSlug);
        toSave = toSave.copyWith(
          id: EntityId(slug: newSlug, ruleset: toSave.id.ruleset),
          name: '${toSave.name} (Copy)',
        );
      }
      final key = '${toSave.id.slug}_${toSave.id.ruleset.name}';
      final idx = otherIndex[key];
      if (idx != null) {
        existingOthers[idx] = toSave;
      } else {
        otherIndex[key] = existingOthers.length;
        existingOthers.add(toSave);
      }
      othersModified = true;
      tick('Rules & Tables');
    }
    if (othersModified) {
      await _saveStringList(
        _keyHomebrewOther,
        existingOthers.map((e) => json.encode(e.toMap())).toList(),
      );
    }

    // Save any pending lore/fluff to persistent storage
    if (EntityFluffService().fluffCount > 0) {
      await saveCustomFluffBatch(EntityFluffService().getAllFluff());
    }

    // Immediately synchronize runtime libraries
    await syncToLibraries();
  }

  /// Hydrates a LayeredPriorityRepository with saved Homebrew and Campaign Overrides.
  Future<void> hydrateRepository(LayeredPriorityRepository repository) async {
    // 1. Homebrew Layer
    PriorityLayer? homebrewLayer;
    try {
      homebrewLayer = repository.layers.firstWhere(
        (l) => l.layerId == 'homebrew-packs',
      );
    } catch (_) {
      homebrewLayer = PriorityLayer(
        layerId: 'homebrew-packs',
        name: 'Homebrew & Custom Packs',
        priority: LayerPriority.homebrewPacks,
      );
      repository.addLayer(homebrewLayer);
    }

    final spells = await loadCustomSpells();
    for (final s in spells) {
      homebrewLayer.registerEntity(s);
    }

    final monsters = await loadCustomMonsters();
    for (final m in monsters) {
      homebrewLayer.registerEntity(m);
    }

    final items = await loadCustomItems();
    for (final i in items) {
      homebrewLayer.registerEntity(i);
    }

    final classes = await loadCustomClasses();
    for (final c in classes) {
      homebrewLayer.registerEntity(c);
    }

    final subclasses = await loadCustomSubclasses();
    for (final sub in subclasses) {
      homebrewLayer.registerEntity(sub);
    }

    final races = await loadCustomRaces();
    for (final r in races) {
      homebrewLayer.registerEntity(r);
    }

    final feats = await loadCustomFeats();
    for (final f in feats) {
      homebrewLayer.registerEntity(f);
    }

    final backgrounds = await loadCustomBackgrounds();
    for (final b in backgrounds) {
      homebrewLayer.registerEntity(b);
    }

    final others = await loadCustomOtherEntries();
    for (final o in others) {
      homebrewLayer.registerEntity(o);
    }
  }

  /// Clears all saved homebrew and override data.
  Future<void> clearAllHomebrew() async {
    final prefs = await SharedPreferences.getInstance();
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewSpells);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewMonsters);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewItems);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewClasses);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewSubclasses);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewRaces);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewFeats);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewBackgrounds);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewOther);
    await _db.delete(AppDatabaseService.boxHomebrew, _keyCampaignOverrides);

    await prefs.remove(_keyHomebrewSpells);
    await prefs.remove(_keyHomebrewMonsters);
    await prefs.remove(_keyHomebrewItems);
    await prefs.remove(_keyHomebrewClasses);
    await prefs.remove(_keyHomebrewSubclasses);
    await prefs.remove(_keyHomebrewRaces);
    await prefs.remove(_keyHomebrewFeats);
    await prefs.remove(_keyHomebrewBackgrounds);
    await prefs.remove(_keyHomebrewOther);
    await prefs.remove(_keyCampaignOverrides);

    // Clear raw payload keys
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewSpellsRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewMonstersRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewItemsRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewClassesRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewSubclassesRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewRacesRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewFeatsRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewBackgroundsRaw);
    await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewOtherRaw);

    await prefs.remove(_keyHomebrewSpellsRaw);
    await prefs.remove(_keyHomebrewMonstersRaw);
    await prefs.remove(_keyHomebrewItemsRaw);
    await prefs.remove(_keyHomebrewClassesRaw);
    await prefs.remove(_keyHomebrewSubclassesRaw);
    await prefs.remove(_keyHomebrewRacesRaw);
    await prefs.remove(_keyHomebrewFeatsRaw);
    await prefs.remove(_keyHomebrewBackgroundsRaw);
    await prefs.remove(_keyHomebrewOtherRaw);

    MonsterCodexLibrary.clearHomebrewMonsters();
    SpellbookLibrary.setHomebrewSpells([]);
    SrdSpeciesLibrary.setCustomSpecies([]);
    SrdSpeciesLibrary.setCustomSubraces([]);
    SrdFeatsLibrary.setCustomFeats([]);
    SrdClassesLibrary.setCustomClasses([]);
    SrdClassesLibrary.setCustomSubclasses([]);
    SrdBackgroundsLibrary.setCustomBackgrounds([]);
    _hydrateCustomOtherSubsystems([]);
    SrdEquivalenceIndex().invalidate();
  }

  /// Purges all persisted data for a single [EntityType] category and
  /// refreshes the corresponding runtime library.
  ///
  /// Only [classDefinition], [subclass], [species], [feat], [background],
  /// [equipment], [spell], [monster], and [custom] are supported.
  Future<void> clearHomebrewCategory(EntityType type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case EntityType.spell:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewSpells);
        await prefs.remove(_keyHomebrewSpells);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewSpellsRaw);
        await prefs.remove(_keyHomebrewSpellsRaw);
        SpellbookLibrary.setHomebrewSpells([]);
      case EntityType.monster:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewMonsters);
        await prefs.remove(_keyHomebrewMonsters);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewMonstersRaw);
        await prefs.remove(_keyHomebrewMonstersRaw);
        MonsterCodexLibrary.clearHomebrewMonsters();
      case EntityType.equipment:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewItems);
        await prefs.remove(_keyHomebrewItems);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewItemsRaw);
        await prefs.remove(_keyHomebrewItemsRaw);
      case EntityType.classDefinition:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewClasses);
        await prefs.remove(_keyHomebrewClasses);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewClassesRaw);
        await prefs.remove(_keyHomebrewClassesRaw);
        SrdClassesLibrary.setCustomClasses([]);
      case EntityType.subclass:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewSubclasses);
        await prefs.remove(_keyHomebrewSubclasses);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewSubclassesRaw);
        await prefs.remove(_keyHomebrewSubclassesRaw);
        SrdClassesLibrary.setCustomSubclasses([]);
      case EntityType.species:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewRaces);
        await prefs.remove(_keyHomebrewRaces);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewRacesRaw);
        await prefs.remove(_keyHomebrewRacesRaw);
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewSubraces);
        await prefs.remove(_keyHomebrewSubraces);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewSubracesRaw);
        await prefs.remove(_keyHomebrewSubracesRaw);
        SrdSpeciesLibrary.setCustomSpecies([]);
        SrdSpeciesLibrary.setCustomSubraces([]);
      case EntityType.feat:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewFeats);
        await prefs.remove(_keyHomebrewFeats);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewFeatsRaw);
        await prefs.remove(_keyHomebrewFeatsRaw);
        SrdFeatsLibrary.setCustomFeats([]);
      case EntityType.background:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewBackgrounds);
        await prefs.remove(_keyHomebrewBackgrounds);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewBackgroundsRaw);
        await prefs.remove(_keyHomebrewBackgroundsRaw);
        SrdBackgroundsLibrary.setCustomBackgrounds([]);
      case EntityType.custom:
        await _db.delete(AppDatabaseService.boxHomebrew, _keyHomebrewOther);
        await prefs.remove(_keyHomebrewOther);
        await _db.delete(AppDatabaseService.boxHomebrewRaw, _keyHomebrewOtherRaw);
        await prefs.remove(_keyHomebrewOtherRaw);
        _hydrateCustomOtherSubsystems([]);
      default:
        break;
    }
    SrdEquivalenceIndex().invalidate();
  }

  /// Loads the raw source JSON payloads for the given [EntityType].
  /// Returns an empty list for entities without raw payloads (imported before
  /// raw storage was added).
  Future<List<Map<String, dynamic>>> loadRawPayloads(EntityType type) async {
    final key = _rawKeyForType(type);
    if (key == null) return [];
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          return dbVal.values
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } else if (dbVal is String && dbVal.isNotEmpty) {
          final decoded = json.decode(dbVal) as Map<String, dynamic>;
          return decoded.values
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      if (stored == null || stored.isEmpty) return [];
      final decoded = json.decode(stored) as Map<String, dynamic>;
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        await _db.put(AppDatabaseService.boxHomebrewRaw, key, decoded);
      }
      return decoded.values
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load raw payloads for $type');
      return [];
    }
  }

  /// Returns how many entities of [type] have stored raw payloads.
  Future<int> rawPayloadCount(EntityType type) async {
    final payloads = await loadRawPayloads(type);
    return payloads.length;
  }

  /// Re-parses all homebrew entities that have raw payloads using the latest
  /// parser logic and SRD equivalence filter.
  ///
  /// Returns a [ReparseResult] describing what changed.
  Future<ReparseResult> reparseAllHomebrew() async {
    final srdIndex = SrdEquivalenceIndex();
    srdIndex.build();

    int updated = 0;
    int srdRemoved = 0;
    int noPayload = 0;

    // Count entities without raw payloads (so the UI can report it)
    for (final type in _reparsableTypes) {
      final payloads = await loadRawPayloads(type);
      final entities = await _loadEntitiesForType(type);
      noPayload += entities.length - payloads.length;
    }

    // Re-parse spells
    final spellParser = CompendiumSpellParser();
    updated += await _reparseCategory<Spell>(
      rawKey: _keyHomebrewSpellsRaw,
      parsedKey: _keyHomebrewSpells,
      fromRaw: (raw) => spellParser.parseSpell(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.spell,
      onSrdRemoved: (slug) {
        srdRemoved++;
      },
    );

    // Re-parse monsters
    final monsterParser = CompendiumMonsterParser();
    updated += await _reparseCategory<Monster>(
      rawKey: _keyHomebrewMonstersRaw,
      parsedKey: _keyHomebrewMonsters,
      fromRaw: (raw) => monsterParser.parseMonster(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.monster,
      onSrdRemoved: (slug) {
        srdRemoved++;
        MonsterCodexLibrary.removeHomebrewMonster(slug);
      },
    );

    // Re-parse items
    updated += await _reparseCategory<EquipmentItem>(
      rawKey: _keyHomebrewItemsRaw,
      parsedKey: _keyHomebrewItems,
      fromRaw: (raw) => CompendiumItemParser().parseItem(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.equipment,
    );

    // Re-parse classes
    final classParser = CompendiumClassParser();
    updated += await _reparseCategory<CharacterClass>(
      rawKey: _keyHomebrewClassesRaw,
      parsedKey: _keyHomebrewClasses,
      fromRaw: (raw) => classParser.parseClass(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.classDefinition,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdClassesLibrary.removeCustomClass(slug);
      },
    );

    // Re-parse subclasses
    updated += await _reparseCategory<Subclass>(
      rawKey: _keyHomebrewSubclassesRaw,
      parsedKey: _keyHomebrewSubclasses,
      fromRaw: (raw) => classParser.parseSubclass(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.subclass,
    );

    // Re-parse races
    updated += await _reparseCategory<Race>(
      rawKey: _keyHomebrewRacesRaw,
      parsedKey: _keyHomebrewRaces,
      fromRaw: (raw) => CompendiumRaceParser().parseRace(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.species,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdSpeciesLibrary.removeCustomSpecies(slug);
      },
    );

    // Re-parse subraces
    updated += await _reparseCategory<Subrace>(
      rawKey: _keyHomebrewSubracesRaw,
      parsedKey: _keyHomebrewSubraces,
      fromRaw: (raw) => CompendiumRaceParser().parseSubrace(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.species,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdSpeciesLibrary.removeCustomSubrace(slug);
      },
    );

    // Re-parse feats
    updated += await _reparseCategory<Feat>(
      rawKey: _keyHomebrewFeatsRaw,
      parsedKey: _keyHomebrewFeats,
      fromRaw: (raw) => CompendiumFeatParser().parseFeat(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.feat,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdFeatsLibrary.removeCustomFeat(slug);
      },
    );

    // Re-parse backgrounds
    updated += await _reparseCategory<Background>(
      rawKey: _keyHomebrewBackgroundsRaw,
      parsedKey: _keyHomebrewBackgrounds,
      fromRaw: (raw) => CompendiumBackgroundParser().parseBackground(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.background,
      onSrdRemoved: (slug) {
        srdRemoved++;
        SrdBackgroundsLibrary.removeCustomBackground(slug);
      },
    );

    // Re-parse rules and other entries
    final genericParser = CompendiumGenericEntryParser();
    updated += await _reparseCategory<HomebrewCompendiumEntry>(
      rawKey: _keyHomebrewOtherRaw,
      parsedKey: _keyHomebrewOther,
      fromRaw: (raw) => genericParser.parseGenericEntry(raw),
      toJson: (e) => json.encode(e.toMap()),
      srdIndex: srdIndex,
      entityType: EntityType.custom,
      onSrdRemoved: (slug) {
        srdRemoved++;
      },
    );

    await syncToLibraries();
    srdIndex.invalidate();

    return ReparseResult(
      updatedCount: updated,
      srdRemovedCount: srdRemoved,
      noPayloadCount: noPayload,
    );
  }

  // ---------------------------------------------------------------------------
  // Private: raw payload storage helpers
  // ---------------------------------------------------------------------------

  /// Saves multiple raw JSON payloads keyed by entity slug in a single batch transaction.
  Future<void> _saveRawPayloadsBatch(
    String key,
    Map<String, Map<String, dynamic>> payloadsBySlug, [
    SharedPreferences? prefs,
  ]) async {
    if (payloadsBySlug.isEmpty) return;
    try {
      Map<String, dynamic> map = {};
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          map = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(dbVal) as Map);
        }
      }
      if (map.isEmpty) {
        final p = prefs ?? await SharedPreferences.getInstance();
        final existing = p.getString(key);
        if (existing != null && existing.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(existing) as Map);
        }
      }
      map.addAll(payloadsBySlug);
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        await _db.put(AppDatabaseService.boxHomebrewRaw, key, map);
      }

      try {
        final p = prefs ?? await SharedPreferences.getInstance();
        await p.setString(key, json.encode(map));
      } catch (_) {}
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to batch save raw payloads for $key');
    }
  }

  /// Public accessor to save a single raw JSON payload for homebrew entities.
  Future<void> saveCustomRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload,
  ) async {
    await _saveRawPayload(key, entitySlug, rawPayload);
  }

  /// Saves a single raw JSON payload keyed by [entitySlug].
  /// Uses a `Map<slug, rawJson>` stored in database and syncs to SharedPreferences.
  Future<void> _saveRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload, [
    SharedPreferences? prefs,
  ]) async {
    await _saveRawPayloadsBatch(key, {entitySlug: rawPayload}, prefs);
  }

  /// Removes the raw payload for [entitySlug] from [key].
  Future<void> _deleteRawPayload(
    String key,
    String entitySlug, [
    SharedPreferences? prefs,
  ]) async {
    try {
      Map<String, dynamic> map = {};
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrewRaw, key);
        if (dbVal is Map) {
          map = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          map = Map<String, dynamic>.from(json.decode(dbVal) as Map);
        }
        map.remove(entitySlug);
        await _db.put(AppDatabaseService.boxHomebrewRaw, key, map);
      }

      try {
        final p = prefs ?? await SharedPreferences.getInstance();
        final existing = p.getString(key);
        if (existing != null && existing.isNotEmpty) {
          final pMap = Map<String, dynamic>.from(json.decode(existing) as Map);
          pMap.remove(entitySlug);
          await p.setString(key, json.encode(pMap));
        }
      } catch (_) {}
    } catch (_) {}
  }

  /// Maps an [EntityType] to its raw payload SharedPreferences key.
  String? _rawKeyForType(EntityType type) => switch (type) {
    EntityType.spell => _keyHomebrewSpellsRaw,
    EntityType.monster => _keyHomebrewMonstersRaw,
    EntityType.equipment => _keyHomebrewItemsRaw,
    EntityType.classDefinition => _keyHomebrewClassesRaw,
    EntityType.subclass => _keyHomebrewSubclassesRaw,
    EntityType.species => _keyHomebrewRacesRaw,
    EntityType.feat => _keyHomebrewFeatsRaw,
    EntityType.background => _keyHomebrewBackgroundsRaw,
    EntityType.custom => _keyHomebrewOtherRaw,
    _ => null,
  };

  static const List<EntityType> _reparsableTypes = [
    EntityType.spell,
    EntityType.monster,
    EntityType.equipment,
    EntityType.classDefinition,
    EntityType.subclass,
    EntityType.species,
    EntityType.feat,
    EntityType.background,
    EntityType.custom,
  ];

  Future<List<dynamic>> _loadEntitiesForType(EntityType type) async {
    return switch (type) {
      EntityType.spell => await loadCustomSpells(),
      EntityType.monster => await loadCustomMonsters(),
      EntityType.equipment => await loadCustomItems(),
      EntityType.classDefinition => await loadCustomClasses(),
      EntityType.subclass => await loadCustomSubclasses(),
      EntityType.species => await loadCustomRaces(),
      EntityType.feat => await loadCustomFeats(),
      EntityType.background => await loadCustomBackgrounds(),
      EntityType.custom => await loadCustomOtherEntries(),
      _ => [],
    };
  }

  /// Generic re-parse engine for a single category.
  Future<int> _reparseCategory<T extends DomainEntity>({
    required String rawKey,
    required String parsedKey,
    required T Function(Map<String, dynamic>) fromRaw,
    required String Function(T) toJson,
    required SrdEquivalenceIndex srdIndex,
    required EntityType entityType,
    void Function(String slug)? onSrdRemoved,
  }) async {
    try {
      Map<String, dynamic> rawMap = {};
      if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
        final dbVal = _db.get(AppDatabaseService.boxHomebrewRaw, rawKey);
        if (dbVal is Map) {
          rawMap = Map<String, dynamic>.from(dbVal);
        } else if (dbVal is String && dbVal.isNotEmpty) {
          try {
            rawMap = Map<String, dynamic>.from(json.decode(dbVal) as Map);
          } catch (_) {}
        }
      }
      if (rawMap.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final storedRaw = prefs.getString(rawKey);
        if (storedRaw != null && storedRaw.isNotEmpty) {
          try {
            rawMap = Map<String, dynamic>.from(json.decode(storedRaw) as Map);
          } catch (_) {}
        }
      }

      final reparsed = <T>[];
      final slugsToPrune = <String>{};
      final seenSlugs = <String>{};

      // 1. Re-parse from raw JSON payloads where available
      for (final entry in rawMap.entries) {
        final rawPayload = Map<String, dynamic>.from(entry.value as Map);
        try {
          final entity = fromRaw(rawPayload);
          final srdResult = srdIndex.checkEntity(
            slug: entity.id.slug,
            name: entity.name,
            type: entityType,
          );
          if (srdResult != SrdMatchResult.notSrd) {
            slugsToPrune.add(entry.key);
            slugsToPrune.add(entity.id.slug);
            onSrdRemoved?.call(entity.id.slug);
            continue;
          }
          if (seenSlugs.contains(entity.id.slug)) {
            continue;
          }
          seenSlugs.add(entity.id.slug);
          reparsed.add(entity);
        } catch (e, st) {
          LoggingService().logNonFatal(e, st, reason: 'Re-parse failed for ${entry.key}');
        }
      }

      // 2. Remove pruned SRD keys from rawMap and save back
      if (slugsToPrune.isNotEmpty) {
        for (final slug in slugsToPrune) {
          rawMap.remove(slug);
        }
        if (_db.isBoxOpen(AppDatabaseService.boxHomebrewRaw)) {
          await _db.put(AppDatabaseService.boxHomebrewRaw, rawKey, rawMap);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(rawKey, json.encode(rawMap));
        } catch (_) {}
      }

      // 3. Check legacy parsed store for any SRD duplicates not in rawMap
      final existingParsed = await _loadStringList(parsedKey);
      final allSlugsHandled = <String>{
        ...seenSlugs,
        ...slugsToPrune,
      };
      if (entityType == EntityType.subclass) {
        for (final s in seenSlugs) {
          if (s.contains('-')) {
            // "artificer-alchemist" -> also mark "alchemist" as handled
            allSlugsHandled.add(s.split('-').skip(1).join('-'));
          }
        }
      }

      for (final jsonStr in existingParsed) {
        try {
          final decoded = json.decode(jsonStr) as Map<String, dynamic>;
          final idObj = decoded['id'];
          final slug = idObj is Map ? (idObj['slug']?.toString() ?? '') : (decoded['slug']?.toString() ?? '');
          final name = decoded['name']?.toString() ?? '';

          if (slug.isNotEmpty && !allSlugsHandled.contains(slug) && !seenSlugs.contains(slug)) {
            final srdResult = srdIndex.checkEntity(
              slug: slug,
              name: name,
              type: entityType,
            );
            if (srdResult != SrdMatchResult.notSrd) {
              onSrdRemoved?.call(slug);
              allSlugsHandled.add(slug);
              continue;
            }
            // Keep non-SRD legacy entity
            T? legacyEntity;
            try {
              legacyEntity = fromRaw(decoded);
            } catch (_) {
              legacyEntity = _restoreLegacyEntity<T>(decoded, entityType);
            }
            if (legacyEntity != null && !seenSlugs.contains(legacyEntity.id.slug)) {
              seenSlugs.add(legacyEntity.id.slug);
              allSlugsHandled.add(slug);
              reparsed.add(legacyEntity);
            }
            allSlugsHandled.add(slug);
          }
        } catch (_) {}
      }

      await _saveStringList(parsedKey, reparsed.map(toJson).toList());
      return reparsed.length;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Re-parse category $entityType failed');
      return 0;
    }
  }

  T? _restoreLegacyEntity<T extends DomainEntity>(Map<String, dynamic> map, EntityType type) {
    try {
      return switch (type) {
        EntityType.spell => Spell.fromMap(map) as T,
        EntityType.monster => Monster.fromMap(map) as T,
        EntityType.equipment => EquipmentItem.fromMap(map) as T,
        EntityType.classDefinition => CharacterClass.fromMap(map) as T,
        EntityType.subclass => Subclass.fromMap(map) as T,
        EntityType.species =>
            (map.containsKey('raceSlug') ? Subrace.fromMap(map) : Race.fromMap(map)) as T,
        EntityType.feat => Feat.fromMap(map) as T,
        EntityType.background => Background.fromMap(map) as T,
        EntityType.custom => HomebrewCompendiumEntry.fromMap(map) as T,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  RulesetVersion _mapDomainRulesetToCore(domain_rules.RulesetVersion ruleset) {
    return switch (ruleset) {
      domain_rules.RulesetVersion.srd2014 => RulesetVersion.v2014,
      domain_rules.RulesetVersion.srd2024 => RulesetVersion.v2024,
    };
  }

  /// Persists a batch of [HomebrewEntity] items parsed from remote repositories
  /// into canonical storage collections and optionally synchronizes runtime libraries.
  Future<void> saveHomebrewEntitiesBatch(
    List<HomebrewEntity> entities, {
    bool syncLibraries = true,
    bool excludeSrdCanon = true,
  }) async {
    if (entities.isEmpty) return;

    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final subraces = <Subrace>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final others = <HomebrewCompendiumEntry>[];
    final fluffToSave = <EntityFluff>[];

    final spellPayloads = <Map<String, dynamic>>[];
    final monsterPayloads = <Map<String, dynamic>>[];
    final itemPayloads = <Map<String, dynamic>>[];
    final classPayloads = <Map<String, dynamic>>[];
    final subclassPayloads = <Map<String, dynamic>>[];
    final racePayloads = <Map<String, dynamic>>[];
    final subracePayloads = <Map<String, dynamic>>[];
    final featPayloads = <Map<String, dynamic>>[];
    final backgroundPayloads = <Map<String, dynamic>>[];
    final otherPayloads = <Map<String, dynamic>>[];
    final fluffPayloads = <Map<String, dynamic>>[];

    final adapters = CommunityCompendiumAdapters();
    final raceParser = CompendiumRaceParser();
    final genericParser = CompendiumGenericEntryParser();
    final srdIndex = SrdEquivalenceIndex();
    if (excludeSrdCanon) srdIndex.build();

    const creatureTypes = {
      'monster',
      'creature',
      'npc',
      'bestiary',
      'aberration',
      'beast',
      'celestial',
      'construct',
      'dragon',
      'elemental',
      'fey',
      'fiend',
      'giant',
      'humanoid',
      'monstrosity',
      'ooze',
      'plant',
      'undead',
    };

    for (final entity in entities) {
      final payload = Map<String, dynamic>.from(entity.rawPayload);
      final coreRuleset = _mapDomainRulesetToCore(entity.ruleset);
      final typeLower = entity.entityType.toLowerCase().trim();

      final isFluff = typeLower.endsWith('fluff') ||
          typeLower == 'fluff' ||
          ((typeLower == 'custom' || typeLower == 'generic') &&
              (payload.containsKey('_fluff') || payload.containsKey('flufftype')));

      if (isFluff) {
        final rawType = typeLower.endsWith('fluff') && typeLower != 'fluff'
            ? typeLower.substring(0, typeLower.length - 5)
            : 'generic';
        final pipeline = CompendiumJsonIngestionPipeline();
        final batchResult = pipeline.ingestJsonMap({
          '${rawType}Fluff': [payload],
        });
        fluffToSave.addAll(batchResult.fluff);
        fluffPayloads.add(payload);
        continue;
      }

      final isMonster = creatureTypes.contains(typeLower) ||
          typeLower.startsWith('{type:') ||
          payload.containsKey('cr') ||
          payload.containsKey('challengeRating') ||
          payload.containsKey('hitDice');

      try {
        if (isMonster) {
          if (excludeSrdCanon &&
              srdIndex.checkEntity(
                    slug: entity.id,
                    name: entity.name,
                    type: EntityType.monster,
                  ) !=
                  SrdMatchResult.notSrd) {
            continue;
          }
          monsters.add(adapters.parseMonster(payload, forceRuleset: coreRuleset));
          monsterPayloads.add(payload);
        } else {
          switch (typeLower) {
            case 'spell':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.spell,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              spells.add(adapters.parseSpell(payload, forceRuleset: coreRuleset));
              spellPayloads.add(payload);
            case 'equipment' || 'item' || 'magicitem' || 'weapon' || 'armor' || 'baseitem' || 'magicvariant':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.equipment,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              items.add(adapters.parseItem(payload, forceRuleset: coreRuleset));
              itemPayloads.add(payload);
            case 'class':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.classDefinition,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              classes.add(adapters.parseClass(payload, forceRuleset: coreRuleset));
              classPayloads.add(payload);
            case 'subclass':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.subclass,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              subclasses.add(adapters.parseSubclass(payload, forceRuleset: coreRuleset));
              subclassPayloads.add(payload);
            case 'race' || 'species':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.species,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              races.add(adapters.parseRace(payload, forceRuleset: coreRuleset));
              racePayloads.add(payload);
            case 'subrace':
              final sub = raceParser.parseSubrace(payload, forceRuleset: coreRuleset);
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: sub.id.slug,
                        name: sub.name,
                        type: EntityType.species,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              subraces.add(sub);
              subracePayloads.add(payload);
              SrdSpeciesLibrary.addCustomSubrace(sub);

              if (sub.raceSlug.isNotEmpty) {
                final match = races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
                if (match != null) {
                  final idx = races.indexOf(match);
                  races[idx] = match.copyWith(subraces: [...match.subraces, sub]);
                  if (idx < racePayloads.length) {
                    final existingSubs = List<dynamic>.from(racePayloads[idx]['subraces'] as List? ?? []);
                    existingSubs.add(payload);
                    racePayloads[idx] = {
                      ...racePayloads[idx],
                      'subraces': existingSubs,
                    };
                  }
                } else if (!excludeSrdCanon ||
                    srdIndex.checkEntity(
                          slug: sub.raceSlug,
                          name: sub.raceSlug.replaceAll('-', ' '),
                          type: EntityType.species,
                        ) ==
                        SrdMatchResult.notSrd) {
                  final parentName = (payload['raceName'] as String?) ?? sub.raceSlug.replaceAll('-', ' ');
                  races.add(Race(
                    id: EntityId(slug: sub.raceSlug, ruleset: coreRuleset),
                    name: parentName,
                    traitsMarkdown: '',
                    subraces: [sub],
                  ));
                  racePayloads.add({
                    'name': parentName,
                    'slug': sub.raceSlug,
                    'entityType': 'race',
                    'subraces': [payload],
                  });
                }
              }
            case 'feat':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.feat,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              feats.add(adapters.parseFeat(payload, forceRuleset: coreRuleset));
              featPayloads.add(payload);
            case 'background':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.background,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              backgrounds.add(adapters.parseBackground(payload, forceRuleset: coreRuleset));
              backgroundPayloads.add(payload);
            default:
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.custom,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              final entry = genericParser.parseGenericEntry(
                payload,
                defaultCategory: entity.entityType,
                forceRuleset: coreRuleset,
              );
              others.add(entry);
              otherPayloads.add(payload);
          }
        }
      } catch (_) {
        if (excludeSrdCanon &&
            srdIndex.checkEntity(
                  slug: entity.id,
                  name: entity.name,
                  type: EntityType.custom,
                ) !=
                SrdMatchResult.notSrd) {
          continue;
        }
        final entry = genericParser.parseGenericEntry(
          payload,
          defaultCategory: entity.entityType,
          forceRuleset: coreRuleset,
        );
        others.add(entry);
        otherPayloads.add(payload);
      }
    }

    if (spells.isNotEmpty) await saveCustomSpellsBatch(spells, rawPayloads: spellPayloads);
    if (monsters.isNotEmpty) await saveCustomMonstersBatch(monsters, rawPayloads: monsterPayloads);
    if (items.isNotEmpty) await saveCustomItemsBatch(items, rawPayloads: itemPayloads);
    if (classes.isNotEmpty) await saveCustomClassesBatch(classes, rawPayloads: classPayloads);
    if (subclasses.isNotEmpty) await saveCustomSubclassesBatch(subclasses, rawPayloads: subclassPayloads);
    if (races.isNotEmpty) await saveCustomRacesBatch(races, rawPayloads: racePayloads);
    if (subraces.isNotEmpty) await saveCustomSubracesBatch(subraces, rawPayloads: subracePayloads);
    if (feats.isNotEmpty) await saveCustomFeatsBatch(feats, rawPayloads: featPayloads);
    if (backgrounds.isNotEmpty) await saveCustomBackgroundsBatch(backgrounds, rawPayloads: backgroundPayloads);
    if (others.isNotEmpty) await saveCustomOtherEntriesBatch(others, rawPayloads: otherPayloads);
    if (fluffToSave.isNotEmpty) await saveCustomFluffBatch(fluffToSave, rawPayloads: fluffPayloads);

    if (syncLibraries) {
      await syncToLibraries();
    }
  }

  /// Persists a single [HomebrewEntity] into canonical storage and optionally synchronizes libraries.
  Future<void> saveHomebrewEntity(
    HomebrewEntity entity, {
    bool syncLibraries = true,
  }) async {
    await saveHomebrewEntitiesBatch([entity], syncLibraries: syncLibraries);
  }
}

/// Result of a [HomebrewPersistenceService.reparseAllHomebrew] run.
class ReparseResult {
  /// Number of entities successfully re-parsed and updated.
  final int updatedCount;

  /// Number of entities removed because they matched an SRD canonical entry.
  final int srdRemovedCount;

  /// Number of entities that could NOT be re-parsed because they were imported
  /// before raw payload storage was added.
  final int noPayloadCount;

  const ReparseResult({
    required this.updatedCount,
    required this.srdRemovedCount,
    required this.noPayloadCount,
  });

  bool get hadSrdRemovals => srdRemovedCount > 0;
  bool get hasUnreparseableEntities => noPayloadCount > 0;

  @override
  String toString() =>
      'ReparseResult(updated=$updatedCount, srdRemoved=$srdRemovedCount, noPayload=$noPayloadCount)';
}
