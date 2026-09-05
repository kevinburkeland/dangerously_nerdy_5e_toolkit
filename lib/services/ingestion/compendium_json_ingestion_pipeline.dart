import 'dart:convert';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_bundle.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../acl/compendium_background_parser.dart';
import '../acl/compendium_class_parser.dart';
import '../acl/compendium_feat_parser.dart';
import '../acl/compendium_generic_entry_parser.dart';
import '../acl/compendium_item_parser.dart';
import '../acl/compendium_monster_parser.dart';
import '../acl/compendium_race_parser.dart';
import '../acl/compendium_spell_parser.dart';
import '../acl/entry_tag_transformer.dart';
import '../fluff/entity_fluff_service.dart';

/// Diagnostic summary of a JSON compendium ingestion operation.
class IngestionBatchResult {
  final List<Spell> spells;
  final List<Monster> monsters;
  final List<EquipmentItem> items;
  final List<CharacterClass> classes;
  final List<Subclass> subclasses;
  final List<Race> races;
  final List<Feat> feats;
  final List<Background> backgrounds;
  final List<HomebrewCompendiumEntry> otherEntries;
  final int attachedFluffCount;
  final List<String> errors;

  const IngestionBatchResult({
    this.spells = const [],
    this.monsters = const [],
    this.items = const [],
    this.classes = const [],
    this.subclasses = const [],
    this.races = const [],
    this.feats = const [],
    this.backgrounds = const [],
    this.otherEntries = const [],
    this.attachedFluffCount = 0,
    this.errors = const [],
  });

  int get totalEntities =>
      spells.length +
      monsters.length +
      items.length +
      classes.length +
      subclasses.length +
      races.length +
      feats.length +
      backgrounds.length +
      otherEntries.length +
      attachedFluffCount;

  bool get hasErrors => errors.isNotEmpty;

  /// Converts this ingestion result into a portable [HomebrewBundle].
  HomebrewBundle toBundle({
    String? bundleName,
    String? author,
    String? description,
  }) {
    return HomebrewBundle(
      appVersion: '1.0.0',
      exportedAt: DateTime.now(),
      bundleName: bundleName,
      author: author,
      description: description,
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
    );
  }
}

/// Generic, legally compliant ingestion pipeline for standard tabletop compendium JSON datasets
/// and portable HomebrewBundle schemas.
class CompendiumJsonIngestionPipeline {
  final EntryTagTransformer transformer;
  final CompendiumSpellParser spellParser;
  final CompendiumMonsterParser monsterParser;
  final CompendiumItemParser itemParser;
  final CompendiumClassParser classParser;
  final CompendiumRaceParser raceParser;
  final CompendiumFeatParser featParser;
  final CompendiumBackgroundParser backgroundParser;
  final CompendiumGenericEntryParser genericParser;

  CompendiumJsonIngestionPipeline({
    EntryTagTransformer? transformer,
    CompendiumSpellParser? spellParser,
    CompendiumMonsterParser? monsterParser,
    CompendiumItemParser? itemParser,
    CompendiumClassParser? classParser,
    CompendiumRaceParser? raceParser,
    CompendiumFeatParser? featParser,
    CompendiumBackgroundParser? backgroundParser,
    CompendiumGenericEntryParser? genericParser,
  })  : transformer = transformer ?? EntryTagTransformer(),
        spellParser = spellParser ??
            CompendiumSpellParser(transformer: transformer ?? EntryTagTransformer()),
        monsterParser = monsterParser ??
            CompendiumMonsterParser(transformer: transformer ?? EntryTagTransformer()),
        itemParser = itemParser ??
            CompendiumItemParser(transformer: transformer ?? EntryTagTransformer()),
        classParser = classParser ??
            CompendiumClassParser(transformer: transformer ?? EntryTagTransformer()),
        raceParser = raceParser ??
            CompendiumRaceParser(transformer: transformer ?? EntryTagTransformer()),
        featParser = featParser ??
            CompendiumFeatParser(transformer: transformer ?? EntryTagTransformer()),
        backgroundParser = backgroundParser ??
            CompendiumBackgroundParser(transformer: transformer ?? EntryTagTransformer()),
        genericParser = genericParser ??
            CompendiumGenericEntryParser(transformer: transformer ?? EntryTagTransformer());

  /// Parses an in-memory Map containing single entity maps, multi-entity bundles, or [HomebrewBundle] envelopes.
  IngestionBatchResult ingestJsonMap(Map<String, dynamic> map, {RulesetVersion? forceRuleset}) {
    return _ingestMap(map, forceRuleset: forceRuleset);
  }

  /// Parses arbitrary JSON text containing single entity maps, multi-entity bundles, or [HomebrewBundle] envelopes.
  IngestionBatchResult ingestJsonString(String jsonString, {RulesetVersion? forceRuleset}) {
    try {
      final clean = jsonString.trim();
      final decoded = json.decode(clean);

      if (decoded is List) {
        return _ingestList(decoded, forceRuleset: forceRuleset);
      } else if (decoded is Map<String, dynamic>) {
        return _ingestMap(decoded, forceRuleset: forceRuleset);
      } else if (decoded is Map) {
        return _ingestMap(Map<String, dynamic>.from(decoded), forceRuleset: forceRuleset);
      } else {
        return const IngestionBatchResult(
          errors: ['Invalid JSON format: expected Map or List at root.'],
        );
      }
    } catch (e) {
      return IngestionBatchResult(
        errors: ['Failed to parse JSON: $e'],
      );
    }
  }

