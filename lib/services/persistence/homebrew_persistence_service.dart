import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/monster_codex_data.dart';
import '../logging_service.dart';
import '../repository/layered_priority_repository.dart';

/// Service managing persistent storage and repository hydration for user-created homebrew and campaign overrides.
class HomebrewPersistenceService {
  static const String _keyHomebrewSpells = 'dn_homebrew_spells_v1';
  static const String _keyHomebrewMonsters = 'dn_homebrew_monsters_v1';
  static const String _keyHomebrewItems = 'dn_homebrew_items_v1';
  static const String _keyCampaignOverrides = 'dn_campaign_overrides_v1';

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

  /// Saves a custom spell to persistent storage.
  Future<void> saveCustomSpell(Spell spell) async {
    final spells = await loadCustomSpells();
    final idx = spells.indexWhere((s) => s.id.slug == spell.id.slug);
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

  /// Synchronizes all loaded homebrew monsters into the global MonsterCodexLibrary.
  Future<void> syncToLibraries() async {
    final monsters = await loadCustomMonsters();
    MonsterCodexLibrary.setHomebrewMonsters(monsters);
  }

  /// Saves a custom monster to persistent storage and updates MonsterCodexLibrary.
  Future<void> saveCustomMonster(Monster monster) async {
    final monsters = await loadCustomMonsters();
    final idx = monsters.indexWhere((m) => m.id.slug == monster.id.slug);
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
    MonsterCodexLibrary.addHomebrewMonster(monster);
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
  Future<void> saveCustomItem(EquipmentItem item) async {
    final items = await loadCustomItems();
    final idx = items.indexWhere((i) => i.id.slug == item.id.slug);
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
  }

  /// Clears all saved homebrew and override data.
  Future<void> clearAllHomebrew() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHomebrewSpells);
    await prefs.remove(_keyHomebrewMonsters);
    await prefs.remove(_keyHomebrewItems);
    await prefs.remove(_keyCampaignOverrides);
    MonsterCodexLibrary.clearHomebrewMonsters();
  }
}
