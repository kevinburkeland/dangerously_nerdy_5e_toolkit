import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_node_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Classes & Subclasses.
class CompendiumClassParser {
  final EntryNodeTransformer transformer;

  CompendiumClassParser({EntryNodeTransformer? transformer})
      : transformer = transformer ?? EntryNodeTransformer();

  /// Transforms a raw community compendium or homebrew class JSON map into a strongly-typed [CharacterClass].
  CharacterClass parseClass(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
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
    final featuresMarkdown = _parseClassFeatures(raw, ruleset);

    // Subclasses
    final subclasses = <Subclass>[];
    final rawSubList = raw['subclasses'] ?? raw['subclass'];
    if (rawSubList is List) {
      for (final rawSub in rawSubList) {
        if (rawSub is Map) {
          try {
            subclasses.add(parseSubclass(Map<String, dynamic>.from(rawSub), defaultClassSlug: slug, forceRuleset: ruleset));
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

    dynamic cleanedEntries = entriesData;
    if (cleanedEntries is List) {
      final flattened = <dynamic>[];
      for (final item in cleanedEntries) {
        if (item is List) {
          flattened.addAll(item);
        } else {
          flattened.add(item);
        }
      }
      cleanedEntries = flattened;
    }

    final parsedEntries = transformer.transformEntries(
      cleanedEntries,
      defaultRuleset: ruleset,
    );

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
      featuresMarkdown: parsedEntries.markdown,
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

  String _parseClassFeatures(Map<String, dynamic> raw, RulesetVersion ruleset) {
    final features = raw['classFeatures'] ?? raw['features'] ?? raw['entries'] ?? raw['desc'] ?? raw['description'];
    if (features == null) return '';

    // Convert pipe-syntax cross references to null while retaining any real description entries
    final cleaned = features is List
        ? features.map((f) {
            if (f is String && f.contains('|') && !f.contains(' ')) return null;
            return f;
          }).where((f) => f != null).toList()
        : features;

    return transformer.transformEntries(cleaned, defaultRuleset: ruleset).markdown;
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
