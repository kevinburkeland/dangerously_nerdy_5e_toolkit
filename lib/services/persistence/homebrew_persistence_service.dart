import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/characters/srd_species_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/monster_codex_data.dart';
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
import '../logging_service.dart';
import '../repository/layered_priority_repository.dart';

/// Service managing persistent storage and repository hydration for user-created homebrew and campaign overrides.
class HomebrewPersistenceService {
  static const String _keyHomebrewSpells = 'dn_homebrew_spells_v1';
  static const String _keyHomebrewMonsters = 'dn_homebrew_monsters_v1';
  static const String _keyHomebrewItems = 'dn_homebrew_items_v1';
  static const String _keyHomebrewClasses = 'dn_homebrew_classes_v1';
  static const String _keyHomebrewSubclasses = 'dn_homebrew_subclasses_v1';
  static const String _keyHomebrewRaces = 'dn_homebrew_races_v1';
  static const String _keyHomebrewFeats = 'dn_homebrew_feats_v1';
  static const String _keyHomebrewBackgrounds = 'dn_homebrew_backgrounds_v1';
  static const String _keyHomebrewOther = 'dn_homebrew_other_v1';
  static const String _keyCampaignOverrides = 'dn_campaign_overrides_v1';

  // Raw payload keys — store original source JSON for lossless re-parsing
  static const String _keyHomebrewSpellsRaw     = 'dn_homebrew_spells_raw_v1';
  static const String _keyHomebrewMonstersRaw   = 'dn_homebrew_monsters_raw_v1';
  static const String _keyHomebrewItemsRaw      = 'dn_homebrew_items_raw_v1';
  static const String _keyHomebrewClassesRaw    = 'dn_homebrew_classes_raw_v1';
  static const String _keyHomebrewSubclassesRaw = 'dn_homebrew_subclasses_raw_v1';
  static const String _keyHomebrewRacesRaw      = 'dn_homebrew_races_raw_v1';
  static const String _keyHomebrewFeatsRaw      = 'dn_homebrew_feats_raw_v1';
  static const String _keyHomebrewBackgroundsRaw = 'dn_homebrew_backgrounds_raw_v1';
  static const String _keyHomebrewOtherRaw      = 'dn_homebrew_other_raw_v1';

  static final HomebrewPersistenceService _instance =
      HomebrewPersistenceService._internal();
  factory HomebrewPersistenceService() => _instance;
  HomebrewPersistenceService._internal();

