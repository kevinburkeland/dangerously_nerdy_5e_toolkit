import '../../models/characters/srd_classes_library.dart';
import '../../models/domain/character_models.dart' show SkillType;
import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_node_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Classes & Subclasses.
class CompendiumClassParser {
  final EntryNodeTransformer transformer;

  CompendiumClassParser({EntryNodeTransformer? transformer})
      : transformer = transformer ?? EntryNodeTransformer();

  /// Transforms a raw community compendium or homebrew class JSON map into a strongly-typed [CharacterClass].
  /// Transforms a raw community compendium or homebrew class JSON map into a strongly-typed [CharacterClass].
  CharacterClass parseClass(
    Map<String, dynamic> raw, {
    RulesetVersion? forceRuleset,
    Map<String, Map<String, dynamic>>? classFeatureMap,
    Map<String, Map<String, dynamic>>? subclassFeatureMap,
  }) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Class';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'SRD';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Hit Die
    final hitDie = _parseHitDie(raw['hd'] ?? raw['hitDie']);

    // Saving Throw Proficiencies
    final savingThrows =
        _parseSavingThrows(raw['proficiency'] ?? raw['savingThrows']);

    // Armor and Weapon Proficiencies
    final armorProficiencies = <String>[];
    final weaponProficiencies = <String>[];
    if (raw['startingProficiencies'] is Map) {
      final sp = raw['startingProficiencies'] as Map;
      if (sp['armor'] is List) {
        armorProficiencies
            .addAll((sp['armor'] as List).map((e) => e.toString()));
      }
      if (sp['weapons'] is List) {
        weaponProficiencies
            .addAll((sp['weapons'] as List).map((e) => e.toString()));
      }
    }

    // Class Features (Level-by-level entries or general entries)
    final featuresMarkdown = _parseClassFeatures(raw, ruleset, classFeatureMap);

    // Subclasses
    final subclasses = <Subclass>[];
    final rawSubList = raw['subclasses'] ?? raw['subclass'];
    if (rawSubList is List) {
      for (final rawSub in rawSubList) {
        if (rawSub is Map) {
          try {
            subclasses.add(parseSubclass(
              Map<String, dynamic>.from(rawSub),
              defaultClassSlug: slug,
              forceRuleset: ruleset,
              subclassFeatureMap: subclassFeatureMap,
            ));
          } catch (_) {}
        }
      }
    }

    final subclassSelectionLevel =
        (raw['subclassSelectionLevel'] as num?)?.toInt() ??
            (raw['subclassLevel'] as num?)?.toInt() ??
            (ruleset == RulesetVersion.v2014 &&
                    ['cleric', 'sorcerer', 'warlock'].contains(slug)
                ? 1
                : ruleset == RulesetVersion.v2014 &&
                        ['druid', 'wizard'].contains(slug)
                    ? 2
                    : 3);

    // Feature Decisions
    final featureDecisions = <ClassFeatureDecision>[];
    if (raw['featureDecisions'] is List) {
      for (final dec in raw['featureDecisions']) {
        if (dec is Map) {
          try {
            featureDecisions.add(
                ClassFeatureDecision.fromMap(Map<String, dynamic>.from(dec)));
          } catch (_) {}
        }
      }
    }

    // Auxiliary Properties (0% data loss)
    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardClassKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    // Explicitly preserve progression tables & starting proficiencies
    if (raw.containsKey('classTableGroups')) {
      customProperties['classTableGroups'] = raw['classTableGroups'];
    }
    if (raw.containsKey('startingProficiencies')) {
      customProperties['startingProficiencies'] = raw['startingProficiencies'];
    }
    if (raw.containsKey('startingEquipment')) {
      customProperties['startingEquipment'] = raw['startingEquipment'];
    }
    if (raw.containsKey('cantripProgression')) {
      customProperties['cantripProgression'] = raw['cantripProgression'];
    }
    if (raw.containsKey('spellsKnownProgression')) {
      customProperties['spellsKnownProgression'] =
          raw['spellsKnownProgression'];
    }

    final parsedSkills = parseClassSkills(raw);
    customProperties['allowedSkills'] = parsedSkills.allowedSkills;
    customProperties['skillChoiceCount'] = parsedSkills.skillChoiceCount;

    final grants = List<FeatureGrant>.from(
      extractSpellsGrants(
        raw['additionalSpells'] ?? raw['spells'],
        'class',
        slug,
      ),
    );

