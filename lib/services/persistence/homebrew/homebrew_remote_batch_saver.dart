import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';

import '../../../models/characters/srd_species_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../acl/compendium_generic_entry_parser.dart';
import '../../acl/compendium_race_parser.dart';
import '../../acl/srd_equivalence_index.dart';
import '../../fluff/entity_fluff_service.dart';
import '../../importers/community_compendium_adapters.dart';
import '../../ingestion/compendium_json_ingestion_pipeline.dart';

/// Typed callback signature for persisting a batch of custom entities with
/// optional raw source payloads.
typedef HomebrewBatchSaveFn<T> = Future<void> Function(
  List<T> entities, {
  List<Map<String, dynamic>>? rawPayloads,
});

/// Batch ingestion and storage router for canonical [HomebrewEntity] imports.
class HomebrewRemoteBatchSaver {
  HomebrewRemoteBatchSaver({
    required this.saveCustomSpellsBatch,
    required this.saveCustomMonstersBatch,
    required this.saveCustomItemsBatch,
    required this.saveCustomClassesBatch,
    required this.saveCustomSubclassesBatch,
    required this.saveCustomRacesBatch,
    required this.saveCustomSubracesBatch,
    required this.saveCustomFeatsBatch,
    required this.saveCustomBackgroundsBatch,
    required this.saveCustomOtherEntriesBatch,
    required this.saveCustomFluffBatch,
    required this.syncToLibraries,
  });

  final HomebrewBatchSaveFn<Spell> saveCustomSpellsBatch;
  final HomebrewBatchSaveFn<Monster> saveCustomMonstersBatch;
  final HomebrewBatchSaveFn<EquipmentItem> saveCustomItemsBatch;
  final HomebrewBatchSaveFn<CharacterClass> saveCustomClassesBatch;
  final HomebrewBatchSaveFn<Subclass> saveCustomSubclassesBatch;
  final HomebrewBatchSaveFn<Race> saveCustomRacesBatch;
  final HomebrewBatchSaveFn<Subrace> saveCustomSubracesBatch;
  final HomebrewBatchSaveFn<Feat> saveCustomFeatsBatch;
  final HomebrewBatchSaveFn<Background> saveCustomBackgroundsBatch;
  final HomebrewBatchSaveFn<HomebrewCompendiumEntry> saveCustomOtherEntriesBatch;
  final HomebrewBatchSaveFn<EntityFluff> saveCustomFluffBatch;
  final Future<void> Function() syncToLibraries;

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
    if (excludeSrdCanon && !srdIndex.isBuilt) srdIndex.build();

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

    final batchSubclassFeatureMap = <String, Map<String, dynamic>>{};
    final batchClassFeatureMap = <String, Map<String, dynamic>>{};