  IngestionBatchResult _ingestList(List<dynamic> list, {RulesetVersion? forceRuleset}) {
    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final otherEntries = <HomebrewCompendiumEntry>[];
    final errors = <String>[];

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map) {
        final subResult = _ingestSingleEntityMap(
          Map<String, dynamic>.from(item),
          forceRuleset: forceRuleset,
        );
        spells.addAll(subResult.spells);
        monsters.addAll(subResult.monsters);
        items.addAll(subResult.items);
        classes.addAll(subResult.classes);
        subclasses.addAll(subResult.subclasses);
        races.addAll(subResult.races);
        feats.addAll(subResult.feats);
        backgrounds.addAll(subResult.backgrounds);
        otherEntries.addAll(subResult.otherEntries);
        errors.addAll(subResult.errors.map((e) => 'Item #$i: $e'));
      }
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestMap(Map<String, dynamic> map, {RulesetVersion? forceRuleset}) {
    final lowerKeys = map.keys.map((k) => k.toLowerCase()).toSet();

    // 1. Check if it's a native HomebrewBundle envelope
    if (lowerKeys.contains('schemaversion') &&
        (lowerKeys.contains('spells') ||
            lowerKeys.contains('monsters') ||
            lowerKeys.contains('items') ||
            lowerKeys.contains('classes') ||
            lowerKeys.contains('races') ||
            lowerKeys.contains('feats') ||
            lowerKeys.contains('backgrounds'))) {
      try {
        final bundle = HomebrewBundle.fromMap(map);

        final baseMonsterLookup = <String, Map<String, dynamic>>{};
        for (final m in bundle.monsters) {
          if (!m.customProperties.containsKey('_copy')) {
            final traits = <Map<String, dynamic>>[];
            final actions = <Map<String, dynamic>>[];
            final bonusActions = <Map<String, dynamic>>[];
            final reactions = <Map<String, dynamic>>[];
            final legendary = <Map<String, dynamic>>[];

            final sections = m.actionsMarkdown.split(RegExp(r'\n*###\s+'));
            for (int i = 1; i < sections.length; i++) {
              final s = sections[i];
              final nl = s.indexOf('\n');
              if (nl == -1) continue;
              final title = s.substring(0, nl).trim().toLowerCase();
              final content = s.substring(nl + 1).trim();
              final items = <Map<String, dynamic>>[];
              final blocks = content.split(RegExp(r'\n\s*\n'));
              for (final block in blocks) {
                final colonIdx = block.indexOf('**:');
                if (block.startsWith('**') && colonIdx != -1) {
                  final bName = block.substring(2, colonIdx).trim();
                  final desc = block.substring(colonIdx + 3).trim();
                  if (bName.isNotEmpty) {
                    items.add({
                      'name': bName,
                      'entries': [desc],
                    });
                  }
                }
              }
              if (title.contains('trait')) {
                traits.addAll(items);
              } else if (title.contains('bonus')) {
                bonusActions.addAll(items);
              } else if (title.contains('reaction')) {
                reactions.addAll(items);
              } else if (title.contains('legendary')) {
                legendary.addAll(items);
              } else if (title.contains('action')) {
                actions.addAll(items);
              }
            }

            int str = (m.customProperties['str'] as num?)?.toInt() ?? 10;
            int dex = (m.customProperties['dex'] as num?)?.toInt() ?? 10;
            int con = (m.customProperties['con'] as num?)?.toInt() ?? 10;
            int intStat = (m.customProperties['int'] as num?)?.toInt() ?? 10;
            int wis = (m.customProperties['wis'] as num?)?.toInt() ?? 10;
            int cha = (m.customProperties['cha'] as num?)?.toInt() ?? 10;

            final statTableMatch = RegExp(
              r'\|\s*(\d+)\s*\([+-]?\d+\)\s*\|\s*(\d+)\s*\([+-]?\d+\)\s*\|\s*(\d+)\s*\([+-]?\d+\)\s*\|\s*(\d+)\s*\([+-]?\d+\)\s*\|\s*(\d+)\s*\([+-]?\d+\)\s*\|\s*(\d+)\s*\([+-]?\d+\)\s*\|',
            ).firstMatch(m.actionsMarkdown);
            if (statTableMatch != null) {
              str = int.tryParse(statTableMatch.group(1)!) ?? str;
              dex = int.tryParse(statTableMatch.group(2)!) ?? dex;
              con = int.tryParse(statTableMatch.group(3)!) ?? con;
              intStat = int.tryParse(statTableMatch.group(4)!) ?? intStat;
              wis = int.tryParse(statTableMatch.group(5)!) ?? wis;
              cha = int.tryParse(statTableMatch.group(6)!) ?? cha;
            }

            baseMonsterLookup[m.name.toLowerCase().trim()] = {
              'name': m.name,
              'ac': m.armorClass,
              'hp': {'average': m.hitPoints, 'formula': m.hitDieFormula},
              'cr': m.challengeRating,
              'speed': m.customProperties['speed'] ?? '30 ft.',
              'str': str,
              'dex': dex,
              'con': con,
              'int': intStat,
              'wis': wis,
              'cha': cha,
              'strScore': str,
              'dexScore': dex,
              'conScore': con,
              'intScore': intStat,
              'wisScore': wis,
              'chaScore': cha,
              if (traits.isNotEmpty) 'trait': traits,
              if (actions.isNotEmpty) 'action': actions,
              if (bonusActions.isNotEmpty) 'bonus': bonusActions,
              if (reactions.isNotEmpty) 'reaction': reactions,
              if (legendary.isNotEmpty) 'legendary': legendary,
              'actionsMarkdown': m.actionsMarkdown,
              ...m.customProperties,
            };
          }
        }

        final revitalizedMonsters = bundle.monsters.map((m) {
          final hasCopy = m.customProperties.containsKey('_copy');
          final hasDefaultStats = m.actionsMarkdown.isEmpty ||
              m.actionsMarkdown.contains('| 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) | 10 (+0) |') ||
              m.actionsMarkdown.startsWith('**Speed:** 30 ft.\n\n| STR | DEX') ||
              (m.hitPoints <= 10 && m.armorClass == 10) ||
              m.challengeRating == '0';

          if (hasCopy && hasDefaultStats) {
            final copyObj = m.customProperties['_copy'];
            if (copyObj is Map && copyObj['name'] != null) {
              final rawSynthesized = <String, dynamic>{
                ...m.customProperties,
                'name': m.name,
                'source': m.id.ruleset.name,
                '_copy': copyObj,
                if (m.armorClass > 10) 'ac': m.armorClass,
                if (m.hitPoints > 10) 'hp': {'average': m.hitPoints, 'formula': m.hitDieFormula},
                if (m.challengeRating != '0') 'cr': m.challengeRating,
              };
              rawSynthesized.remove('str');
              rawSynthesized.remove('dex');
              rawSynthesized.remove('con');
              rawSynthesized.remove('int');
              rawSynthesized.remove('wis');
              rawSynthesized.remove('cha');
              rawSynthesized.remove('strScore');
              rawSynthesized.remove('dexScore');
              rawSynthesized.remove('conScore');
              rawSynthesized.remove('intScore');
              rawSynthesized.remove('wisScore');
              rawSynthesized.remove('chaScore');
              if (m.armorClass <= 10) rawSynthesized.remove('ac');
              if (m.hitPoints <= 10) rawSynthesized.remove('hp');
              if (m.challengeRating == '0') rawSynthesized.remove('cr');

              return monsterParser.parseMonster(
                rawSynthesized,
                forceRuleset: forceRuleset ?? m.id.ruleset,
                baseLookup: (name, src) => baseMonsterLookup[name.toLowerCase().trim()],
              );
            }
          }

          // Clean legacy actionsMarkdown of unparsed tags and leaked untyped
          String actions = m.actionsMarkdown;
          if (actions.contains('{@') || actions.contains('untyped')) {
            actions = transformer.transformEntries(actions).markdown;
            actions = actions.replaceAll(RegExp(r'\*\*`([^`]+)\s+untyped`\*\*'), r'**`$1`**');
          }

          // Revitalize attackMath damage types from actions text if untyped
          var updatedAttackMath = m.attackMath;
          if (m.attackMath.any((a) => a.damageType == DamageType.untyped)) {
            final cleanAct = actions.toLowerCase();
            updatedAttackMath = m.attackMath.map((att) {
              if (att.damageType != DamageType.untyped) return att;
              final fEsc = RegExp.escape(att.diceFormula.toLowerCase());
              final match = RegExp(
                fEsc + r'[^\n\.]*?\b(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)\s+damage',
                caseSensitive: false,
              ).firstMatch(cleanAct);
              if (match != null) {
                final typeStr = match.group(1)!.toLowerCase();
                final resolvedType = DamageType.values.firstWhere(
                  (d) => d.name == typeStr,
                  orElse: () => DamageType.untyped,
                );
                if (resolvedType != DamageType.untyped) {
                  return EvaluationMath(
                    diceFormula: att.diceFormula,
                    damageType: resolvedType,
                    scalingFormula: att.scalingFormula,
                  );
                }
              }
              return att;
            }).toList();
          }

          if (actions != m.actionsMarkdown || updatedAttackMath != m.attackMath) {
            return m.copyWith(actionsMarkdown: actions, attackMath: updatedAttackMath);
          }
          return m;
        }).toList();

        final revitalizedSpells = bundle.spells.map((s) {
          String desc = s.descriptionMarkdown;
          if (desc.contains('{@') || desc.contains('untyped')) {
            desc = transformer.transformEntries(desc).markdown;
            desc = desc.replaceAll(RegExp(r'\*\*`([^`]+)\s+untyped`\*\*'), r'**`$1`**');
          }
          String? hl = s.higherLevelsMarkdown;
          if (hl != null && (hl.contains('{@') || hl.contains('untyped'))) {
            hl = transformer.transformEntries(hl).markdown;
            hl = hl.replaceAll(RegExp(r'\*\*`([^`]+)\s+untyped`\*\*'), r'**`$1`**');
          }
          var updated = s.copyWith(descriptionMarkdown: desc, higherLevelsMarkdown: hl);

          if (!updated.customProperties.containsKey('classes') ||
              (updated.customProperties['classes'] is List && (updated.customProperties['classes'] as List).isEmpty)) {
            final parsedClasses = spellParser.parseSpell({
              'name': updated.name,
              'source': updated.id.ruleset.name,
              'classes': updated.customProperties['classes'],
            }).customProperties['classes'];
            if (parsedClasses != null) {
              final cp = Map<String, dynamic>.from(updated.customProperties);
              cp['classes'] = parsedClasses;
              return updated.copyWith(customProperties: cp);
            }
          }
          return updated;
        }).toList();

        final revitalizedItems = bundle.items.map((i) {
          var desc = i.descriptionMarkdown;
          if (desc.contains('{@') || desc.contains('untyped')) {
            desc = cleanRawTags(desc);
            desc = desc.replaceAll(RegExp(r'\*\*`([^`]+)\s+untyped`\*\*'), r'**`$1`**');
          }
          var customProps = Map<String, dynamic>.from(i.customProperties);
          if (customProps.containsKey('rechargeAmount')) {
            final rc = customProps['rechargeAmount'];
            if (rc is String && rc.contains('{@')) {
              customProps['rechargeAmount'] = cleanRawTags(rc).replaceAll('`', '').trim();
            }
          }
          final raw = <String, dynamic>{
            ...customProps,
            'name': i.name,
            'type': i.itemType,
            'rarity': i.rarity,
            'reqAttune': i.requiresAttunement,
            if (desc.isNotEmpty) 'entries': [desc],
          };
          final reparsed = itemParser.parseItem(raw, forceRuleset: forceRuleset ?? i.id.ruleset);
          return reparsed.copyWith(
            descriptionMarkdown: desc.isNotEmpty ? desc : reparsed.descriptionMarkdown,
            customProperties: customProps,
          );
        }).toList();

        final revitalizedRaces = bundle.races.where((r) => r.id.slug.isNotEmpty && r.name.isNotEmpty).map((r) {
          final raw = <String, dynamic>{
            ...r.customProperties,
            'name': r.name,
            'size': r.size,
            'speed': r.customProperties['speed'] ?? r.speed,
            if (r.traitsMarkdown.isNotEmpty) 'entries': [r.traitsMarkdown],
            if (r.abilityScoreSummary != null) 'abilityScoreSummary': r.abilityScoreSummary,
          };
          final reparsed = raceParser.parseRace(raw, forceRuleset: forceRuleset ?? r.id.ruleset);
          final validSubraces = r.subraces.where((s) => s.id.slug.isNotEmpty || s.name.isNotEmpty).toList();
          return reparsed.copyWith(
            traitsMarkdown: r.traitsMarkdown.isNotEmpty ? r.traitsMarkdown : reparsed.traitsMarkdown,
            subraces: validSubraces.isNotEmpty ? validSubraces : reparsed.subraces,
          );
        }).toList();

        final revitalizedFeats = bundle.feats.map((f) {
          final raw = <String, dynamic>{
            ...f.customProperties,
            'name': f.name,
            'prerequisite': f.prerequisite,
            'category': f.category,
            if (f.descriptionMarkdown.isNotEmpty) 'entries': [f.descriptionMarkdown],
          };
          final reparsed = featParser.parseFeat(raw, forceRuleset: forceRuleset ?? f.id.ruleset);
          return reparsed.copyWith(
            descriptionMarkdown: f.descriptionMarkdown.isNotEmpty ? f.descriptionMarkdown : reparsed.descriptionMarkdown,
          );
        }).toList();

        final revitalizedBackgrounds = bundle.backgrounds.map((b) {
          final raw = <String, dynamic>{
            ...b.customProperties,
            'name': b.name,
            'skillProficiencies': b.skillProficiencies,
            'toolProficiencies': b.toolProficiencies,
            'languageProficiencies': b.languages,
            'feat': b.originFeat,
            'ability': b.abilityScoreSummary,
            if (b.descriptionMarkdown.isNotEmpty) 'entries': [b.descriptionMarkdown],
          };
          final reparsed = backgroundParser.parseBackground(raw, forceRuleset: forceRuleset ?? b.id.ruleset);
          return reparsed.copyWith(
            descriptionMarkdown: b.descriptionMarkdown.isNotEmpty ? b.descriptionMarkdown : reparsed.descriptionMarkdown,
          );
        }).toList();

        final revitalizedOtherEntries = bundle.otherEntries.map((o) {
          final raw = <String, dynamic>{
            ...o.customProperties,
            'name': o.name,
            'category': o.category,
            if (o.descriptionMarkdown.isNotEmpty) 'entries': [o.descriptionMarkdown],
          };
          final reparsed = genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset ?? o.id.ruleset, defaultCategory: o.category);
          return reparsed.copyWith(
            descriptionMarkdown: o.descriptionMarkdown.isNotEmpty ? o.descriptionMarkdown : reparsed.descriptionMarkdown,
          );
        }).toList();

        final revitalizedClasses = bundle.classes.map((c) {
          var updated = c;
          if (c.featuresMarkdown.contains('{@')) {
            updated = updated.copyWith(featuresMarkdown: cleanRawTags(updated.featuresMarkdown));
          }
          if (c.grants.isEmpty && (c.customProperties.containsKey('additionalSpells') || c.customProperties.containsKey('spells'))) {
            final grants = classParser.extractSpellsGrants(
              c.customProperties['additionalSpells'] ?? c.customProperties['spells'],
              'class',
              c.id.slug,
            );
            if (grants.isNotEmpty) {
              updated = updated.copyWith(grants: [...updated.grants, ...grants]);
            }
          }
          return updated;
        }).toList();

        final revitalizedSubclasses = bundle.subclasses.map((s) {
          var updated = s;
          if (s.featuresMarkdown.contains('{@')) {
            updated = updated.copyWith(featuresMarkdown: cleanRawTags(updated.featuresMarkdown));
          }
          if (s.grants.isEmpty && (s.customProperties.containsKey('additionalSpells') || s.customProperties.containsKey('subclassSpells'))) {
            final grants = classParser.extractSpellsGrants(
              s.customProperties['additionalSpells'] ?? s.customProperties['subclassSpells'],
              'subclass',
              s.id.slug,
            );
            if (grants.isNotEmpty) {
              updated = updated.copyWith(grants: [...updated.grants, ...grants]);
            }
          }
          return updated;
        }).toList();

        return IngestionBatchResult(
          spells: revitalizedSpells,
          monsters: revitalizedMonsters,
          items: revitalizedItems,
          classes: revitalizedClasses,
          subclasses: revitalizedSubclasses,
          races: revitalizedRaces,
          feats: revitalizedFeats,
          backgrounds: revitalizedBackgrounds,
          otherEntries: revitalizedOtherEntries,
        );
      } catch (e) {
        // Fall back to standard map ingestion
      }
    }

