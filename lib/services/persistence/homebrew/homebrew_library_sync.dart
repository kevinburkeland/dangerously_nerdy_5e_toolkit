import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/domain/homebrew_other_category.dart';
import '../../../models/magic_items/magic_item_library.dart';
import '../../../models/monster_codex_data.dart';
import '../../../models/spellbook_data.dart';
import '../../../models/tables/srd_tables_library.dart';
import '../../acl/compendium_spell_parser.dart';
import '../../fluff/entity_fluff_service.dart';
import '../../repository/layered_priority_repository.dart';
import 'homebrew_compendium_mappers.dart';

/// Synchronizes persisted homebrew collections into runtime libraries,
/// compendium registries, and [LayeredPriorityRepository] instances.
class HomebrewLibrarySync {
  HomebrewLibrarySync({
    required this.loadCustomSpells,
    required this.loadCustomMonsters,
    required this.loadCustomItems,
    required this.loadCustomRaces,
    required this.loadCustomSubraces,
    required this.loadCustomFeats,
    required this.loadCustomClasses,
    required this.loadCustomSubclasses,
    required this.loadCustomBackgrounds,
    required this.loadCustomOtherEntries,
    required this.loadCustomFluff,
  });

  final Future<List<Spell>> Function() loadCustomSpells;
  final Future<List<Monster>> Function() loadCustomMonsters;
  final Future<List<EquipmentItem>> Function() loadCustomItems;
  final Future<List<Race>> Function() loadCustomRaces;
  final Future<List<Subrace>> Function() loadCustomSubraces;
  final Future<List<Feat>> Function() loadCustomFeats;
  final Future<List<CharacterClass>> Function() loadCustomClasses;
  final Future<List<Subclass>> Function() loadCustomSubclasses;
  final Future<List<Background>> Function() loadCustomBackgrounds;
  final Future<List<HomebrewCompendiumEntry>> Function() loadCustomOtherEntries;
  final Future<List<EntityFluff>> Function() loadCustomFluff;

  /// Enriches homebrew spells that have no class list with SRD class
  /// assignments by name/slug before registering them in [SpellbookLibrary].
  /// Stored records are never mutated by this view-time enrichment.
  static List<Spell> enrichSpellsWithSrdClasses(List<Spell> spells) {
    final parser = CompendiumSpellParser();
    return spells.map((s) {
      if (s.rules2014.classes.isNotEmpty || s.rules2024.classes.isNotEmpty) {
        return s;
      }
      final fallbackNames =
          parser.extractClassesForSpell(s.id.slug, s.name, s.id.ruleset);
      if (fallbackNames.isEmpty) return s;
      final resolved = <SpellClass>[];
      for (final fn in fallbackNames) {
        final match = SpellClass.values
            .where((sc) =>
                sc.name.toLowerCase() == fn.toLowerCase() ||
                sc.label.toLowerCase() == fn.toLowerCase())
            .firstOrNull;
        if (match != null && !resolved.contains(match)) {
          resolved.add(match);
        }
      }
      if (resolved.isEmpty) return s;
      SpellEditionDetails withClasses(SpellEditionDetails d) =>
          SpellEditionDetails(
            schoolOverride: d.schoolOverride,
            castingTime: d.castingTime,
            range: d.range,
            components: d.components,
            materialDetails: d.materialDetails,
            duration: d.duration,
            concentration: d.concentration,
            ritual: d.ritual,
            description: d.description,
            higherLevels: d.higherLevels,
            classes: resolved,
            rollFormula: d.rollFormula,
            scalingFormula: d.scalingFormula,
            damageOrHealType: d.damageOrHealType,
            savingThrow: d.savingThrow,
            reactionTrigger: d.reactionTrigger,
          );
      return s.copyWith(
        rules2014: withClasses(s.rules2014),
        rules2024: withClasses(s.rules2024),
      );
    }).toList();
  }

