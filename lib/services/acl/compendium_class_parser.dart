import '../../models/domain/core_types.dart';
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
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Hit Die
    final hitDie = _parseHitDie(raw['hd'] ?? raw['hitDie']);

    // Saving Throw Proficiencies
    final savingThrows = _parseSavingThrows(raw['proficiency'] ?? raw['savingThrows']);

    // Armor and Weapon Proficiencies
    final armorProficiencies = <String>[];
    final weaponProficiencies = <String>[];
    if (raw['startingProficiencies'] is Map) {
      final sp = raw['startingProficiencies'] as Map;
      if (sp['armor'] is List) {
        armorProficiencies.addAll((sp['armor'] as List).map((e) => e.toString()));
      }
      if (sp['weapons'] is List) {
        weaponProficiencies.addAll((sp['weapons'] as List).map((e) => e.toString()));
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

    final subclassSelectionLevel = (raw['subclassSelectionLevel'] as num?)?.toInt() ??
        (raw['subclassLevel'] as num?)?.toInt() ??
        (ruleset == RulesetVersion.v2014 && ['cleric', 'sorcerer', 'warlock'].contains(slug)
            ? 1
            : ruleset == RulesetVersion.v2014 && ['druid', 'wizard'].contains(slug)
                ? 2
                : 3);

    // Feature Decisions
    final featureDecisions = <ClassFeatureDecision>[];
    if (raw['featureDecisions'] is List) {
      for (final dec in raw['featureDecisions']) {
        if (dec is Map) {
          try {
            featureDecisions.add(ClassFeatureDecision.fromMap(Map<String, dynamic>.from(dec)));
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
      customProperties['spellsKnownProgression'] = raw['spellsKnownProgression'];
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
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ??
        raw['subclassSource']?.toString().toUpperCase() ??
        raw['classSource']?.toString().toUpperCase() ??
        'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    String classSlug = '';
    if (raw['className'] != null && raw['className'].toString().isNotEmpty) {
      classSlug = _slugify(raw['className'].toString());
    } else if (raw['class'] != null) {
      if (raw['class'] is Map) {
        classSlug = _slugify((raw['class'] as Map)['name']?.toString() ?? '');
      } else {
        classSlug = _slugify(raw['class'].toString());
      }
    } else if (raw['classSlug'] != null && raw['classSlug'].toString().isNotEmpty) {
      classSlug = _slugify(raw['classSlug'].toString());
    } else if (defaultClassSlug != null && defaultClassSlug.isNotEmpty) {
      classSlug = _slugify(defaultClassSlug);
    }

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

    final featuresMarkdown = _parseSubclassFeatures(entriesData, ruleset, subclassFeatureMap);

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

    return Subclass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      classSlug: classSlug,
      shortName: shortName,
      featuresMarkdown: featuresMarkdown,
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

  Map<String, dynamic>? _lookupFeature(dynamic ptr, Map<String, Map<String, dynamic>>? featureMap) {
    if (featureMap == null || featureMap.isEmpty) return null;
    String pointerStr = '';
    if (ptr is String) {
      pointerStr = ptr.trim();
    } else if (ptr is Map) {
      pointerStr = (ptr['classFeature'] ?? ptr['subclassFeature'] ?? ptr['feature'] ?? '').toString().trim();
    }
    if (pointerStr.isEmpty) return null;

    final lower = pointerStr.toLowerCase();
    if (featureMap.containsKey(lower)) {
      return featureMap[lower];
    }
    final parts = lower.split('|').map((p) => p.trim()).toList();
    if (parts.isNotEmpty) {
      final name = parts[0];
      if (parts.length >= 4) {
        final c1 = '$name|${parts[1]}|${parts[3]}';
        if (featureMap.containsKey(c1)) return featureMap[c1];
        final c2 = '$name|${parts[1]}|${parts[2]}|${parts[3]}';
        if (featureMap.containsKey(c2)) return featureMap[c2];
      }
      if (parts.length >= 2) {
        final c3 = '$name|${parts[1]}';
        if (featureMap.containsKey(c3)) return featureMap[c3];
      }
      if (featureMap.containsKey(name)) {
        return featureMap[name];
      }
    }
    return null;
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
          final fName = resolved['name']?.toString() ?? '';
          final level = resolved['level'] != null ? ' (Level ${resolved['level']})' : '';
          final fContent = transformer.transformEntries(
            resolved['entries'] ?? resolved['entry'] ?? resolved['desc'] ?? resolved['description'],
            defaultRuleset: ruleset,
          ).markdown;
          if (fName.isNotEmpty || fContent.isNotEmpty) {
            featureBlocks.add('### $fName$level\n$fContent');
          }
          return;
        }
        if (f.contains('|') && !f.contains(' ')) {
          return;
        }
      } else if (f is Map && (f.containsKey('classFeature') || f.containsKey('subclassFeature'))) {
        final resolved = _lookupFeature(f, classFeatureMap);
        if (resolved != null) {
          final fName = resolved['name']?.toString() ?? '';
          final level = resolved['level'] != null ? ' (Level ${resolved['level']})' : '';
          final fContent = transformer.transformEntries(
            resolved['entries'] ?? resolved['entry'] ?? resolved['desc'] ?? resolved['description'],
            defaultRuleset: ruleset,
          ).markdown;
          if (fName.isNotEmpty || fContent.isNotEmpty) {
            featureBlocks.add('### $fName$level\n$fContent');
          }
          return;
        }
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

    final parsedOther = transformer.transformEntries(otherEntries, defaultRuleset: ruleset).markdown;
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
          final fName = resolved['name']?.toString() ?? '';
          final level = resolved['level'] != null ? ' (Level ${resolved['level']})' : '';
          final fContent = transformer.transformEntries(
            resolved['entries'] ?? resolved['entry'] ?? resolved['desc'] ?? resolved['description'],
            defaultRuleset: ruleset,
          ).markdown;
          if (fName.isNotEmpty || fContent.isNotEmpty) {
            featureBlocks.add('### $fName$level\n$fContent');
          }
          return;
        }
        if (f.contains('|') && !f.contains(' ')) {
          return;
        }
      } else if (f is Map && (f.containsKey('subclassFeature') || f.containsKey('classFeature'))) {
        final resolved = _lookupFeature(f, subclassFeatureMap);
        if (resolved != null) {
          final fName = resolved['name']?.toString() ?? '';
          final level = resolved['level'] != null ? ' (Level ${resolved['level']})' : '';
          final fContent = transformer.transformEntries(
            resolved['entries'] ?? resolved['entry'] ?? resolved['desc'] ?? resolved['description'],
            defaultRuleset: ruleset,
          ).markdown;
          if (fName.isNotEmpty || fContent.isNotEmpty) {
            featureBlocks.add('### $fName$level\n$fContent');
          }
          return;
        }
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

    final parsedOther = transformer.transformEntries(otherEntries, defaultRuleset: ruleset).markdown;
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
}
