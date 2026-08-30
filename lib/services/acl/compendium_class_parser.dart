import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import 'entry_tag_transformer.dart';

/// Anti-Corruption Layer (ACL) dedicated transformer for Community Compendium and Homebrew Classes & Subclasses.
class CompendiumClassParser {
  final EntryTagTransformer transformer;

  CompendiumClassParser({EntryTagTransformer? transformer})
      : transformer = transformer ?? EntryTagTransformer();

  /// Transforms a raw community compendium or homebrew class JSON map into a strongly-typed [CharacterClass].
  CharacterClass parseClass(Map<String, dynamic> raw, {RulesetVersion? forceRuleset}) {
    final name = raw['name']?.toString().trim() ?? 'Unnamed Class';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    // Hit Die
    final hitDie = _parseHitDie(raw['hd']);

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
    if (raw['subclasses'] is List) {
      for (final rawSub in raw['subclasses']) {
        if (rawSub is Map<String, dynamic>) {
          try {
            subclasses.add(parseSubclass(rawSub, defaultClassSlug: slug, forceRuleset: ruleset));
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
        if (dec is Map<String, dynamic>) {
          try {
            featureDecisions.add(ClassFeatureDecision.fromMap(dec));
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
    final name = raw['name']?.toString().trim() ?? 'Unnamed Subclass';
    final slug = _slugify(name);
    final source = raw['source']?.toString().toUpperCase() ?? 'PHB';
    final ruleset = forceRuleset ?? _mapSourceToRuleset(source);

    final classSlug = raw['className'] != null
        ? _slugify(raw['className'].toString())
        : (raw['classSlug']?.toString() ?? defaultClassSlug ?? '');

    final shortName = raw['shortName']?.toString() ??
        raw['subclassTitle']?.toString() ??
        name;

    final parsedEntries = transformer.transformEntries(
      raw['subclassFeatures'] ?? raw['entries'],
      defaultRuleset: ruleset,
    );

    final customProperties = <String, dynamic>{};
    raw.forEach((key, value) {
      if (!_standardSubclassKeys.contains(key)) {
        customProperties[key] = value;
      }
    });

    if (raw.containsKey('subclassFeatures')) {
      customProperties['subclassFeatures'] = raw['subclassFeatures'];
    }
    if (raw.containsKey('subclassTableGroups')) {
      customProperties['subclassTableGroups'] = raw['subclassTableGroups'];
    }
    if (raw.containsKey('spellcastingAbility')) {
      customProperties['spellcastingAbility'] = raw['spellcastingAbility'];
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
    'proficiency',
    'savingThrows',
    'primaryAbility',
    'spellcastingAbility',
    'classFeatures',
    'entries',
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
    'entries',
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
    final features = raw['classFeatures'] ?? raw['entries'];
    if (features == null) return '';

    if (features is List) {
      final buffer = StringBuffer();
      for (final f in features) {
        if (f is String) {
          buffer.writeln(f);
          buffer.writeln();
        } else if (f is Map<String, dynamic>) {
          final title = f['name']?.toString();
          if (title != null && title.isNotEmpty) {
            buffer.writeln('### $title');
          }
          final parsed = transformer.transformEntries(f['entries'] ?? f, defaultRuleset: ruleset);
          buffer.writeln(parsed.markdown);
          buffer.writeln();
        }
      }
      return buffer.toString().trim();
    }

    return transformer.transformEntries(features, defaultRuleset: ruleset).markdown;
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