  /// Loads all custom spells from persistent storage.
  Future<List<Spell>> loadCustomSpells() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewSpells) ?? [];
      return rawList
          .map((jsonStr) =>
              Spell.fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewSpellsRaw, spell.id.slug, rawPayload, prefs);
    }
  }

  /// Batch saves multiple custom spells to persistent storage.
  Future<void> saveCustomSpellsBatch(
    List<Spell> newSpells, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newSpells.isEmpty) return;
    final spells = await loadCustomSpells();
    for (int i = 0; i < newSpells.length; i++) {
      final spell = newSpells[i];
      final idx = spells.indexWhere(
        (s) => s.id.slug == spell.id.slug && s.id.ruleset == spell.id.ruleset,
      );
      if (idx != -1) {
        spells[idx] = spell;
      } else {
        spells.add(spell);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newSpells.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewSpellsRaw, newSpells[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom spell by slug.
  Future<void> deleteCustomSpell(String slug) async {
    final spells = await loadCustomSpells();
    spells.removeWhere((s) => s.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSpells,
      spells.map((s) => json.encode(s.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewSpellsRaw, slug, prefs);
  }

  /// Loads all custom monsters from persistent storage.
  Future<List<Monster>> loadCustomMonsters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewMonsters) ?? [];
      return rawList
          .map((jsonStr) =>
              Monster.fromMap(Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew monsters');
      return [];
    }
  }

  /// Synchronizes all loaded homebrew entities into global runtime libraries.
  Future<void> syncToLibraries() async {
    final monsters = await loadCustomMonsters();
    MonsterCodexLibrary.setHomebrewMonsters(monsters);

    final races = await loadCustomRaces();
    SrdSpeciesLibrary.setCustomSpecies(races);

    final customSubraces = <Subrace>[];
    for (final r in races) {
      customSubraces.addAll(r.subraces);
    }
    SrdSpeciesLibrary.setCustomSubraces(customSubraces);

    final feats = await loadCustomFeats();
    SrdFeatsLibrary.setCustomFeats(feats);

    final classes = await loadCustomClasses();
    SrdClassesLibrary.setCustomClasses(classes);

    final subclasses = await loadCustomSubclasses();
    SrdClassesLibrary.setCustomSubclasses(subclasses);

    final backgrounds = await loadCustomBackgrounds();
    SrdBackgroundsLibrary.setCustomBackgrounds(backgrounds);

    final others = await loadCustomOtherEntries();
    final customInvocations = others
        .where((e) => e.category.toLowerCase().contains('invocation'))
        .map((e) => FeatureOption(
              id: e.id.slug,
              name: e.name,
              descriptionMarkdown: e.descriptionMarkdown,
            ))
        .toList();
    SrdFeatureOptions.setCustomInvocations(customInvocations);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewMonstersRaw, monster.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newMonsters.length; i++) {
      final monster = newMonsters[i];
      final idx = monsters.indexWhere(
        (m) => m.id.slug == monster.id.slug && m.id.ruleset == monster.id.ruleset,
      );
      if (idx != -1) {
        monsters[idx] = monster;
      } else {
        monsters.add(monster);
      }
      MonsterCodexLibrary.addHomebrewMonster(monster);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newMonsters.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewMonstersRaw, newMonsters[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom monster by slug and updates MonsterCodexLibrary.
  Future<void> deleteCustomMonster(String slug) async {
    final monsters = await loadCustomMonsters();
    monsters.removeWhere((m) => m.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewMonsters,
      monsters.map((m) => json.encode(m.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewMonstersRaw, slug, prefs);
    MonsterCodexLibrary.removeHomebrewMonster(slug);
  }

  /// Loads all custom items from persistent storage.
  Future<List<EquipmentItem>> loadCustomItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewItems) ?? [];
      return rawList
          .map((jsonStr) => EquipmentItem.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewItemsRaw, item.id.slug, rawPayload, prefs);
    }
  }

  /// Batch saves multiple custom items to persistent storage.
  Future<void> saveCustomItemsBatch(
    List<EquipmentItem> newItems, {
    List<Map<String, dynamic>>? rawPayloads,
  }) async {
    if (newItems.isEmpty) return;
    final items = await loadCustomItems();
    for (int i = 0; i < newItems.length; i++) {
      final item = newItems[i];
      final idx = items.indexWhere(
        (i) => i.id.slug == item.id.slug && i.id.ruleset == item.id.ruleset,
      );
      if (idx != -1) {
        items[idx] = item;
      } else {
        items.add(item);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newItems.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewItemsRaw, newItems[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom item by slug.
  Future<void> deleteCustomItem(String slug) async {
    final items = await loadCustomItems();
    items.removeWhere((i) => i.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewItems,
      items.map((i) => json.encode(i.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewItemsRaw, slug, prefs);
  }

  /// Loads all custom classes from persistent storage.
  Future<List<CharacterClass>> loadCustomClasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewClasses) ?? [];
      return rawList
          .map((jsonStr) => CharacterClass.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewClassesRaw, characterClass.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newClasses.length; i++) {
      final c = newClasses[i];
      final idx = classes.indexWhere(
        (existing) => existing.id.slug == c.id.slug && existing.id.ruleset == c.id.ruleset,
      );
      if (idx != -1) {
        classes[idx] = c;
      } else {
        classes.add(c);
      }
      SrdClassesLibrary.addCustomClass(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newClasses.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewClassesRaw, newClasses[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom class by slug and runtime library.
  Future<void> deleteCustomClass(String slug) async {
    final classes = await loadCustomClasses();
    classes.removeWhere((c) => c.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewClasses,
      classes.map((c) => json.encode(c.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewClassesRaw, slug, prefs);
    SrdClassesLibrary.removeCustomClass(slug);
  }

  /// Loads all custom subclasses from persistent storage.
  Future<List<Subclass>> loadCustomSubclasses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewSubclasses) ?? [];
      return rawList
          .map((jsonStr) => Subclass.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewSubclassesRaw, subclass.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newSubclasses.length; i++) {
      final s = newSubclasses[i];
      final idx = subs.indexWhere(
        (existing) => existing.id.slug == s.id.slug && existing.id.ruleset == s.id.ruleset,
      );
      if (idx != -1) {
        subs[idx] = s;
      } else {
        subs.add(s);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newSubclasses.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewSubclassesRaw, newSubclasses[i].id.slug, rawPayloads[i], prefs);
      }
    }
    for (final s in newSubclasses) {
      SrdClassesLibrary.addCustomSubclass(s);
    }
  }

  /// Deletes a custom subclass by slug.
  Future<void> deleteCustomSubclass(String slug) async {
    final subs = await loadCustomSubclasses();
    subs.removeWhere((s) => s.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewSubclasses,
      subs.map((s) => json.encode(s.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewSubclassesRaw, slug, prefs);
    SrdClassesLibrary.removeCustomSubclass(slug);
  }

  /// Loads all custom races from persistent storage.
  Future<List<Race>> loadCustomRaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewRaces) ?? [];
      return rawList
          .map((jsonStr) => Race.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewRacesRaw, race.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newRaces.length; i++) {
      final r = newRaces[i];
      final idx = races.indexWhere(
        (existing) => existing.id.slug == r.id.slug && existing.id.ruleset == r.id.ruleset,
      );
      if (idx != -1) {
        races[idx] = r;
      } else {
        races.add(r);
      }
      SrdSpeciesLibrary.addCustomSpecies(r);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newRaces.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewRacesRaw, newRaces[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom race by slug and runtime library.
  Future<void> deleteCustomRace(String slug) async {
    final races = await loadCustomRaces();
    races.removeWhere((r) => r.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewRaces,
      races.map((r) => json.encode(r.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewRacesRaw, slug, prefs);
    SrdSpeciesLibrary.removeCustomSpecies(slug);
  }

  /// Loads all custom feats from persistent storage.
  Future<List<Feat>> loadCustomFeats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewFeats) ?? [];
      return rawList
          .map((jsonStr) => Feat.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewFeatsRaw, feat.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newFeats.length; i++) {
      final f = newFeats[i];
      final idx = feats.indexWhere(
        (existing) => existing.id.slug == f.id.slug && existing.id.ruleset == f.id.ruleset,
      );
      if (idx != -1) {
        feats[idx] = f;
      } else {
        feats.add(f);
      }
      SrdFeatsLibrary.addCustomFeat(f);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newFeats.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewFeatsRaw, newFeats[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom feat by slug and runtime library.
  Future<void> deleteCustomFeat(String slug) async {
    final feats = await loadCustomFeats();
    feats.removeWhere((f) => f.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewFeats,
      feats.map((f) => json.encode(f.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewFeatsRaw, slug, prefs);
    SrdFeatsLibrary.removeCustomFeat(slug);
  }

  /// Loads all custom backgrounds from persistent storage.
  Future<List<Background>> loadCustomBackgrounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewBackgrounds) ?? [];
      return rawList
          .map((jsonStr) => Background.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewBackgroundsRaw, background.id.slug, rawPayload, prefs);
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
    for (int i = 0; i < newBackgrounds.length; i++) {
      final b = newBackgrounds[i];
      final idx = backgrounds.indexWhere(
        (existing) => existing.id.slug == b.id.slug && existing.id.ruleset == b.id.ruleset,
      );
      if (idx != -1) {
        backgrounds[idx] = b;
      } else {
        backgrounds.add(b);
      }
      SrdBackgroundsLibrary.addCustomBackground(b);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    if (rawPayloads != null) {
      for (int i = 0; i < newBackgrounds.length && i < rawPayloads.length; i++) {
        await _saveRawPayload(_keyHomebrewBackgroundsRaw, newBackgrounds[i].id.slug, rawPayloads[i], prefs);
      }
    }
  }

  /// Deletes a custom background by slug and runtime library.
  Future<void> deleteCustomBackground(String slug) async {
    final backgrounds = await loadCustomBackgrounds();
    backgrounds.removeWhere((b) => b.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewBackgrounds,
      backgrounds.map((b) => json.encode(b.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewBackgroundsRaw, slug, prefs);
    SrdBackgroundsLibrary.removeCustomBackground(slug);
  }

  /// Loads all custom generic entries (tables, rules, etc.) from persistent storage.
  Future<List<HomebrewCompendiumEntry>> loadCustomOtherEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyHomebrewOther) ?? [];
      return rawList
          .map((jsonStr) => HomebrewCompendiumEntry.fromMap(
              Map<String, dynamic>.from(json.decode(jsonStr) as Map)))
          .toList();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to load homebrew custom entries');
      return [];
    }
  }

  /// Saves a generic compendium entry to persistent storage.
  Future<void> saveCustomOtherEntry(HomebrewCompendiumEntry entry, {Map<String, dynamic>? rawPayload}) async {
    final entries = await loadCustomOtherEntries();
    final idx = entries.indexWhere((e) => e.id.slug == entry.id.slug);
    if (idx != -1) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );
    if (rawPayload != null) {
      await _saveRawPayload(_keyHomebrewOtherRaw, entry.id.slug, rawPayload, prefs);
    }
    if (entry.category.toLowerCase().contains('invocation')) {
      SrdFeatureOptions.addCustomInvocation(FeatureOption(
        id: entry.id.slug,
        name: entry.name,
        descriptionMarkdown: entry.descriptionMarkdown,
      ));
    }
  }

  /// Deletes a generic compendium entry by slug.
  Future<void> deleteCustomOtherEntry(String slug) async {
    final entries = await loadCustomOtherEntries();
    entries.removeWhere((e) => e.id.slug == slug);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyHomebrewOther,
      entries.map((e) => json.encode(e.toMap())).toList(),
    );
    await _deleteRawPayload(_keyHomebrewOtherRaw, slug, prefs);
    SrdFeatureOptions.removeCustomInvocation(slug);
  }

  /// Batch deletes multiple custom entities by [slugs] for the given [EntityType].
  /// Returns the number of entities removed.
  Future<int> deleteCustomEntitiesBatch(EntityType type, List<String> slugs) async {
    if (slugs.isEmpty) return 0;
    final slugSet = slugs.toSet();
    final prefs = await SharedPreferences.getInstance();
    int count = 0;

    switch (type) {
      case EntityType.spell:
        final spells = await loadCustomSpells();
        final initialLen = spells.length;
        spells.removeWhere((s) => slugSet.contains(s.id.slug));
        count = initialLen - spells.length;
        await prefs.setStringList(_keyHomebrewSpells, spells.map((s) => json.encode(s.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewSpellsRaw, slug, prefs);
        }

      case EntityType.monster:
        final monsters = await loadCustomMonsters();
        final initialLen = monsters.length;
        monsters.removeWhere((m) => slugSet.contains(m.id.slug));
        count = initialLen - monsters.length;
        await prefs.setStringList(_keyHomebrewMonsters, monsters.map((m) => json.encode(m.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewMonstersRaw, slug, prefs);
          MonsterCodexLibrary.removeHomebrewMonster(slug);
        }

      case EntityType.equipment:
        final items = await loadCustomItems();
        final initialLen = items.length;
        items.removeWhere((i) => slugSet.contains(i.id.slug));
        count = initialLen - items.length;
        await prefs.setStringList(_keyHomebrewItems, items.map((i) => json.encode(i.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewItemsRaw, slug, prefs);
        }

      case EntityType.classDefinition:
        final classes = await loadCustomClasses();
        final initialLen = classes.length;
        classes.removeWhere((c) => slugSet.contains(c.id.slug));
        count = initialLen - classes.length;
        await prefs.setStringList(_keyHomebrewClasses, classes.map((c) => json.encode(c.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewClassesRaw, slug, prefs);
          SrdClassesLibrary.removeCustomClass(slug);
        }

      case EntityType.subclass:
        final subs = await loadCustomSubclasses();
        final initialLen = subs.length;
        subs.removeWhere((s) => slugSet.contains(s.id.slug));
        count = initialLen - subs.length;
        await prefs.setStringList(_keyHomebrewSubclasses, subs.map((s) => json.encode(s.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewSubclassesRaw, slug, prefs);
        }

      case EntityType.species:
        final races = await loadCustomRaces();
        final initialLen = races.length;
        races.removeWhere((r) => slugSet.contains(r.id.slug));
        count = initialLen - races.length;
        await prefs.setStringList(_keyHomebrewRaces, races.map((r) => json.encode(r.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewRacesRaw, slug, prefs);
          SrdSpeciesLibrary.removeCustomSpecies(slug);
        }

      case EntityType.feat:
        final feats = await loadCustomFeats();
        final initialLen = feats.length;
        feats.removeWhere((f) => slugSet.contains(f.id.slug));
        count = initialLen - feats.length;
        await prefs.setStringList(_keyHomebrewFeats, feats.map((f) => json.encode(f.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewFeatsRaw, slug, prefs);
          SrdFeatsLibrary.removeCustomFeat(slug);
        }

      case EntityType.background:
        final bgs = await loadCustomBackgrounds();
        final initialLen = bgs.length;
        bgs.removeWhere((b) => slugSet.contains(b.id.slug));
        count = initialLen - bgs.length;
        await prefs.setStringList(_keyHomebrewBackgrounds, bgs.map((b) => json.encode(b.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewBackgroundsRaw, slug, prefs);
          SrdBackgroundsLibrary.removeCustomBackground(slug);
        }

      case EntityType.custom:
        final others = await loadCustomOtherEntries();
        final initialLen = others.length;
        others.removeWhere((o) => slugSet.contains(o.id.slug));
        count = initialLen - others.length;
        await prefs.setStringList(_keyHomebrewOther, others.map((o) => json.encode(o.toMap())).toList());
        for (final slug in slugSet) {
          await _deleteRawPayload(_keyHomebrewOtherRaw, slug, prefs);
        }

      default:
        break;
    }

    SrdEquivalenceIndex().invalidate();
    return count;
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
      races: includeRaces ? await loadCustomRaces() : const [],
      feats: includeFeats ? await loadCustomFeats() : const [],
      backgrounds: includeBackgrounds ? await loadCustomBackgrounds() : const [],
      otherEntries: includeOther ? await loadCustomOtherEntries() : const [],
    );
  }

  /// Imports an analyzed and resolved [ImportAnalysisResult], writing entities to storage
  /// according to user-selected collision resolutions, and syncs runtime libraries immediately.
  Future<void> importResolvedBundle(ImportAnalysisResult resolution) async {
    // 1. Spells
    final existingSpells = await loadCustomSpells();
    final spellSlugs = existingSpells.map((s) => s.id.slug).toSet();
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
      await saveCustomSpell(toSave);
    }

    // 2. Monsters
    final existingMonsters = await loadCustomMonsters();
    final monsterSlugs = existingMonsters.map((m) => m.id.slug).toSet();
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
      await saveCustomMonster(toSave);
    }

    // 3. Items
    final existingItems = await loadCustomItems();
    final itemSlugs = existingItems.map((i) => i.id.slug).toSet();
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
      await saveCustomItem(toSave);
    }

    // 4. Classes
    final existingClasses = await loadCustomClasses();
    final classSlugs = existingClasses.map((c) => c.id.slug).toSet();
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
      await saveCustomClass(toSave);
    }

    // 5. Subclasses
    final existingSubclasses = await loadCustomSubclasses();
    final subSlugs = existingSubclasses.map((s) => s.id.slug).toSet();
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
      await saveCustomSubclass(toSave);
    }

    // 6. Races
    final existingRaces = await loadCustomRaces();
    final raceSlugs = existingRaces.map((r) => r.id.slug).toSet();
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
      await saveCustomRace(toSave);
    }

    // 7. Feats
    final existingFeats = await loadCustomFeats();
    final featSlugs = existingFeats.map((f) => f.id.slug).toSet();
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
      await saveCustomFeat(toSave);
    }

    // 8. Backgrounds
    final existingBgs = await loadCustomBackgrounds();
    final bgSlugs = existingBgs.map((b) => b.id.slug).toSet();
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
      await saveCustomBackground(toSave);
    }

    // 9. Other entries
    final existingOthers = await loadCustomOtherEntries();
    final otherSlugs = existingOthers.map((o) => o.id.slug).toSet();
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
      await saveCustomOtherEntry(toSave);
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
    SrdSpeciesLibrary.setCustomSpecies([]);
    SrdFeatsLibrary.setCustomFeats([]);
    SrdClassesLibrary.setCustomClasses([]);
    SrdBackgroundsLibrary.setCustomBackgrounds([]);
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
        await prefs.remove(_keyHomebrewSpells);
        await prefs.remove(_keyHomebrewSpellsRaw);
      case EntityType.monster:
        await prefs.remove(_keyHomebrewMonsters);
        await prefs.remove(_keyHomebrewMonstersRaw);
        MonsterCodexLibrary.clearHomebrewMonsters();
      case EntityType.equipment:
        await prefs.remove(_keyHomebrewItems);
        await prefs.remove(_keyHomebrewItemsRaw);
      case EntityType.classDefinition:
        await prefs.remove(_keyHomebrewClasses);
        await prefs.remove(_keyHomebrewClassesRaw);
        SrdClassesLibrary.setCustomClasses([]);
      case EntityType.subclass:
        await prefs.remove(_keyHomebrewSubclasses);
        await prefs.remove(_keyHomebrewSubclassesRaw);
      case EntityType.species:
        await prefs.remove(_keyHomebrewRaces);
        await prefs.remove(_keyHomebrewRacesRaw);
        SrdSpeciesLibrary.setCustomSpecies([]);
      case EntityType.feat:
        await prefs.remove(_keyHomebrewFeats);
        await prefs.remove(_keyHomebrewFeatsRaw);
        SrdFeatsLibrary.setCustomFeats([]);
      case EntityType.background:
        await prefs.remove(_keyHomebrewBackgrounds);
        await prefs.remove(_keyHomebrewBackgroundsRaw);
        SrdBackgroundsLibrary.setCustomBackgrounds([]);
      case EntityType.custom:
        await prefs.remove(_keyHomebrewOther);
        await prefs.remove(_keyHomebrewOtherRaw);
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
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      if (stored == null || stored.isEmpty) return [];
      final decoded = json.decode(stored) as Map<String, dynamic>;
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

  /// Saves a single raw JSON payload keyed by [entitySlug].
  /// Uses a `Map<slug, rawJson>` stored as a single JSON string per category.
  Future<void> _saveRawPayload(
    String key,
    String entitySlug,
    Map<String, dynamic> rawPayload,
    SharedPreferences prefs,
  ) async {
    try {
      final existing = prefs.getString(key);
      final map = existing != null && existing.isNotEmpty
          ? Map<String, dynamic>.from(json.decode(existing) as Map)
          : <String, dynamic>{};
      map[entitySlug] = rawPayload;
      await prefs.setString(key, json.encode(map));
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to save raw payload for $entitySlug');
    }
  }

  /// Removes the raw payload for [entitySlug] from [key].
  Future<void> _deleteRawPayload(
    String key,
    String entitySlug,
    SharedPreferences prefs,
  ) async {
    try {
      final existing = prefs.getString(key);
      if (existing == null || existing.isEmpty) return;
      final map = Map<String, dynamic>.from(json.decode(existing) as Map);
      map.remove(entitySlug);
      await prefs.setString(key, json.encode(map));
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
      final prefs = await SharedPreferences.getInstance();
      final storedRaw = prefs.getString(rawKey);
      final rawMap = storedRaw != null && storedRaw.isNotEmpty
          ? Map<String, dynamic>.from(json.decode(storedRaw) as Map)
          : <String, dynamic>{};

      final reparsed = <T>[];
      final slugsToPrune = <String>{};

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
        await prefs.setString(rawKey, json.encode(rawMap));
      }

      // 3. Check legacy parsed store for any SRD duplicates not in rawMap
      final existingParsed = prefs.getStringList(parsedKey) ?? [];
      final allSlugsHandled = <String>{
        ...reparsed.map((e) => e.id.slug),
        ...slugsToPrune,
      };

      for (final jsonStr in existingParsed) {
        try {
          final decoded = json.decode(jsonStr) as Map<String, dynamic>;
          final idObj = decoded['id'];
          final slug = idObj is Map ? (idObj['slug']?.toString() ?? '') : (decoded['slug']?.toString() ?? '');
          final name = decoded['name']?.toString() ?? '';

          if (slug.isNotEmpty && !allSlugsHandled.contains(slug)) {
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
            final legacyEntity = fromRaw(decoded);
            reparsed.add(legacyEntity);
            allSlugsHandled.add(slug);
          }
        } catch (_) {}
      }

      await prefs.setStringList(parsedKey, reparsed.map(toJson).toList());
      return reparsed.length;
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Re-parse category $entityType failed');
      return 0;
    }
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
