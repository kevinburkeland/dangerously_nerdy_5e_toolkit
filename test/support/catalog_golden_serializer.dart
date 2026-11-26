import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';

dynamic _jsonSafe(dynamic v) {
  if (v is Enum) return v.name;
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): _jsonSafe(e.value)};
  }
  if (v is List) return v.map(_jsonSafe).toList();
  return v;
}

Map<String, dynamic> serializeSpellEditionDetails(SpellEditionDetails d) => {
      'castingTime': d.castingTime,
      'range': d.range,
      'components': d.components,
      'duration': d.duration,
      'concentration': d.concentration,
      'ritual': d.ritual,
      'description': d.description,
      'higherLevels': d.higherLevels,
      'classes': d.classes.map((c) => c.name).toList(),
      'rollFormula': d.rollFormula,
      'damageOrHealType': d.damageOrHealType,
      'savingThrow': d.savingThrow,
      'schoolOverride': d.schoolOverride?.name,
      'reactionTrigger': d.reactionTrigger,
    };

Map<String, dynamic> serializeSpellForCatalogGolden(SpellItem s) {
  final r14 = s.getRules(DmRulesEdition.v2014);
  final r24 = s.getRules(DmRulesEdition.v2024);
  final nameQ = s.name.split(' ').first;
  return {
    'id': s.id,
    'name': s.name,
    'name2014': s.name2014,
    'name2024': s.name2024,
    'level': s.level,
    'school': s.school.name,
    'levelLabel': s.levelLabel,
    'fullTypeLabel': s.fullTypeLabel,
    'isChangedIn2024': s.isChangedIn2024,
    'diffSummary': s.diffSummary,
    'diffHighlights': s.diffHighlights,
    'tags': s.tags,
    'v2014': {
      'editionName': s.getName(DmRulesEdition.v2014),
      'effectiveSchool': s.getSchool(DmRulesEdition.v2014).name,
      'fullTypeLabel': s.getFullTypeLabel(DmRulesEdition.v2014),
      'glyphActionRings':
          s.getGlyphActionRings(DmRulesEdition.v2014).map((r) => r.toString()).toList(),
      'matchesName': s.matches(nameQ, edition: DmRulesEdition.v2014),
      'matchesSchool': s.matches(
        s.getSchool(DmRulesEdition.v2014).label,
        edition: DmRulesEdition.v2014,
      ),
      'rules': serializeSpellEditionDetails(r14),
    },
    'v2024': {
      'editionName': s.getName(DmRulesEdition.v2024),
      'effectiveSchool': s.getSchool(DmRulesEdition.v2024).name,
      'fullTypeLabel': s.getFullTypeLabel(DmRulesEdition.v2024),
      'glyphActionRings':
          s.getGlyphActionRings(DmRulesEdition.v2024).map((r) => r.toString()).toList(),
      'matchesName': s.matches(nameQ, edition: DmRulesEdition.v2024),
      'matchesSchool': s.matches(
        s.getSchool(DmRulesEdition.v2024).label,
        edition: DmRulesEdition.v2024,
      ),
      'rules': serializeSpellEditionDetails(r24),
    },
  };
}

Map<String, dynamic> serializeItemEditionDetails(ItemEditionDetails d) => {
      'summary': d.summary,
      'description': d.description,
      'activation': d.activation,
      'charges': d.charges,
      'masteryProperties': d.masteryProperties,
      'savingThrowDc': d.savingThrowDc,
      'properties': d.properties,
    };

Map<String, dynamic> serializeItemForCatalogGolden(EquipmentItem item) {
  final nameQ = item.name.split(' ').first;
  return {
    'id': item.id.slug,
    'name': item.name,
    'name2014': item.name2014,
    'name2024': item.name2024,
    'category': item.category.name,
    'rarity': item.rarityTier.name,
    'cost': item.cost,
    'cost2014': item.cost2014,
    'cost2024': item.cost2024,
    'requiresAttunement': item.requiresAttunement,
    'attunementRequirement': item.attunementRequirement,
    'isConsumable': item.isConsumable,
    'isChangedIn2024': item.isChangedIn2024,
    'diffSummary': item.diffSummary,
    'diffHighlights': item.diffHighlights,
    'tags': item.tags,
    'glyphArgb': item.glyphArgb?.value,
    'effectiveGlyphArgb': item.effectiveGlyphArgb?.value,
    'damageAccent': item.damageAccent?.name,
    'actionRings': item.actionRings.map((r) => r.toString()).toList(),
    'v2014': {
      'editionName': item.getName(DmRulesEdition.v2014),
      'matchesName': item.matches(nameQ, edition: DmRulesEdition.v2014),
      'rules': serializeItemEditionDetails(item.getRules(DmRulesEdition.v2014)),
    },
    'v2024': {
      'editionName': item.getName(DmRulesEdition.v2024),
      'matchesName': item.matches(nameQ, edition: DmRulesEdition.v2024),
      'rules': serializeItemEditionDetails(item.getRules(DmRulesEdition.v2024)),
    },
  };
}