    for (final entity in entities) {
      final t = entity.entityType.toLowerCase().trim();
      final p = entity.rawPayload;
      if (t == 'subclassfeature' || t == 'subclassfeatures') {
        SrdClassesLibrary.registerSubclassFeature(p);
        final name = (p['name'] ?? entity.name).toString().toLowerCase().trim();
        final subShort = (p['subclassShortName'] ?? p['shortName'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final lvl = (p['level'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          batchSubclassFeatureMap[name] = p;
          if (subShort.isNotEmpty) {
            batchSubclassFeatureMap['$name|$subShort'] = p;
            if (lvl.isNotEmpty) {
              batchSubclassFeatureMap['$name|$subShort|$lvl'] = p;
            }
          }
          if (lvl.isNotEmpty) {
            batchSubclassFeatureMap['$name|$lvl'] = p;
          }
        }
      } else if (t == 'classfeature' || t == 'classfeatures') {
        final name = (p['name'] ?? entity.name).toString().toLowerCase().trim();
        final cls = (p['className'] ?? p['class'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        final lvl = (p['level'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          batchClassFeatureMap[name] = p;
          if (cls.isNotEmpty) {
            batchClassFeatureMap['$name|$cls'] = p;
            if (lvl.isNotEmpty) {
              batchClassFeatureMap['$name|$cls|$lvl'] = p;
            }
          }
        }
      }
    }

    for (final entity in entities) {
      final payload = Map<String, dynamic>.from(entity.rawPayload);
      final typeLower = entity.entityType.toLowerCase().trim();

      final isFluff = typeLower.endsWith('fluff') ||
          typeLower == 'fluff' ||
          ((typeLower == 'custom' || typeLower == 'generic') &&
              (payload.containsKey('_fluff') ||
                  payload.containsKey('flufftype')));

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

      final primaryType = typeLower.split(RegExp(r'[\s(,]')).first.trim();
      final hasMonsterAttributes = payload.containsKey('cr') ||
          payload.containsKey('challengeRating') ||
          payload.containsKey('hitDice') ||
          payload.containsKey('ac') ||
          payload.containsKey('hp') ||
          payload.containsKey('actions') ||
          payload.containsKey('action') ||
          payload.containsKey('isNpc') ||
          payload.containsKey('isNamedCreature') ||
          payload.containsKey('legendary') ||
          payload.containsKey('reactions') ||
          (payload.containsKey('_copy') &&
              (typeLower.contains('monster') ||
                  typeLower.contains('creature') ||
                  typeLower.contains('bestiary') ||
                  typeLower == 'race'));

      final isMonster = creatureTypes.contains(primaryType) ||
          creatureTypes.contains(typeLower) ||
          typeLower.startsWith('{type:') ||
          hasMonsterAttributes;

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
          monsters
              .add(adapters.parseMonster(payload, forceRuleset: entity.ruleset));
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
              spells
                  .add(adapters.parseSpell(payload, forceRuleset: entity.ruleset));
              spellPayloads.add(payload);
            case 'equipment' ||
                  'item' ||
                  'magicitem' ||
                  'weapon' ||
                  'armor' ||
                  'baseitem' ||
                  'magicvariant':
              if (excludeSrdCanon &&
                  srdIndex.checkEntity(
                        slug: entity.id,
                        name: entity.name,
                        type: EntityType.equipment,
                      ) !=
                      SrdMatchResult.notSrd) {
                break;
              }
              items.add(adapters.parseItem(payload, forceRuleset: entity.ruleset));
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
              classes.add(adapters.parseClass(
                payload,
                forceRuleset: entity.ruleset,
                classFeatureMap: batchClassFeatureMap.isNotEmpty
                    ? batchClassFeatureMap
                    : null,
                subclassFeatureMap: batchSubclassFeatureMap.isNotEmpty
                    ? batchSubclassFeatureMap
                    : null,
              ));
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
              subclasses.add(adapters.parseSubclass(
                payload,
                forceRuleset: entity.ruleset,
                subclassFeatureMap: batchSubclassFeatureMap.isNotEmpty
                    ? batchSubclassFeatureMap
                    : null,
              ));
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
              races.add(adapters.parseRace(payload, forceRuleset: entity.ruleset));
              racePayloads.add(payload);
            case 'subrace':
              final sub =
                  raceParser.parseSubrace(payload, forceRuleset: entity.ruleset);
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
                final match =
                    races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
                if (match != null) {
                  final idx = races.indexOf(match);
                  races[idx] =
                      match.copyWith(subraces: [...match.subraces, sub]);
                  if (idx < racePayloads.length) {
                    final existingSubs = List<dynamic>.from(
                        racePayloads[idx]['subraces'] as List? ?? []);
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
                  final parentName = (payload['raceName'] as String?) ??
                      sub.raceSlug.replaceAll('-', ' ');
                  races.add(Race(
                    id: EntityId(slug: sub.raceSlug, ruleset: entity.ruleset),
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
              feats.add(adapters.parseFeat(payload, forceRuleset: entity.ruleset));
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
              backgrounds.add(
                  adapters.parseBackground(payload, forceRuleset: entity.ruleset));
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
                forceRuleset: entity.ruleset,
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
          forceRuleset: entity.ruleset,
        );
        others.add(entry);
        otherPayloads.add(payload);
      }
    }

    if (spells.isNotEmpty) {
      await saveCustomSpellsBatch(spells, rawPayloads: spellPayloads);
    }
    if (monsters.isNotEmpty) {
      await saveCustomMonstersBatch(monsters, rawPayloads: monsterPayloads);
    }
    if (items.isNotEmpty) {
      await saveCustomItemsBatch(items, rawPayloads: itemPayloads);
    }
    if (classes.isNotEmpty) {
      await saveCustomClassesBatch(classes, rawPayloads: classPayloads);
    }
    if (subclasses.isNotEmpty) {
      await saveCustomSubclassesBatch(subclasses,
          rawPayloads: subclassPayloads);
    }
    if (races.isNotEmpty) {
      await saveCustomRacesBatch(races, rawPayloads: racePayloads);
    }
    if (subraces.isNotEmpty) {
      await saveCustomSubracesBatch(subraces, rawPayloads: subracePayloads);
    }
    if (feats.isNotEmpty) {
      await saveCustomFeatsBatch(feats, rawPayloads: featPayloads);
    }
    if (backgrounds.isNotEmpty) {
      await saveCustomBackgroundsBatch(backgrounds,
          rawPayloads: backgroundPayloads);
    }
    if (others.isNotEmpty) {
      await saveCustomOtherEntriesBatch(others, rawPayloads: otherPayloads);
    }
    if (fluffToSave.isNotEmpty) {
      await saveCustomFluffBatch(fluffToSave, rawPayloads: fluffPayloads);
    }

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