    // 2. If the map itself represents a single entity definition (e.g. no bundle list keys)
    final hasBundleKeys = lowerKeys.any((k) => const {
      'spell', 'spells', 'monster', 'monsters', 'bestiary', 'creature', 'creatures',
      'item', 'items', 'baseitem', 'magicitems', 'magicitem', 'magicvariants', 'equipment',
      'class', 'classes', 'subclass', 'subclasses', 'classfeature', 'classfeatures',
      'subclassfeature', 'subclassfeatures', 'race', 'races', 'species', 'lineage', 'lineages',
      'subrace', 'subraces', 'feat', 'feats', 'background', 'backgrounds',
      'invocation', 'invocations', 'eldritchinvocation', 'eldritchinvocations',
      'optionalfeature', 'optionalfeatures', 'table', 'tables', 'reward', 'rewards',
      'condition', 'conditions', 'hazard', 'hazards', 'variantrule', 'variantrules', 'rule', 'rules',
      'monsterfluff', 'spellfluff', 'itemfluff', 'racefluff', 'classfluff', 'featfluff', 'backgroundfluff', 'fluff',
    }.contains(k) && map[k] is List);

    final isSingleClass = lowerKeys.contains('hd') && lowerKeys.contains('name');
    final isSingleMonster = lowerKeys.contains('cr') && lowerKeys.contains('name');
    final isSingleSpell = lowerKeys.contains('school') && lowerKeys.contains('name');
    final isSingleFluff = (lowerKeys.contains('entries') || lowerKeys.contains('images')) &&
        lowerKeys.contains('name') &&
        (lowerKeys.contains('_fluff') || lowerKeys.contains('flufftype'));