Map<String, dynamic> buildSpellCatalogGoldenMap() {
  SpellbookLibrary.setHomebrewSpells(const []);
  final entries = <String, dynamic>{};
  for (final s in SpellbookLibrary.srdSpells) {
    entries[s.id] = serializeSpellForCatalogGolden(s);
  }
  return {
    'count': entries.length,
    'spells': entries,
  };
}

Map<String, dynamic> buildItemCatalogGoldenMap() {
  MagicItemLibrary.setHomebrewItems(const []);
  final entries = <String, dynamic>{};
  for (final item in MagicItemLibrary.baseItems) {
    entries[item.id.slug] = serializeItemForCatalogGolden(item);
  }
  return {
    'count': entries.length,
    'items': entries,
  };
}

Map<String, dynamic> buildCatalogLookupsGoldenMap() {
  SpellbookLibrary.setHomebrewSpells(const []);
  MagicItemLibrary.setHomebrewItems(const []);

  final spellById = <String, String?>{};
  final spellByName = <String, String?>{};
  for (final s in SpellbookLibrary.srdSpells) {
    spellById[s.id] = SpellbookLibrary.getSpellById(s.id)?.id;
    spellByName[s.name] = SpellbookLibrary.getSpellByName(s.name)?.id;
  }

  final spellsByLevel = <String, List<String>>{};
  for (var lvl = 0; lvl <= 9; lvl++) {
    spellsByLevel['$lvl'] =
        SpellbookLibrary.getSpellsByLevel(lvl).map((s) => s.id).toList();
  }

  final spellsByClass2014 = <String, List<String>>{};
  final spellsByClass2024 = <String, List<String>>{};
  for (final cls in SpellClass.values) {
    spellsByClass2014[cls.name] = SpellbookLibrary.getSpellsByClass(
      cls,
      edition: DmRulesEdition.v2014,
    ).map((s) => s.id).toList();
    spellsByClass2024[cls.name] = SpellbookLibrary.getSpellsByClass(
      cls,
      edition: DmRulesEdition.v2024,
    ).map((s) => s.id).toList();
  }

  final itemById = <String, String?>{};
  final itemByName = <String, String?>{};
  for (final item in MagicItemLibrary.baseItems) {
    itemById[item.id.slug] = MagicItemLibrary.findById(item.id.slug)?.id.slug;
    itemByName[item.name] = MagicItemLibrary.findByName(item.name)?.id.slug;
  }

  final itemsByCategory = <String, List<String>>{};
  for (final cat in ItemCategory.values) {
    itemsByCategory[cat.name] =
        MagicItemLibrary.getByCategory(cat).map((i) => i.id.slug).toList();
  }

  final itemsByRarity = <String, List<String>>{};
  for (final rar in ItemRarity.values) {
    itemsByRarity[rar.name] =
        MagicItemLibrary.getByRarity(rar).map((i) => i.id.slug).toList();
  }

  return {
    'spellbook': {
      'changedIds':
          SpellbookLibrary.getChangedSpells().map((s) => s.id).toList(),
      'byIdCount': spellById.length,
      'byIdMismatches': spellById.entries
          .where((e) => e.value != e.key)
          .map((e) => '${e.key}->${e.value}')
          .toList(),
      'byName': spellByName,
      'byLevel': spellsByLevel,
      'byClass2014': spellsByClass2014,
      'byClass2024': spellsByClass2024,
    },
    'magicItems': {
      'diffIds': MagicItemLibrary.diffItems.map((i) => i.id.slug).toList(),
      'byIdCount': itemById.length,
      'byIdMismatches': itemById.entries
          .where((e) => e.value != e.key)
          .map((e) => '${e.key}->${e.value}')
          .toList(),
      'byName': itemByName,
      'byCategory': itemsByCategory,
      'byRarity': itemsByRarity,
    },
  };
}

Map<String, dynamic> buildItemRulesViewGoldenMap() {
  MagicItemLibrary.setHomebrewItems(const []);
  final entries = <String, dynamic>{};
  for (final eq in SrdEquipmentLibrary.allEquipmentItems) {
    final full = eq.toMap();
    entries[eq.id.slug] = _jsonSafe({
      'id': full['id'],
      'name': full['name'],
      'itemType': full['itemType'],
      'rarity': full['rarity'],
      'requiresAttunement': full['requiresAttunement'],
      'descriptionMarkdown': full['descriptionMarkdown'],
      'grants': full['grants'],
      'customProperties': full['customProperties'],
    });
  }
  return {
    'count': entries.length,
    'items': entries,
  };
}