    if (raw['startingProficiencies'] is Map) {
      final sp = raw['startingProficiencies'] as Map;
      if (sp['tools'] is List) {
        for (final t in sp['tools'] as List) {
          var tStr = t.toString().trim();
          if (tStr.contains('{@')) {
            tStr = tStr
                .replaceAllMapped(
                  RegExp(r'\{@[a-zA-Z0-9_-]+\s+([^|}]+)(?:\|[^}]*)?\}'),
                  (m) => m.group(1) ?? '',
                )
                .trim();
          }
          if (tStr.isNotEmpty) {
            grants.add(FeatureGrant.bonusTool(
              tStr,
              grantId:
                  'class-$slug-tool-${tStr.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-")}',
              label: '$tStr Proficiency',
            ));
          }
        }
      }
    }

    return CharacterClass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      hitDie: hitDie,
      primaryAbility: raw['primaryAbility']?.toString(),
      savingThrows: savingThrows,
      armorProficiencies: armorProficiencies,
      weaponProficiencies: weaponProficiencies,
      spellcastingAbility: raw['spellcastingAbility']?.toString(),
      featuresMarkdown: featuresMarkdown,
      subclasses: subclasses,
      subclassSelectionLevel: subclassSelectionLevel,
      featureDecisions: featureDecisions,
      grants: grants,
      customProperties: customProperties,
    );
  }

  /// Transforms a raw community compendium or homebrew subclass JSON map into a strongly-typed [Subclass].
  Subclass parseSubclass(
    Map<String, dynamic> raw, {
    String? defaultClassSlug,
    RulesetVersion? forceRuleset,
    Map<String, Map<String, dynamic>>? subclassFeatureMap,
  }) {
    final name = raw['name']?.toString().trim() ??
        raw['subclassName']?.toString().trim() ??
        raw['title']?.toString().trim() ??
        'Unnamed Subclass';
    final source = raw['source']?.toString().toUpperCase() ??
        raw['subclassSource']?.toString().toUpperCase() ??
        raw['classSource']?.toString().toUpperCase() ??
        'SRD';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    String classSlug = '';
    final rawClassData = raw['className'] ??
        raw['class'] ??
        raw['classSlug'] ??
        raw['class_name'] ??
        raw['parentClass'] ??
        raw['parent_class'];

    if (rawClassData != null && rawClassData.toString().trim().isNotEmpty) {
      if (rawClassData is Map) {
        classSlug = _slugify(rawClassData['name']?.toString() ?? '');
      } else {
        final cleanBase = rawClassData
            .toString()
            .split('|')
            .first
            .replaceAll(
                RegExp(r'\{@[a-zA-Z0-9_-]+\s*([^|}]+)(?:\|[^}]*)?\}'), r'$1')
            .trim();
        classSlug = _slugify(cleanBase);
      }
    } else if (defaultClassSlug != null && defaultClassSlug.isNotEmpty) {
      classSlug = _slugify(defaultClassSlug);
    }

    // Fallback 1: Extract class from subclassFeatures (e.g. "Feature Name|Warlock|CUSTOM|Archetype|CUSTOM|1")
    if (classSlug.isEmpty) {
      final subFeats =
          raw['subclassFeatures'] ?? raw['features'] ?? raw['entries'];
      if (subFeats is List && subFeats.isNotEmpty) {
        for (final item in subFeats) {
          final sStr = item is Map
              ? (item['subclassFeature'] ?? item['name'] ?? '').toString()
              : item.toString();
          if (sStr.contains('|')) {
            final parts = sStr.split('|');
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              classSlug = _slugify(parts[1].trim());
              break;
            }
          }
        }
      }
    }

    // Fallback 2: Extract class from slug or id prefix (e.g. "warlock-custom-archetype")
    if (classSlug.isEmpty) {
      final rawSlug =
          (raw['slug'] ?? raw['id'] ?? '').toString().toLowerCase().trim();
      const srdClasses = [
        'barbarian',
        'bard',
        'cleric',
        'druid',
        'fighter',
        'monk',
        'paladin',
        'ranger',
        'rogue',
        'sorcerer',
        'warlock',
        'wizard',
      ];
      for (final core in srdClasses) {
        if (rawSlug.startsWith('$core-')) {
          classSlug = core;
          break;
        }
      }
      if (classSlug.isEmpty) {
        final hyphenIndex = rawSlug.indexOf('-');
        if (hyphenIndex > 0) {
          classSlug = rawSlug.substring(0, hyphenIndex);
        }
      }
    }

    final nameSlug = _slugify(name);
    final slug = classSlug.isNotEmpty && !nameSlug.startsWith('$classSlug-')
        ? '$classSlug-$nameSlug'
        : nameSlug;

    final shortName = raw['shortName']?.toString() ??
        raw['subclassShortName']?.toString() ??
        raw['subclassTitle']?.toString() ??
        name;

    final entriesData = raw['subclassFeatures'] ??
        raw['features'] ??
        raw['entries'] ??
        raw['desc'] ??
        raw['description'] ??
        raw['subclassFeature'];

    var featuresMarkdown =
        _parseSubclassFeatures(entriesData, ruleset, subclassFeatureMap);
    final rawMarkdown = raw['featuresMarkdown']?.toString().trim() ?? '';
    final isOnlyFallback = featuresMarkdown.isEmpty ||
        !featuresMarkdown.contains('\n\n') ||
        featuresMarkdown.contains('Feature*\n\nGranted at level');
    if (isOnlyFallback &&
        rawMarkdown.isNotEmpty &&
        !rawMarkdown.contains('Feature*\n\nGranted at level')) {
      featuresMarkdown = rawMarkdown;
    }

    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSubclassKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('subclassTableGroups')) {
      customProperties['subclassTableGroups'] = raw['subclassTableGroups'];
    }
    if (raw.containsKey('spellcastingAbility')) {
      customProperties['spellcastingAbility'] = raw['spellcastingAbility'];
    }
    if (raw.containsKey('additionalSpells')) {
      customProperties['additionalSpells'] = raw['additionalSpells'];
    }
    if (raw.containsKey('subclassSpells')) {
      customProperties['subclassSpells'] = raw['subclassSpells'];
    }

    final grants = List<FeatureGrant>.from(
      extractSpellsGrants(
        raw['additionalSpells'] ?? raw['subclassSpells'],
        'subclass',
        slug,
      ),
    );

    return Subclass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      classSlug: classSlug,
      shortName: shortName,
      featuresMarkdown: featuresMarkdown,
      grants: grants,
      customProperties: customProperties,
    );
  }

  static const Set<String> _standardClassKeys = {
    'name',
    'source',
    'hd',
    'hitDie',
    'proficiency',
    'savingThrows',
    'primaryAbility',
    'spellcastingAbility',
    'classFeatures',
    'features',
    'entries',
    'desc',
    'description',
    'subclasses',
    'subclassSelectionLevel',
    'subclassLevel',
    'featureDecisions',
  };

  static const Set<String> _standardSubclassKeys = {
    'name',
    'source',
    'className',
    'classSlug',
    'shortName',
    'subclassTitle',
    'subclassFeatures',
    'features',
    'entries',
    'desc',
    'description',
  };

  String _parseHitDie(dynamic hdData) {
    if (hdData is Map) {
      final faces = hdData['faces'] ?? 8;
      return 'd$faces';
    } else if (hdData is num) {
      return 'd$hdData';
    } else if (hdData != null) {
      final str = hdData.toString();
      return str.startsWith('d') ? str : 'd$str';
    }
    return 'd8';
  }

  List<String> _parseSavingThrows(dynamic profData) {
    final saves = <String>[];
    if (profData is List) {
      for (final p in profData) {
        saves.add(p.toString().toUpperCase());
      }
    }
    return saves;
  }

  Map<String, dynamic>? _lookupFeature(
      dynamic ptr, Map<String, Map<String, dynamic>>? featureMap) {
    String pointerStr = '';
    if (ptr is String) {
      pointerStr = ptr.trim();
    } else if (ptr is Map) {
      pointerStr = (ptr['classFeature'] ??
              ptr['subclassFeature'] ??
              ptr['feature'] ??
              ptr['name'] ??
              ptr['title'] ??
              '')
          .toString()
          .trim();
    }
    if (pointerStr.isEmpty) return null;

    final featureMaps = <Map<String, Map<String, dynamic>>>[
      if (featureMap != null && featureMap.isNotEmpty) featureMap,
      SrdClassesLibrary.customSubclassFeatures,
      SrdClassesLibrary.customClassFeatures,
    ];
    if (featureMaps.isEmpty) return null;

    Map<String, dynamic>? checkKey(String key) {
      for (final map in featureMaps) {
        if (map.containsKey(key)) {
          return map[key];
        }
      }
      return null;
    }

    final lower = pointerStr.toLowerCase();
    final exact = checkKey(lower);
    if (exact != null) return exact;

    final parts = lower.split('|').map((p) => p.trim()).toList();
    if (parts.isNotEmpty) {
      final name = parts[0];
      final slugName = _slugify(name);

      String? className;
      String? classSource;
      String? subShort;
      String? subSource;
      String? level;

      if (parts.length >= 6) {
        className = parts[1];
        classSource = parts[2];
        subShort = parts[3];
        subSource = parts[4];
        level = parts[5];
      } else if (parts.length >= 4) {
        className = parts[1];
        subShort = parts[2];
        level = parts[3];
      } else if (parts.length >= 3) {
        subShort = parts[1];
        level = parts[2];
      } else if (parts.length >= 2) {
        subShort = parts[1];
      }

      final stripped = subShort != null ? _stripArchetypePrefix(subShort) : '';
      final subShortCandidates = <String>{
        if (subShort != null && subShort.isNotEmpty) subShort,
        if (subShort != null && subShort.startsWith('the '))
          subShort.substring(4).trim(),
        if (subShort != null &&
            subShort.isNotEmpty &&
            !subShort.startsWith('the '))
          'the $subShort',
        if (stripped.isNotEmpty) stripped,
        if (stripped.isNotEmpty) _slugify(stripped),
      };

      final candidates = <String>[];
      final candidateShorts = subShortCandidates.isNotEmpty
          ? subShortCandidates.toList()
          : <String?>[null];
      for (final sShort in candidateShorts) {
        if (sShort != null &&
            level != null &&
            className != null &&
            classSource != null &&
            subSource != null) {
          candidates
              .add('$name|$className|$classSource|$sShort|$subSource|$level');
        }
        if (sShort != null &&
            level != null &&
            className != null &&
            classSource != null) {
          candidates.add('$name|$className|$classSource|$sShort||$level');
        }
        if (sShort != null && level != null && className != null) {
          candidates.add('$name|$className||$sShort||$level');
          candidates.add('$name|$className|$sShort|$level');
          candidates
              .add('$name|${_slugify(className)}|${_slugify(sShort)}|$level');
        }
        if (sShort != null && level != null) {
          candidates.add('$name|$sShort|$level');
          candidates.add('$name|${_slugify(sShort)}|$level');
          candidates.add('$slugName|${_slugify(sShort)}|$level');
        }
        if (sShort != null && className != null) {
          candidates.add('$name|$className|$sShort');
          candidates.add('$name|${_slugify(className)}|${_slugify(sShort)}');
        }
        if (sShort != null) {
          candidates.add('$name|$sShort');
          candidates.add('$name|${_slugify(sShort)}');
        }
      }

      if (className != null && level != null) {
        candidates.add('$name|$className|$level');
        candidates.add('$name|${_slugify(className)}|$level');
      }
      if (className != null) {
        candidates.add('$name|$className');
        candidates.add('$name|${_slugify(className)}');
      }
      if (level != null) {
        candidates.add('$name|$level');
        candidates.add('$slugName|$level');
      }
      candidates.add(name);
      candidates.add(slugName);

      for (final key in candidates) {
        final match = checkKey(key);
        if (match != null) return match;
      }
    }
    return null;
  }

  /// Recursively expands nested AST nodes in feature entries:
  /// 1. If [isTopLevel] is true:
  ///    Extracts top-level child feature references (e.g. `refSubclassFeature` or `refClassFeature`)
  ///    into [topLevelExtractedFeatures] to be rendered as first-class feature blocks.
  /// 2. If [isTopLevel] is false:
  ///    In-place resolves referenced features (e.g. inside `options` or `list`) into `{ "name": childName, "entries": childEntries }`.
  dynamic _expandFeatureAst(
    dynamic node,
    Map<String, Map<String, dynamic>>? featureMap, {
    Set<String>? visited,
    List<Map<String, dynamic>>? topLevelExtractedFeatures,
    bool isTopLevel = false,
  }) {
    if (node == null || featureMap == null || featureMap.isEmpty) return node;
    visited ??= <String>{};

    if (node is List) {
      final expandedList = <dynamic>[];
      for (final item in node) {
        if (item is Map &&
            (item['type'] == 'refSubclassFeature' ||
                item['type'] == 'refClassFeature' ||
                item.containsKey('subclassFeature') ||
                item.containsKey('classFeature'))) {
          final ptr = (item['subclassFeature'] ??
                  item['classFeature'] ??
                  item['name'] ??
                  '')
              .toString()
              .trim();
          final ptrKey = ptr.toLowerCase();
          if (ptrKey.isNotEmpty && !visited.contains(ptrKey)) {
            final child = _lookupFeature(item, featureMap);
            if (child != null) {
              final childName = child['name']?.toString().trim() ?? '';
              final childKey = childName.toLowerCase();
              if (!visited.contains(childKey)) {
                visited.add(ptrKey);
                visited.add(childKey);

                if (isTopLevel && topLevelExtractedFeatures != null) {
                  topLevelExtractedFeatures.add(child);
                  continue;
                } else {
                  final childEntries = _expandFeatureAst(
                    child['entries'] ??
                        child['entry'] ??
                        child['desc'] ??
                        child['description'],
                    featureMap,
                    visited: visited,
                    isTopLevel: false,
                  );
                  expandedList.add({
                    'name': childName,
                    if (childEntries != null) 'entries': childEntries,
                  });
                  continue;
                }
              }
            }
          }
        }
        expandedList.add(_expandFeatureAst(
          item,
          featureMap,
          visited: visited,
          topLevelExtractedFeatures: topLevelExtractedFeatures,
          isTopLevel: false,
        ));
      }
      return expandedList;
    } else if (node is Map) {
      final mapCopy = Map<String, dynamic>.from(node);
      for (final k in [
        'entries',
        'entry',
        'items',
        'options',
        'subentries',
        'features'
      ]) {
        if (mapCopy.containsKey(k)) {
          mapCopy[k] = _expandFeatureAst(
            mapCopy[k],
            featureMap,
            visited: visited,
            topLevelExtractedFeatures: topLevelExtractedFeatures,
            isTopLevel: false,
          );
        }
      }
      return mapCopy;
    }
    return node;
  }

  String _parseClassFeatures(
    Map<String, dynamic> raw,
    RulesetVersion ruleset,
    Map<String, Map<String, dynamic>>? classFeatureMap,
  ) {
    final features = raw['classFeatures'] ??
        raw['features'] ??
        raw['entries'] ??
        raw['desc'] ??
        raw['description'];
    if (features == null) return '';

    final featureBlocks = <String>[];
    final otherEntries = <dynamic>[];
    final renderedNames = <String>{};

    void processClassFeature(Map<String, dynamic> feat, {int? inheritedLevel}) {
      final isSubclass = feat['subclassShortName'] != null ||
          feat['subclass'] != null ||
          feat['gainSubclassFeature'] == true;
      if (isSubclass) return;

      final fName = feat['name']?.toString().trim() ?? '';
      if (fName.isEmpty) return;
      final fKey = fName.toLowerCase();
      if (renderedNames.contains(fKey)) return;
      renderedNames.add(fKey);

      final levelVal = feat['level'] ?? inheritedLevel;
      final levelStr = levelVal != null ? ' (Level $levelVal)' : '';

      final topLevelChildren = <Map<String, dynamic>>[];
      final rawEntries = feat['entries'] ??
          feat['entry'] ??
          feat['desc'] ??
          feat['description'];
      final expandedEntries = _expandFeatureAst(
        rawEntries,
        classFeatureMap,
        visited: {fKey},
        topLevelExtractedFeatures: topLevelChildren,
        isTopLevel: true,
      );

      final fContent = transformer
          .transformEntries(
            expandedEntries,
            defaultRuleset: ruleset,
          )
          .markdown;

      if (fContent.isNotEmpty) {
        featureBlocks.add('### $fName$levelStr\n$fContent');
      } else if (topLevelChildren.isEmpty) {
        featureBlocks.add('### $fName$levelStr');
      }

      for (final child in topLevelChildren) {
        final childLevel = (child['level'] as num?)?.toInt() ??
            (feat['level'] as num?)?.toInt() ??
            inheritedLevel;
        processClassFeature(child, inheritedLevel: childLevel);
      }
    }

    void processItem(dynamic f) {
      if (f is List) {
        for (final item in f) {
          processItem(item);
        }
        return;
      }
      if (f is String && (f.contains('|') || classFeatureMap != null)) {
        final resolved = _lookupFeature(f, classFeatureMap);
        if (resolved != null) {
          processClassFeature(resolved);
          return;
        }
        if (f.contains('|')) {
          final parts = f.split('|').map((p) => p.trim()).toList();
          final fName = parts.isNotEmpty ? parts[0] : '';
          final fClass = parts.length > 1 ? parts[1] : '';
          final fSource = parts.length > 2 ? parts[2] : '';
          final fLevel = parts.length > 3 ? int.tryParse(parts[3]) : null;
          final levelStr = fLevel != null ? ' (Level $fLevel)' : '';
          if (fName.isNotEmpty) {
            featureBlocks.add(
                '### $fName$levelStr\n*Source: $fSource • $fClass Feature*\n\nGranted to $fClass at level ${fLevel ?? 1}.');
          }
          return;
        }
      } else if (f is Map &&
          (f.containsKey('classFeature') || f.containsKey('subclassFeature'))) {
        if (f['gainSubclassFeature'] == true ||
            f['subclassShortName'] != null ||
            f['subclass'] != null) {
          return;
        }
        final resolved = _lookupFeature(f, classFeatureMap);
        if (resolved != null) {
          processClassFeature(resolved);
          return;
        }
      } else if (f is Map &&
          f.containsKey('name') &&
          (f.containsKey('entries') ||
              f.containsKey('desc') ||
              f.containsKey('description') ||
              f.containsKey('entry'))) {
        processClassFeature(Map<String, dynamic>.from(f));
        return;
      }
      otherEntries.add(f);
    }

    if (features is List) {
      for (final f in features) {
        processItem(f);
      }
    } else {
      otherEntries.add(features);
    }

    final parsedOther = transformer
        .transformEntries(otherEntries, defaultRuleset: ruleset)
        .markdown;
    final allParts = [
      if (parsedOther.isNotEmpty) parsedOther,
      ...featureBlocks,
    ];
    return allParts.join('\n\n').trim();
  }

  String _parseSubclassFeatures(
    dynamic entriesData,
    RulesetVersion ruleset,
    Map<String, Map<String, dynamic>>? subclassFeatureMap,
  ) {
    if (entriesData == null) return '';

    final featureBlocks = <String>[];
    final otherEntries = <dynamic>[];
    final renderedNames = <String>{};

    void processFeature(Map<String, dynamic> feat, {int? inheritedLevel}) {
      final fName = feat['name']?.toString().trim() ?? '';
      if (fName.isEmpty) return;
      final fKey = fName.toLowerCase();
      if (renderedNames.contains(fKey)) return;
      renderedNames.add(fKey);

      final levelVal = feat['level'] ?? inheritedLevel;
      final levelStr = levelVal != null ? ' (Level $levelVal)' : '';

      final topLevelChildren = <Map<String, dynamic>>[];
      final rawEntries = feat['entries'] ??
          feat['entry'] ??
          feat['desc'] ??
          feat['description'];
      final expandedEntries = _expandFeatureAst(
        rawEntries,
        subclassFeatureMap,
        visited: {fKey},
        topLevelExtractedFeatures: topLevelChildren,
        isTopLevel: true,
      );

      final fContent = transformer
          .transformEntries(
            expandedEntries,
            defaultRuleset: ruleset,
          )
          .markdown;

      if (fContent.isNotEmpty) {
        featureBlocks.add('### $fName$levelStr\n$fContent');
      } else if (topLevelChildren.isEmpty) {
        featureBlocks.add('### $fName$levelStr');
      }

      for (final child in topLevelChildren) {
        final childLevel = (child['level'] as num?)?.toInt() ??
            (feat['level'] as num?)?.toInt() ??
            inheritedLevel;
        processFeature(child, inheritedLevel: childLevel);
      }
    }

    void processItem(dynamic f) {
      if (f is List) {
        for (final item in f) {
          processItem(item);
        }
        return;
      }
      if (f is String && (f.contains('|') || subclassFeatureMap != null)) {
        final resolved = _lookupFeature(f, subclassFeatureMap);
        if (resolved != null) {
          processFeature(resolved);
          return;
        }
        if (f.contains('|')) {
          final parts = f.split('|').map((p) => p.trim()).toList();
          final fName = parts.isNotEmpty ? parts[0] : '';
          final fClass = parts.length > 1 ? parts[1] : '';
          final fSubShort = parts.length > 3 ? parts[3] : '';
          final fLevel = parts.length > 5
              ? int.tryParse(parts[5])
              : (parts.length > 3 ? int.tryParse(parts[3]) : null);
          final levelStr = fLevel != null ? ' (Level $fLevel)' : '';
          final subTitle = fSubShort.isNotEmpty
              ? fSubShort
              : (fClass.isNotEmpty ? '$fClass Subclass' : 'Subclass');
          if (fName.isNotEmpty) {
            featureBlocks.add(
                '### $fName$levelStr\n*$subTitle Feature*\n\nGranted at level ${fLevel ?? 1}.');
          }
          return;
        }
      } else if (f is Map &&
          (f.containsKey('subclassFeature') || f.containsKey('classFeature'))) {
        final resolved = _lookupFeature(f, subclassFeatureMap);
        if (resolved != null) {
          processFeature(resolved);
          return;
        }
        final rawEntries =
            f['entries'] ?? f['entry'] ?? f['desc'] ?? f['description'];
        final ptr = (f['subclassFeature'] ?? f['classFeature']).toString();
        if (rawEntries != null) {
          final ptrName = ptr.contains('|') ? ptr.split('|')[0].trim() : '';
          final fName = f['name']?.toString().trim() ??
              (ptrName.isNotEmpty ? ptrName : 'Feature');
          final level = f['level'] != null ? ' (Level ${f['level']})' : '';
          final fContent = transformer
              .transformEntries(rawEntries, defaultRuleset: ruleset)
              .markdown;
          if (fName.isNotEmpty || fContent.isNotEmpty) {
            featureBlocks.add('### $fName$level\n$fContent');
            return;
          }
        }
        if (ptr.contains('|')) {
          final parts = ptr.split('|').map((p) => p.trim()).toList();
          final fName = parts.isNotEmpty ? parts[0] : '';
          final fClass = parts.length > 1 ? parts[1] : '';
          final fSubShort = parts.length > 3 ? parts[3] : '';
          final fLevel = parts.length > 5
              ? int.tryParse(parts[5])
              : (parts.length > 3 ? int.tryParse(parts[3]) : null);
          final levelStr = fLevel != null ? ' (Level $fLevel)' : '';
          final subTitle = fSubShort.isNotEmpty
              ? fSubShort
              : (fClass.isNotEmpty ? '$fClass Subclass' : 'Subclass');
          if (fName.isNotEmpty) {
            featureBlocks.add(
                '### $fName$levelStr\n*$subTitle Feature*\n\nGranted at level ${fLevel ?? 1}.');
          }
          return;
        }
      } else if (f is Map &&
          f.containsKey('name') &&
          (f.containsKey('entries') ||
              f.containsKey('desc') ||
              f.containsKey('description') ||
              f.containsKey('entry'))) {
        processFeature(Map<String, dynamic>.from(f));
        return;
      }
      otherEntries.add(f);
    }

    if (entriesData is List) {
      for (final f in entriesData) {
        processItem(f);
      }
    } else {
      otherEntries.add(entriesData);
    }

    final parsedOther = transformer
        .transformEntries(otherEntries, defaultRuleset: ruleset)
        .markdown;
    final allParts = [
      if (parsedOther.isNotEmpty) parsedOther,
      ...featureBlocks,
    ];
    return allParts.join('\n\n').trim();
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _stripArchetypePrefix(String s) {
    return s
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'^(?:circle\s+of\s+(?:the\s+)?|oath\s+of\s+(?:the\s+)?|path\s+of\s+(?:the\s+)?|college\s+of\s+(?:the\s+)?|school\s+of\s+(?:the\s+)?|way\s+of\s+(?:the\s+)?|domain\s+of\s+(?:the\s+)?|order\s+of\s+(?:the\s+)?)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+domain$', caseSensitive: false), '')
        .trim();
  }

  RulesetVersion _mapSourceToRuleset(String? source) {
    if (source == null || source.isEmpty) return RulesetVersion.homebrew;
    final s = source.toUpperCase();
    if (s.contains('XPHB') || s.contains('SRD52') || s.contains('2024')) {
      return RulesetVersion.v2024;
    }
    if (s.contains('PHB') || s.contains('SRD') || s.contains('2014')) {
      return RulesetVersion.v2014;
    }
    return RulesetVersion.homebrew;
  }

  List<FeatureGrant> extractSpellsGrants(
      dynamic addSpellsData, String ownerPrefix, String ownerSlug) {
    if (addSpellsData == null) return <FeatureGrant>[];
    final grants = <FeatureGrant>[];
    final seenSlugs = <String>{};

    void processSpellItem(dynamic item) {
      if (item == null) return;
      if (item is String) {
        final clean = item.split('|').first.replaceAll('#c', '').trim();
        if (clean.isNotEmpty && !clean.startsWith('{')) {
          final slug = _slugify(clean);
          if (slug.isNotEmpty && seenSlugs.add(slug)) {
            grants.add(FeatureGrant.bonusSpell(
              grantId: '$ownerPrefix-$ownerSlug-spell-$slug',
              slug: slug,
              displayName: clean,
              label: clean,
            ));
          }
        }
      } else if (item is List) {
        for (final subItem in item) {
          processSpellItem(subItem);
        }
      } else if (item is Map) {
        for (final entry in item.entries) {
          final k = entry.key.toString().toLowerCase();
          if (k == 'choose' || k == 'count' || k == 'all') continue;
          processSpellItem(entry.value);
        }
      }
    }

    void processSpellGroup(dynamic group) {
      if (group == null) return;
      if (group is List) {
        for (final item in group) {
          processSpellGroup(item);
        }
      } else if (group is Map) {
        bool hadKnownSubkey = false;
        for (final key in [
          'prepared',
          'expanded',
          'innate',
          'known',
          'spells'
        ]) {
          if (group.containsKey(key)) {
            hadKnownSubkey = true;
            processSpellItem(group[key]);
          }
        }
        if (!hadKnownSubkey) {
          for (final entry in group.entries) {
            final k = entry.key.toString().toLowerCase();
            if (k == 'name' ||
                k == 'source' ||
                k == 'class' ||
                k == 'subclass' ||
                k == 'choose' ||
                k == 'count' ||
                k == 'all') {
              continue;
            }
            processSpellItem(entry.value);
          }
        }
      } else if (group is String) {
        processSpellItem(group);
      }
    }

    processSpellGroup(addSpellsData);
    return grants;
  }

  /// Extracts allowed skills and choice count from class definitions across
  /// community compendium schemas, startingProficiencies, direct properties, and text features.
  static ({List<String> allowedSkills, int skillChoiceCount}) parseClassSkills(
      Map<String, dynamic> raw) {
    final allowed = <String>{};
    int choiceCount = 2;
    bool allowsAny = false;

    if (raw['skillChoiceCount'] is num) {
      choiceCount = (raw['skillChoiceCount'] as num).toInt();
    }
    if (raw['allowedSkills'] is List) {
      for (final s in raw['allowedSkills'] as List) {
        final st = SkillType.tryParse(s.toString());
        if (st != null) allowed.add(st.name);
      }
    }

    final sp = raw['startingProficiencies'] ??
        (raw['proficiencies'] is Map ? raw['proficiencies'] : null);
    dynamic skillsData;
    if (sp is Map) {
      skillsData = sp['skills'] ?? sp['skill'];
    } else if (raw.containsKey('skills')) {
      skillsData = raw['skills'];
    }

    void extractSkills(dynamic data) {
      if (data == null) return;
      if (data is String) {
        final tagMatches = RegExp(r'\{@skill\s+([^}]+)\}').allMatches(data);
        if (tagMatches.isNotEmpty) {
          for (final m in tagMatches) {
            final st = SkillType.tryParse(m.group(1));
            if (st != null) allowed.add(st.name);
          }
        } else {
          final st = SkillType.tryParse(data);
          if (st != null) {
            allowed.add(st.name);
          } else {
            for (final s in SkillType.values) {
              final reg = RegExp('\\b${RegExp.escape(s.displayName)}\\b',
                  caseSensitive: false);
              if (reg.hasMatch(data)) {
                allowed.add(s.name);
              }
            }
          }
        }
      } else if (data is List) {
        for (final item in data) {
          extractSkills(item);
        }
      } else if (data is Map) {
        if (data.containsKey('any')) {
          allowsAny = true;
          if (data['any'] is num) {
            choiceCount = (data['any'] as num).toInt();
          }
        }
        if (data.containsKey('count') && data['count'] is num) {
          choiceCount = (data['count'] as num).toInt();
        }
        if (data.containsKey('choose')) {
          final ch = data['choose'];
          if (ch is Map) {
            if (ch['count'] is num) {
              choiceCount = (ch['count'] as num).toInt();
            }
            if (ch['from'] != null) {
              extractSkills(ch['from']);
            }
          }
        }
        if (data.containsKey('from')) {
          extractSkills(data['from']);
        }
      }
    }

    if (skillsData != null) {
      extractSkills(skillsData);
    }

    // Inspect class features if allowed skills are still empty
    if (allowed.isEmpty && !allowsAny) {
      final features = raw['classFeatures'] ?? raw['entries'] ?? raw['desc'];
      if (features != null) {
        final text = features.toString();
        final match = RegExp(
                r'Skills:\s*Choose\s+(\w+)\s+(?:skills?\s+)?from\s+([^.]+)\.',
                caseSensitive: false)
            .firstMatch(text);
        if (match != null) {
          final word = match.group(1)?.toLowerCase() ?? '';
          choiceCount = switch (word) {
            'one' => 1,
            'two' => 2,
            'three' => 3,
            'four' => 4,
            _ => int.tryParse(word) ?? choiceCount,
          };
          final listPart = match.group(2) ?? '';
          for (final st in SkillType.values) {
            final reg = RegExp('\\b${RegExp.escape(st.displayName)}\\b',
                caseSensitive: false);
            if (reg.hasMatch(listPart)) {
              allowed.add(st.name);
            }
          }
        }
      }
    }

    // Archetype fallbacks for known classes if allowed skills could not be extracted
    final rawName = (raw['name'] ?? raw['id'] ?? raw['slug'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (allowed.isEmpty && !allowsAny) {
      if (rawName.contains('warrior sidekick') ||
          rawName == 'warrior-sidekick') {
        allowed.addAll([
          SkillType.acrobatics.name,
          SkillType.animalHandling.name,
          SkillType.athletics.name,
          SkillType.intimidation.name,
          SkillType.nature.name,
          SkillType.perception.name,
          SkillType.survival.name,
        ]);
        choiceCount = 1;
      } else if (rawName.contains('spellcaster sidekick') ||
          rawName == 'spellcaster-sidekick') {
        allowed.addAll([
          SkillType.arcana.name,
          SkillType.history.name,
          SkillType.insight.name,
          SkillType.investigation.name,
          SkillType.medicine.name,
          SkillType.performance.name,
          SkillType.religion.name,
          SkillType.survival.name,
        ]);
        choiceCount = 2;
      }
    }

    if (allowsAny || allowed.isEmpty) {
      return (
        allowedSkills: SkillType.values.map((s) => s.name).toList(),
        skillChoiceCount: choiceCount,
      );
    }

    return (
      allowedSkills: allowed.toList(),
      skillChoiceCount: choiceCount,
    );
  }
}