  /// Synchronizes all loaded homebrew entities into global runtime libraries.
  Future<void> syncToLibraries() async {
    final spells = enrichSpellsWithSrdClasses(await loadCustomSpells());
    SpellbookLibrary.setHomebrewSpells(spells);

    final monsters = await loadCustomMonsters();
    MonsterCodexLibrary.setHomebrewMonsters(monsters);

    final items = await loadCustomItems();
    MagicItemLibrary.setHomebrewItems(items);

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
        final rawAbility =
            f.customProperties['ability'] ?? f.customProperties['abilities'];
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
        final addSpells = c.customProperties['additionalSpells'] ??
            c.customProperties['spells'];
        if (addSpells != null) {
          final grants =
              FeatureGrant.extractBonusSpells(addSpells, 'class', c.id.slug);
          if (grants.isNotEmpty) return c.copyWith(grants: grants);
        }
      }
      return c;
    }).toList();
    SrdClassesLibrary.setCustomClasses(revitalizedClasses);

    final subclasses = await loadCustomSubclasses();
    final revitalizedSubclasses = subclasses.map((s) {
      if (s.grants.isEmpty) {
        final addSpells = s.customProperties['additionalSpells'] ??
            s.customProperties['subclassSpells'];
        if (addSpells != null) {
          final grants =
              FeatureGrant.extractBonusSpells(addSpells, 'subclass', s.id.slug);
          if (grants.isNotEmpty) return s.copyWith(grants: grants);
        }
      }
      return s;
    }).toList();
    SrdClassesLibrary.setCustomSubclasses(revitalizedSubclasses);

    final backgrounds = await loadCustomBackgrounds();
    SrdBackgroundsLibrary.setCustomBackgrounds(backgrounds);

    final others = await loadCustomOtherEntries();
    hydrateCustomOtherSubsystems(others);

    final updatedSubs = SrdClassesLibrary.customSubclasses.map((s) {
      if (s.featuresMarkdown.isEmpty ||
          s.featuresMarkdown.contains('Granted at level')) {
        final stitched = SrdClassesLibrary.buildFeaturesMarkdownForSubclass(s);
        if (stitched.isNotEmpty) {
          return s.copyWith(featuresMarkdown: stitched);
        }
      }
      return s;
    }).toList();
    SrdClassesLibrary.setCustomSubclasses(updatedSubs);

    final customFluff = await loadCustomFluff();
    if (customFluff.isNotEmpty) {
      EntityFluffService().batchRegisterFluff(customFluff);
    }
  }

  /// Hydrates active homebrew "other" compendium entries into runtime feature
  /// option libraries, rollable tables, DM screen registries, and subclass features.
  ///
  /// Only entries with [isEnabled] == true are registered into the active runtime toolkit.
  static void hydrateCustomOtherSubsystems(
      List<HomebrewCompendiumEntry> others) {
    final activeOthers = others.where((e) => e.isEnabled).toList();

    final customPactBoons = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final name = e.name.toLowerCase();
          return cat.contains('pact boon') ||
              cat.contains('pb') ||
              name.startsWith('pact of the');
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
          final isPactBoon = cat.contains('pact boon') ||
              cat.contains('pb') ||
              e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          return cat.contains('invocation') ||
              cat == 'ei' ||
              cat.startsWith('ei:') ||
              e.customProperties['featureType']?.toString().toUpperCase() ==
                  'EI';
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
          final isPactBoon = cat.contains('pact boon') ||
              cat.contains('pb') ||
              e.name.toLowerCase().startsWith('pact of the');
          if (isPactBoon) return false;
          final isInvocation = cat.contains('invocation') ||
              cat.contains('ei') ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('EI') ==
                  true;
          if (isInvocation) return false;
          return cat.contains('infusion') ||
              cat.contains('ai') ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('AI') ==
                  true ||
              e.customProperties['featureType']
                      ?.toString()
                      .toUpperCase()
                      .contains('INF') ==
                  true;
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
        .map(HomebrewCompendiumMappers.compendiumEntryToRollableTable)
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
              classified == HomebrewOtherCategory.rulesAndReference ||
              classified == HomebrewOtherCategory.tables ||
              classified == HomebrewOtherCategory.dataTables;
        })
        .map(HomebrewCompendiumMappers.compendiumEntryToDmReferenceItem)
        .toList();
    DmScreenLibrary.setCustomItems(customRefItems);

    final customSubclassFeatures = activeOthers
        .where((e) {
          final cat = e.category.toLowerCase();
          final type = (e.customProperties['entityType'] ??
                  e.customProperties['type'] ??
                  '')
              .toString()
              .toLowerCase();
          return cat.contains('subclassfeature') ||
              cat == 'subclass feature' ||
              type.contains('subclassfeature') ||
              e.customProperties.containsKey('subclassShortName') ||
              e.customProperties.containsKey('subclass');
        })
        .map((e) => {
              'name': e.name,
              'subclassShortName': e.customProperties['subclassShortName'] ??
                  e.customProperties['subclass'] ??
                  e.customProperties['shortName'],
              'className': e.customProperties['className'] ??
                  e.customProperties['class'],
              'level': e.customProperties['level'],
              'classSource': e.customProperties['classSource'],
              'subclassSource': e.customProperties['subclassSource'],
              'entries':
                  e.customProperties['entries'] ?? [e.descriptionMarkdown],
              'descriptionMarkdown': e.descriptionMarkdown,
              ...e.customProperties,
            })
        .toList();

    if (customSubclassFeatures.isNotEmpty) {
      SrdClassesLibrary.registerSubclassFeatures(customSubclassFeatures);
    } else if (others.isEmpty) {
      SrdClassesLibrary.clearCustomSubclassFeatures();
    }
  }

  /// Hydrates a [LayeredPriorityRepository] with saved Homebrew and Campaign Overrides.
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
}
