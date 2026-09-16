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

    final parsedSkills = parseClassSkills(raw);
    customProperties['allowedSkills'] = parsedSkills.allowedSkills;
    customProperties['skillChoiceCount'] = parsedSkills.skillChoiceCount;

    final grants = extractSpellsGrants(
      raw['additionalSpells'] ?? raw['spells'],
      'class',
      slug,
    );

    if (raw['startingProficiencies'] is Map) {
      final sp = raw['startingProficiencies'] as Map;
      if (sp['tools'] is List) {
        for (final t in sp['tools'] as List) {
          final tStr = t.toString().trim();
          if (tStr.isNotEmpty) {
            grants.add(FeatureGrant.weaponArmorProficiency(
              tStr,
              grantId: 'class-$slug-tool-${tStr.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-")}',
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

    final grants = extractSpellsGrants(
      raw['additionalSpells'] ?? raw['subclassSpells'],
      'subclass',
      slug,
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
          final isSubclass = resolved['subclassShortName'] != null ||
              resolved['subclass'] != null ||
              resolved['gainSubclassFeature'] == true;
          if (isSubclass) return;

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
        if (f['gainSubclassFeature'] == true ||
            f['subclassShortName'] != null ||
            f['subclass'] != null) {
          return;
        }
        final resolved = _lookupFeature(f, classFeatureMap);
        if (resolved != null) {
          final isSubclass = resolved['subclassShortName'] != null ||
              resolved['subclass'] != null ||
              resolved['gainSubclassFeature'] == true;
          if (isSubclass) return;

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

  List<FeatureGrant> extractSpellsGrants(dynamic addSpellsData, String ownerPrefix, String ownerSlug) {
    if (addSpellsData == null) return const [];
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
        for (final key in ['prepared', 'expanded', 'innate', 'known', 'spells']) {
          if (group.containsKey(key)) {
            hadKnownSubkey = true;
            processSpellItem(group[key]);
          }
        }
        if (!hadKnownSubkey) {
          for (final entry in group.entries) {
            final k = entry.key.toString().toLowerCase();
            if (k == 'name' || k == 'source' || k == 'class' || k == 'subclass' || k == 'choose' || k == 'count' || k == 'all') {
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
  /// 5eTools schemas, startingProficiencies, direct properties, and text features.
  static ({List<String> allowedSkills, int skillChoiceCount}) parseClassSkills(Map<String, dynamic> raw) {
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

    final sp = raw['startingProficiencies'] ?? raw['proficiency'] ?? raw['proficiencies'];
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
              final reg = RegExp('\\b${RegExp.escape(s.displayName)}\\b', caseSensitive: false);
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
        final match = RegExp(r'Skills:\s*Choose\s+(\w+)\s+(?:skills?\s+)?from\s+([^.]+)\.', caseSensitive: false).firstMatch(text);
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
            final reg = RegExp('\\b${RegExp.escape(st.displayName)}\\b', caseSensitive: false);
            if (reg.hasMatch(listPart)) {
              allowed.add(st.name);
            }
          }
        }
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
