import 'package:vtt_engine_core/simulation/combat_rider.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_equipment_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/subclass_spells_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/stat_block_acl_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_pipe_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/animated_object.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd_5e_animated_object_adapter.dart';

/// Concrete production implementation of [Dnd5eCatalog] delegating ruleset
/// queries and AST extractions to the application compendiums and parsers.
class AppDnd5eCatalog implements Dnd5eCatalog {
  const AppDnd5eCatalog();

  @override
  CharacterClass? findClass(String slug) => SrdClassesLibrary.findBySlug(slug);

  @override
  CatalogFeat? findFeat(String slug) {
    final feat = SrdFeatsLibrary.findBySlug(slug);
    if (feat == null) return null;
    return CatalogFeat(grants: feat.grants);
  }

  @override
  CatalogMagicItem? findMagicItem(String idOrName) {
    final normalizedId =
        SrdEquipmentLibrary.normalizeLegacyBundledItemId(idOrName);
    final item = MagicItemLibrary.findById(normalizedId) ??
        MagicItemLibrary.findById('item_$normalizedId') ??
        MagicItemLibrary.findByName(idOrName);
    if (item == null) return null;
    return CatalogMagicItem(
      categoryName: item.category.name,
      tags: item.tags,
      summary2024: item.rules2024.summary,
      summary2014: item.rules2014.summary,
    );
  }

  @override
  MonsterStatBlock? findMonsterStatBlockByName(String name) {
    return MonsterCodexLibrary.getMonsterByName(name)?.sourceStatBlock;
  }

  @override
  List<String> getAlwaysPreparedSpells({
    required String classSlug,
    String? subclassSlug,
    required int classLevel,
    required RulesetEdition edition,
  }) {
    return SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: classSlug,
      subclassSlug: subclassSlug,
      classLevel: classLevel,
      edition: edition == RulesetEdition.v2024
          ? DmRulesEdition.dnd2024
          : DmRulesEdition.dnd2014,
    ).map((s) => s.name).toList();
  }

  @override
  int? getSpellLevel(String slug) {
    return SpellbookLibrary.getSpellById(slug)?.level;
  }

  @override
  List<CombatEffectRider> extractRiders(String markdown) {
    return StatBlockAclParser.extractRiders(markdown);
  }

  static void _validateAddSpellsDataShape(Object? addSpellsData) {
    if (addSpellsData == null ||
        addSpellsData is String ||
        addSpellsData is List ||
        addSpellsData is Map) {
      return;
    }
    throw ArgumentError.value(
      addSpellsData,
      'addSpellsData',
      'Unsupported spell data shape: ${addSpellsData.runtimeType} '
          '(expected null, String, List, or Map)',
    );
  }

  @override
  Map<String, bool> extractSpellDescriptors(Object? addSpellsData) {
    _validateAddSpellsDataShape(addSpellsData);
    return CompendiumPipeParser.extractSpellDescriptors(addSpellsData);
  }

  @override
  Set<String> extractSpellNames(Object? addSpellsData) {
    _validateAddSpellsDataShape(addSpellsData);
    return CompendiumPipeParser.extractSpellNames(addSpellsData);
  }

  @override
  List<FeatureGrant> extractBonusSpells(
    Object? addSpellsData,
    String ownerPrefix,
    String ownerSlug,
  ) {
    _validateAddSpellsDataShape(addSpellsData);
    return CompendiumPipeParser.extractBonusSpells(
      addSpellsData,
      ownerPrefix,
      ownerSlug,
    );
  }
}

/// Installs the production ruleset catalog and shared engine adapters.
void installRulesetCatalog() {
  Dnd5eRuleset.install(const AppDnd5eCatalog());
  AnimatedObjectStats.defaultProvider = Dnd5eAnimatedObjectAdapter.getStats;
}
