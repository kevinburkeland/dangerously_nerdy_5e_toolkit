import 'package:vtt_engine_core/simulation/combat_rider.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
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
  dynamic findFeat(String slug) => SrdFeatsLibrary.findBySlug(slug);

  @override
  dynamic findMagicItem(String idOrName) {
    return MagicItemLibrary.findById(idOrName) ??
        MagicItemLibrary.findById('item_$idOrName') ??
        MagicItemLibrary.findByName(idOrName);
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

  @override
  Map<String, bool> extractSpellDescriptors(dynamic addSpellsData) {
    return CompendiumPipeParser.extractSpellDescriptors(addSpellsData);
  }

  @override
  Set<String> extractSpellNames(dynamic addSpellsData) {
    return CompendiumPipeParser.extractSpellNames(addSpellsData);
  }

  @override
  List<FeatureGrant> extractBonusSpells(
    dynamic addSpellsData,
    String ownerPrefix,
    String ownerSlug,
  ) {
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