    if (!hasBundleKeys || isSingleClass || isSingleMonster || isSingleSpell || isSingleFluff) {
      final singleResult = _ingestSingleEntityMap(map, forceRuleset: forceRuleset);
      if (singleResult.totalEntities > 0) {
        return singleResult;
      }
    }

    final spells = <Spell>[];
    final monsters = <Monster>[];
    final items = <EquipmentItem>[];
    final classes = <CharacterClass>[];
    final subclasses = <Subclass>[];
    final races = <Race>[];
    final feats = <Feat>[];
    final backgrounds = <Background>[];
    final otherEntries = <HomebrewCompendiumEntry>[];
    final errors = <String>[];

    // Helper to find key case-insensitively
    List<dynamic>? findListForKeys(List<String> candidateKeys) {
      for (final candidate in candidateKeys) {
        final candLower = candidate.toLowerCase();
        for (final entry in map.entries) {
          if (entry.key.toLowerCase() == candLower && entry.value is List) {
            return entry.value as List;
          }
        }
      }
      return null;
    }

    // Helper to safely loop over list in matching map keys
    void ingestKeys(List<String> candidateKeys, void Function(Map<String, dynamic>) handler, String entityLabel) {
      final list = findListForKeys(candidateKeys);
      if (list != null) {
        for (final raw in list) {
          if (raw is Map) {
            try {
              handler(Map<String, dynamic>.from(raw));
            } catch (e) {
              errors.add('$entityLabel error (${raw['name'] ?? 'unnamed'}): $e');
            }
          }
        }
      }
    }

    // Spells
    ingestKeys(['spell', 'spells'], (raw) => spells.add(spellParser.parseSpell(raw, forceRuleset: forceRuleset)), 'Spell');

    // Monsters / Bestiary
    final rawMonsterList = findListForKeys(['monster', 'monsters', 'bestiary', 'creature', 'creatures', 'npc', 'npcs']);
    if (rawMonsterList != null) {
      final batchLookup = <String, Map<String, dynamic>>{};
      final rawMonsters = <Map<String, dynamic>>[];
      for (final item in rawMonsterList) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          rawMonsters.add(m);
          final name = m['name']?.toString().toLowerCase().trim();
          if (name != null && name.isNotEmpty && !m.containsKey('_copy')) {
            batchLookup[name] = m;
          }
        }
      }

      Map<String, dynamic>? lookupBase(String name, String? source) {
        final norm = name.toLowerCase().trim();
        return batchLookup[norm];
      }

      for (final raw in rawMonsters) {
        try {
          final parsed = monsterParser.parseMonster(
            raw,
            forceRuleset: forceRuleset,
            baseLookup: lookupBase,
          );
          monsters.add(parsed);
        } catch (e) {
          errors.add('Monster error (${raw['name'] ?? 'unnamed'}): $e');
        }
      }
    }

    // Items / Equipment
    ingestKeys(['item', 'items', 'baseitem', 'magicitems', 'magicitem', 'magicvariants', 'equipment'],
        (raw) => items.add(itemParser.parseItem(raw, forceRuleset: forceRuleset)), 'Item');

    // Intercept Class & Subclass features upfront to build relational stitching lookup maps
    final rawSubclassFeatures = <Map<String, dynamic>>[];
    ingestKeys(['subclassfeature', 'subclassfeatures'], (raw) {
      rawSubclassFeatures.add(raw);
    }, 'Subclass Feature');

    final rawClassFeatures = <Map<String, dynamic>>[];
    ingestKeys(['classfeature', 'classfeatures'], (raw) {
      final isSubclass = raw['subclassShortName'] != null ||
          raw['subclass'] != null ||
          raw['subclassName'] != null ||
          raw['gainSubclassFeature'] == true;
      if (isSubclass) {
        rawSubclassFeatures.add(raw);
      } else {
        rawClassFeatures.add(raw);
      }
    }, 'Class Feature');

    final classFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawClassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className = (feat['className']?.toString() ?? feat['class']?.toString() ?? '').toLowerCase().trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();

      if (name.isNotEmpty) {
        classFeatureMap[name] = feat;
        if (className.isNotEmpty) {
          classFeatureMap['$name|$className'] = feat;
          if (level.isNotEmpty) {
            classFeatureMap['$name|$className|$level'] = feat;
            if (source.isNotEmpty) {
              classFeatureMap['$name|$className|$source|$level'] = feat;
            }
          }
        }
      }
    }

    final subclassFeatureMap = <String, Map<String, dynamic>>{};
    for (final feat in rawSubclassFeatures) {
      final name = feat['name']?.toString().toLowerCase().trim() ?? '';
      final className = (feat['className']?.toString() ?? feat['class']?.toString() ?? '').toLowerCase().trim();
      final subShort = (feat['subclassShortName']?.toString() ?? feat['shortName']?.toString() ?? '').toLowerCase().trim();
      final source = (feat['source']?.toString() ?? '').toLowerCase().trim();
      final subSource = (feat['subclassSource']?.toString() ?? source).toLowerCase().trim();
      final level = (feat['level']?.toString() ?? '').trim();

      if (name.isNotEmpty) {
        subclassFeatureMap[name] = feat;
        if (subShort.isNotEmpty) {
          subclassFeatureMap['$name|$subShort'] = feat;
          if (level.isNotEmpty) {
            subclassFeatureMap['$name|$subShort|$level'] = feat;
            if (className.isNotEmpty) {
              subclassFeatureMap['$name|$className|$subShort|$level'] = feat;
              if (source.isNotEmpty) {
                subclassFeatureMap['$name|$className|$source|$subShort|$subSource|$level'] = feat;
              }
            }
          }
        }
      }
    }

    // Classes & Subclasses (with relational feature lookup maps)
    ingestKeys(['class', 'classes'], (raw) {
      final parsedClass = classParser.parseClass(
        raw,
        forceRuleset: forceRuleset,
        classFeatureMap: classFeatureMap,
        subclassFeatureMap: subclassFeatureMap,
      );
      classes.add(parsedClass);
      // Automatically extract any embedded subclasses as standalone subclasses
      // so additive additions to SRD classes are tracked and importable!
      for (final sub in parsedClass.subclasses) {
        if (!subclasses.any((s) => s.id.slug == sub.id.slug)) {
          subclasses.add(sub);
        }
      }
    }, 'Class');

    ingestKeys(['subclass', 'subclasses'], (raw) {
      final sub = classParser.parseSubclass(
        raw,
        forceRuleset: forceRuleset,
        subclassFeatureMap: subclassFeatureMap,
      );
      if (!subclasses.any((s) => s.id.slug == sub.id.slug)) {
        subclasses.add(sub);
      }
      final matchClass = classes.where((c) => c.id.slug == sub.classSlug || c.name.toLowerCase() == sub.classSlug.toLowerCase()).firstOrNull;
      if (matchClass != null) {
        if (!matchClass.subclasses.any((s) => s.id.slug == sub.id.slug)) {
          final idx = classes.indexOf(matchClass);
          classes[idx] = matchClass.copyWith(subclasses: [...matchClass.subclasses, sub]);
        }
      }
    }, 'Subclass');

    // Races / Species
    ingestKeys(['race', 'races', 'species', 'lineage', 'lineages'], (raw) => races.add(raceParser.parseRace(raw, forceRuleset: forceRuleset)), 'Race');
    ingestKeys(['subrace', 'subraces'], (raw) {
      final sub = raceParser.parseSubrace(raw, forceRuleset: forceRuleset);
      if (sub.raceSlug.isEmpty) return;
      final match = races.where((r) => r.id.slug == sub.raceSlug).firstOrNull;
      if (match != null) {
        final idx = races.indexOf(match);
        races[idx] = match.copyWith(subraces: [...match.subraces, sub]);
      } else {
        races.add(Race(
          id: EntityId(slug: sub.raceSlug, ruleset: forceRuleset ?? sub.id.ruleset),
          name: sub.raceSlug.replaceAll('-', ' '),
          traitsMarkdown: '',
          subraces: [sub],
        ));
      }
    }, 'Subrace');

    // Feats
    ingestKeys(['feat', 'feats'], (raw) => feats.add(featParser.parseFeat(raw, forceRuleset: forceRuleset)), 'Feat');

    // Backgrounds
    ingestKeys(['background', 'backgrounds'], (raw) => backgrounds.add(backgroundParser.parseBackground(raw, forceRuleset: forceRuleset)), 'Background');

    // Eldritch Invocations & Pact Boons
    ingestKeys([
      'invocation',
      'invocations',
      'eldritchinvocation',
      'eldritchinvocations',
    ], (raw) {
      final name = raw['name']?.toString().toLowerCase() ?? '';
      final featureType = raw['featureType']?.toString().toUpperCase() ?? '';
      String category = 'Eldritch Invocation';
      if (name.startsWith('pact of the') || name.contains('pact boon') || featureType.contains('PB')) {
        category = 'Pact Boon';
      }
      otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: category));
    }, 'Eldritch Invocation');

    // Other Compendium Entities & Optional Features
    ingestKeys(['optionalfeature', 'optionalfeatures'], (raw) {
      final featureType = raw['featureType']?.toString().toUpperCase() ?? '';
      final name = raw['name']?.toString().toLowerCase() ?? '';
      String category = 'Optional Feature';
      if (name.startsWith('pact of the') || name.contains('pact boon') || featureType.contains('PB')) {
        category = 'Pact Boon';
      } else if (featureType.contains('EI') || name.contains('invocation') || raw['isInvocation'] == true) {
        category = 'Eldritch Invocation';
      } else if (featureType.contains('MM') || name.contains('metamagic')) {
        category = 'Metamagic';
      } else if (featureType.contains('MAN') || featureType.contains('BM') || name.contains('maneuver')) {
        category = 'Maneuver';
      } else if (featureType.contains('AI') || featureType.contains('INF') || name.contains('infusion')) {
        category = 'Infusion';
      }
      otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: category));
    }, 'Optional Feature');

    ingestKeys(['table', 'tables'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: 'Table')), 'Table');
    ingestKeys(['reward', 'rewards'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: 'Reward')), 'Reward');
    ingestKeys(['condition', 'conditions'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: 'Condition')), 'Condition');
    ingestKeys(['hazard', 'hazards'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: 'Hazard')), 'Hazard');
    ingestKeys(['variantrule', 'variantrules', 'rule', 'rules'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset, defaultCategory: 'Rule')), 'Rule');
    ingestKeys(['otherentry', 'otherentries', 'genericentry', 'genericentries'], (raw) => otherEntries.add(genericParser.parseGenericEntry(raw, forceRuleset: forceRuleset)), 'Generic Entry');

    // Fluff & Lore Ingestion (5etools bestiary / spell / item / race / class / feat fluff)
    int attachedFluffCount = 0;

    void ingestFluffKeys(List<String> candidateKeys, String defaultEntityType) {
      final list = findListForKeys(candidateKeys);
      if (list == null) return;
      for (final item in list) {
        if (item is Map) {
          final count = _ingestFluffEntry(defaultEntityType, Map<String, dynamic>.from(item));
          attachedFluffCount += count;
        }
      }
    }

    ingestFluffKeys(['monsterfluff', 'bestiaryfluff', 'creaturefluff'], 'monster');
    ingestFluffKeys(['spellfluff'], 'spell');
    ingestFluffKeys(['itemfluff', 'magicitemfluff'], 'item');
    ingestFluffKeys(['racefluff', 'speciesfluff'], 'race');
    ingestFluffKeys(['classfluff'], 'class');
    ingestFluffKeys(['featfluff'], 'feat');
    ingestFluffKeys(['backgroundfluff'], 'background');
    ingestFluffKeys(['fluff'], 'generic');

    // Stitch external subclass features into Subclasses
    if (rawSubclassFeatures.isNotEmpty) {
      final entryTransformer = classParser.transformer;
      for (int i = 0; i < subclasses.length; i++) {
        final sub = subclasses[i];
        final cleanSubName = sub.name.toLowerCase().trim();
        final cleanSubShort = sub.shortName.toLowerCase().trim();
        final cleanClass = sub.classSlug.toLowerCase().trim();

        final matchingFeatures = rawSubclassFeatures.where((f) {
          final fClass = (f['className']?.toString() ?? f['class']?.toString() ?? '').toLowerCase().trim();
          final fSubShort = (f['subclassShortName'] ?? f['shortName'] ?? f['subclass'])?.toString().toLowerCase().trim() ?? '';
          final fSubName = (f['subclassName'] ?? f['name'])?.toString().toLowerCase().trim() ?? '';

          final matchesClass = fClass.isEmpty || cleanClass.isEmpty || fClass == cleanClass || cleanClass.contains(fClass) || fClass.contains(cleanClass);
          final matchesSub = fSubShort == cleanSubShort ||
              fSubShort == cleanSubName ||
              fSubName == cleanSubName ||
              fSubName == cleanSubShort ||
              (fSubShort.isNotEmpty && (cleanSubName.contains(fSubShort) || cleanSubShort.contains(fSubShort)));

          return matchesClass && matchesSub;
        }).toList();

        if (matchingFeatures.isNotEmpty) {
          matchingFeatures.sort((a, b) => ((a['level'] as num?) ?? 0).compareTo((b['level'] as num?) ?? 0));
          final featureBlocks = <String>[];
          for (final feat in matchingFeatures) {
            final fName = feat['name']?.toString() ?? '';
            final level = feat['level'] != null ? ' (Level ${feat['level']})' : '';
            final fContent = entryTransformer.transformEntries(feat['entries'] ?? feat['entry'] ?? feat['desc'] ?? feat['description']).markdown;
            if (fName.isNotEmpty || fContent.isNotEmpty) {
              featureBlocks.add('### $fName$level\n$fContent');
            }
          }
          if (featureBlocks.isNotEmpty) {
            final combinedMarkdown = sub.featuresMarkdown.isEmpty || (sub.featuresMarkdown.contains('|') && !sub.featuresMarkdown.contains('\n'))
                ? featureBlocks.join('\n\n')
                : '${sub.featuresMarkdown}\n\n${featureBlocks.join('\n\n')}';
            subclasses[i] = Subclass(
              id: sub.id,
              name: sub.name,
              classSlug: sub.classSlug,
              shortName: sub.shortName,
              featuresMarkdown: combinedMarkdown.trim(),
              customProperties: sub.customProperties,
            );
          }
        }
      }

      // Keep class.subclasses synchronized with the newly enriched subclasses
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final updatedSubs = <Subclass>[];
        for (final sub in cls.subclasses) {
          final matchingSub = subclasses.where((s) => s.id.slug == sub.id.slug).firstOrNull;
          updatedSubs.add(matchingSub ?? sub);
        }
        classes[i] = cls.copyWith(subclasses: updatedSubs);
      }
    }

    // Stitch external class features into Classes
    if (rawClassFeatures.isNotEmpty) {
      final entryTransformer = classParser.transformer;
      for (int i = 0; i < classes.length; i++) {
        final cls = classes[i];
        final cleanClass = cls.id.slug.toLowerCase().trim();
        final cleanClassName = cls.name.toLowerCase().trim();

        final matchingFeatures = rawClassFeatures.where((f) {
          final isSubclass = f['subclassShortName'] != null ||
              f['subclass'] != null ||
              f['subclassName'] != null ||
              f['gainSubclassFeature'] == true;
          if (isSubclass) return false;
          final fClass = (f['className']?.toString() ?? f['class']?.toString() ?? '').toLowerCase().trim();
          return fClass == cleanClass || fClass == cleanClassName;
        }).toList();

        if (matchingFeatures.isNotEmpty) {
          matchingFeatures.sort((a, b) => ((a['level'] as num?) ?? 0).compareTo((b['level'] as num?) ?? 0));
          final featureBlocks = <String>[];
          for (final feat in matchingFeatures) {
            final fName = feat['name']?.toString() ?? '';
            final level = feat['level'] != null ? ' (Level ${feat['level']})' : '';
            final fContent = entryTransformer.transformEntries(feat['entries'] ?? feat['entry'] ?? feat['desc'] ?? feat['description']).markdown;
            if (fName.isNotEmpty || fContent.isNotEmpty) {
              featureBlocks.add('### $fName$level\n$fContent');
            }
          }
          if (featureBlocks.isNotEmpty) {
            final combinedMarkdown = cls.featuresMarkdown.isEmpty || (cls.featuresMarkdown.contains('|') && !cls.featuresMarkdown.contains('\n'))
                ? featureBlocks.join('\n\n')
                : '${cls.featuresMarkdown}\n\n${featureBlocks.join('\n\n')}';
            classes[i] = cls.copyWith(featuresMarkdown: combinedMarkdown.trim());
          }
        }
      }
    }

    // If no bundle arrays found, attempt single entity map parse
    final hasAny = spells.isNotEmpty ||
        monsters.isNotEmpty ||
        items.isNotEmpty ||
        classes.isNotEmpty ||
        subclasses.isNotEmpty ||
        races.isNotEmpty ||
        feats.isNotEmpty ||
        backgrounds.isNotEmpty ||
        otherEntries.isNotEmpty ||
        attachedFluffCount > 0;

    if (!hasAny) {
      return _ingestSingleEntityMap(map);
    }

    return IngestionBatchResult(
      spells: spells,
      monsters: monsters,
      items: items,
      classes: classes,
      subclasses: subclasses,
      races: races,
      feats: feats,
      backgrounds: backgrounds,
      otherEntries: otherEntries,
      attachedFluffCount: attachedFluffCount,
      errors: errors,
    );
  }

  IngestionBatchResult _ingestSingleEntityMap(Map<String, dynamic> map, {RulesetVersion? forceRuleset}) {
    final lowerKeys = map.keys.map((k) => k.toLowerCase()).toSet();

    // 0. Fluff / Lore Single Entry (has _fluff, monsterFluff, spellFluff, etc. or pure lore map)
    if (lowerKeys.contains('_fluff') ||
        lowerKeys.contains('fluff') ||
        lowerKeys.contains('flufftype') ||
        lowerKeys.contains('monsterfluff') ||
        lowerKeys.contains('spellfluff') ||
        lowerKeys.contains('itemfluff') ||
        lowerKeys.contains('racefluff') ||
        lowerKeys.contains('classfluff') ||
        lowerKeys.contains('featfluff')) {
      String entityType = 'generic';
      if (lowerKeys.contains('monsterfluff') || map['fluffType'] == 'monster' || map['type'] == 'monster') {
        entityType = 'monster';
      } else if (lowerKeys.contains('spellfluff') || map['fluffType'] == 'spell' || map['type'] == 'spell') {
        entityType = 'spell';
      } else if (lowerKeys.contains('itemfluff') || map['fluffType'] == 'item' || map['type'] == 'item') {
        entityType = 'item';
      } else if (lowerKeys.contains('racefluff') || map['fluffType'] == 'race' || map['type'] == 'race') {
        entityType = 'race';
      } else if (lowerKeys.contains('classfluff') || map['fluffType'] == 'class' || map['type'] == 'class') {
        entityType = 'class';
      } else if (lowerKeys.contains('featfluff') || map['fluffType'] == 'feat' || map['type'] == 'feat') {
        entityType = 'feat';
      }

      final count = _ingestFluffEntry(entityType, map);
      if (count > 0) {
        return IngestionBatchResult(attachedFluffCount: count);
      }
    }

    // 1. Identify Spells (has school or level + time/duration/range)
    if (lowerKeys.contains('school') ||
        (lowerKeys.contains('level') &&
            (lowerKeys.contains('time') || lowerKeys.contains('duration') || lowerKeys.contains('range')))) {
      try {
        final spell = spellParser.parseSpell(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(spells: [spell]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse spell: $e']);
      }
    }

    // 2. Identify Monsters (has cr or hp or ac or statblock)
    if (lowerKeys.contains('cr') ||
        (lowerKeys.contains('hp') && (lowerKeys.contains('ac') || lowerKeys.contains('speed')))) {
      try {
        final monster = monsterParser.parseMonster(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(monsters: [monster]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse monster: $e']);
      }
    }

    // 3. Identify Classes (has hd and proficiency or classFeatures)
    if (lowerKeys.contains('hd') ||
        lowerKeys.contains('classfeatures') ||
        (lowerKeys.contains('proficiency') && lowerKeys.contains('subclasses'))) {
      try {
        final cl = classParser.parseClass(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(
          classes: [cl],
          subclasses: cl.subclasses,
        );
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse class: $e']);
      }
    }

    // 4. Identify Subclasses (has className, classSlug, subclassFeatures, shortName, subclassTitle, or class)
    if (lowerKeys.contains('classname') ||
        lowerKeys.contains('classslug') ||
        lowerKeys.contains('subclassfeatures') ||
        lowerKeys.contains('subclassshortname') ||
        lowerKeys.contains('subclasstitle') ||
        (lowerKeys.contains('class') && (lowerKeys.contains('features') || lowerKeys.contains('desc') || lowerKeys.contains('entries')))) {
      try {
        final sub = classParser.parseSubclass(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(subclasses: [sub]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse subclass: $e']);
      }
    }

    // 5. Identify Races / Species (has speed or size without ac/hp, or traits)
    if ((lowerKeys.contains('size') || lowerKeys.contains('speed')) &&
        !lowerKeys.contains('ac') &&
        !lowerKeys.contains('hp') &&
        !lowerKeys.contains('school')) {
      try {
        final race = raceParser.parseRace(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(races: [race]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse race: $e']);
      }
    }

    // 6. Identify Feats (has prerequisite or featType or category)
    if (lowerKeys.contains('prerequisite') ||
        lowerKeys.contains('feattype') ||
        (map['category']?.toString().toLowerCase().contains('feat') ?? false)) {
      try {
        final feat = featParser.parseFeat(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(feats: [feat]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse feat: $e']);
      }
    }

    // 7. Identify Backgrounds (has skillProficiencies or backgroundFeature)
    if (lowerKeys.contains('skillproficiencies') || lowerKeys.contains('backgroundfeature')) {
      try {
        final bg = backgroundParser.parseBackground(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(backgrounds: [bg]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse background: $e']);
      }
    }

    // 8. Identify Items (has rarity, itemType, reqAttune, or entries)
    if (lowerKeys.contains('rarity') ||
        lowerKeys.contains('type') ||
        lowerKeys.contains('reqattune') ||
        lowerKeys.contains('weaponcategory')) {
      try {
        final item = itemParser.parseItem(map, forceRuleset: forceRuleset);
        return IngestionBatchResult(items: [item]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse item: $e']);
      }
    }

    // 9. Generic Fallback (tables, rules, etc.)
    if (lowerKeys.contains('name')) {
      try {
        final entry = genericParser.parseGenericEntry(map, forceRuleset: forceRuleset, defaultCategory: 'Custom');
        return IngestionBatchResult(otherEntries: [entry]);
      } catch (e) {
        return IngestionBatchResult(errors: ['Failed to parse custom compendium entry: $e']);
      }
    }

    return const IngestionBatchResult(
      errors: ['Unrecognized compendium schema. Could not categorize entity.'],
    );
  }

  int _ingestFluffEntry(String entityType, Map<String, dynamic> raw) {
    final name = raw['name']?.toString().trim() ?? '';
    if (name.isEmpty) return 0;

    final slug = raw['slug']?.toString().trim() ?? _slugify(name);
    final source = raw['source']?.toString().trim();
    final rawEntries = raw['entries'] ?? raw['entry'] ?? raw['fluff'] ?? raw['description'] ?? raw['lore'];
    final loreMarkdown = rawEntries != null ? transformer.transformEntries(rawEntries).markdown.trim() : '';

    final images = <String>[];
    if (raw['images'] is List) {
      for (final img in raw['images'] as List) {
        if (img is String && img.isNotEmpty) {
          images.add(img);
        } else if (img is Map) {
          final href = img['href'];
          if (href is Map && href['path'] != null) {
            images.add(href['path'].toString());
          } else if (href is String) {
            images.add(href);
          }
        }
      }
    }

    if (loreMarkdown.isNotEmpty || images.isNotEmpty) {
      EntityFluffService().setFluff(
        entityType,
        slug,
        loreMarkdown,
        images: images,
        source: source,
      );
      return 1;
    }
    return 0;
  }

  static String cleanRawTags(String input) {
    if (!input.contains('{@')) return input;
    return input.replaceAllMapped(RegExp(r'\{@([a-zA-Z0-9_-]+)(?:\s+([^}]+))?\}'), (match) {
      final tag = match.group(1)?.toLowerCase();
      final content = match.group(2) ?? '';
      final parts = content.split('|');
      final primary = parts[0].trim();
      final display = parts.length > 2 && parts[2].trim().isNotEmpty ? parts[2].trim() : primary;

      switch (tag) {
        case 'dice':
        case 'd20':
          return '**`$primary`**';
        case 'damage':
          return '**`$primary`**';
        case 'h':
          return '*Hit:* ';
        case 'dc':
          return 'DC $primary';
        case 'b':
        case 'bold':
          return '**$primary**';
        case 'i':
        case 'italic':
          return '*$primary*';
        case 'code':
          return '`$primary`';
        case 'note':
          return '> **Note:** $primary';
        case 'book':
        case 'variantrule':
        case 'spell':
        case 'item':
        case 'creature':
        case 'monster':
        case 'class':
        case 'subclass':
        case 'race':
        case 'species':
        case 'feat':
        case 'background':
        case 'classfeature':
        case 'subclassfeature':
        case 'condition':
        case 'status':
        case 'skill':
        case 'sense':
        case 'action':
        case 'table':
          return display;
        default:
          return display;
      }
    });
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}
