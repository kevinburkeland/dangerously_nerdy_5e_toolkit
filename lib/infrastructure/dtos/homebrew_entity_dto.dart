import 'package:meta/meta.dart';
import 'package:vtt_engine_core/homebrew/models/homebrew_entity.dart';
import 'package:vtt_engine_core/homebrew/value_objects/ruleset_version.dart';

/// Validation exception thrown when homebrew schema violates ruleset contracts.
class HomebrewValidationException implements Exception {
  final String message;
  final String? path;

  const HomebrewValidationException(this.message, {this.path});

  @override
  String toString() => path != null
      ? 'HomebrewValidationException: $message ($path)'
      : 'HomebrewValidationException: $message';
}

/// Data Transfer Object for homebrew entities.
///
/// Implements strict Anti-Corruption Layer (ACL) validation against pre-selected
/// [RulesetVersion], bounds-clamps numeric stats, and preserves unparsed fields.
/// PURE DART: ZERO FLUTTER RUNTIME DEPENDENCIES.
@immutable
class HomebrewEntityDto {
  final String id;
  final String name;
  final String entityType;
  final RulesetVersion ruleset;
  final Map<String, dynamic> rawPayload;
  final Map<String, dynamic> normalizedData;
  final Map<String, dynamic> unparsedPayload;

  const HomebrewEntityDto({
    required this.id,
    required this.name,
    required this.entityType,
    required this.ruleset,
    this.rawPayload = const {},
    this.normalizedData = const {},
    this.unparsedPayload = const {},
  });

  /// Validates and parses incoming JSON strictly against [ruleset].
  ///
  /// Throws [HomebrewValidationException] on cross-ruleset violations or schema defects.
  factory HomebrewEntityDto.fromJson(
    Map<String, dynamic> json, {
    required RulesetVersion ruleset,
    String? sourcePath,
  }) {
    // 1. Mandatory Name Validation with fallback fields (title, label, header)
    final rawName =
        (json['name'] ?? json['title'] ?? json['label'] ?? json['header'])
            ?.toString()
            .trim();
    if (rawName == null || rawName.isEmpty) {
      throw HomebrewValidationException(
        'Entity is missing a valid "name" attribute.',
        path: sourcePath,
      );
    }

    // 2. Explicit Ruleset Mismatch Detection
    final declaredRuleset = json['ruleset']?.toString().toLowerCase();
    if (declaredRuleset != null) {
      if (ruleset == RulesetVersion.srd2014 &&
          (declaredRuleset.contains('2024') ||
              declaredRuleset.contains('5.2') ||
              declaredRuleset.contains('xphb'))) {
        throw HomebrewValidationException(
          'Entity declared ruleset "$declaredRuleset" collides with required 2014 SRD 5.1 target.',
          path: sourcePath,
        );
      }
      if (ruleset == RulesetVersion.srd2024 &&
          (declaredRuleset.contains('2014') ||
              declaredRuleset.contains('5.1') ||
              declaredRuleset.contains('phb14'))) {
        throw HomebrewValidationException(
          'Entity declared ruleset "$declaredRuleset" collides with required 2024 SRD 5.2.1 target.',
          path: sourcePath,
        );
      }
    }

    // 3. Entity Classification
    final entityType = _detectEntityType(json);

    // 4. Strict Ruleset Mechanical Boundary Enforcement
    if (ruleset == RulesetVersion.srd2014) {
      _validateSrd2014Contract(json, entityType, sourcePath);
    } else {
      _validateSrd2024Contract(json, entityType, sourcePath);
    }

    // 5. Bounds Clamping & Normalization
    final normalized = _normalizeAndClamp(json, entityType);

    // 6. Unparsed Payload Preservation (Directive 4)
    final recognizedKeys = {
      'id',
      'name',
      'entityType',
      'type',
      'source',
      'ruleset',
      'level',
      'school',
      'time',
      'duration',
      'range',
      'cr',
      'hp',
      'hitDice',
      'ac',
      'speed',
      'abilities',
      'str',
      'dex',
      'con',
      'int',
      'wis',
      'cha',
      'rarity',
      'itemType',
      'weaponMastery',
      'mastery',
      'masteryProperties',
      'traits',
      'actions',
      'bonusActions',
      'reactions',
      'spells',
      'originFeat',
      'asi',
      'ability',
      'abilityScoreIncrease',
      'raceName',
      'subrace',
      'subraces',
      'flexibleAbilities',
      'startingProficiencies',
      'proficiencyChoices',
      'flexibleSkills',
      'skillProficiencies',
      'allowedSkills',
      'skillChoiceCount',
      'classFeatures',
      'hitDie',
      'hd',
      'savingThrows',
      'proficiency',
      'armorProficiencies',
      'toolProficiencies',
      'weaponProficiencies',
      'prerequisite',
      'prereq',
      'featuresMarkdown',
      'shortName',
      'classSlug',
      'grants',
      'customProperties',
    };

    final unparsed = <String, dynamic>{};
    json.forEach((k, v) {
      if (!recognizedKeys.contains(k)) {
        unparsed[k] = v;
      }
    });

    final id =
        json['id']?.toString() ?? json['slug']?.toString() ?? _slugify(rawName);

    return HomebrewEntityDto(
      id: id,
      name: rawName,
      entityType: entityType,
      ruleset: ruleset,
      rawPayload: Map<String, dynamic>.from(json),
      normalizedData: normalized,
      unparsedPayload: unparsed,
    );
  }

  static void _validateSrd2014Contract(
    Map<String, dynamic> json,
    String entityType,
    String? sourcePath,
  ) {
    // 2014 RAW rejects Weapon Masteries
    if (json.containsKey('weaponMastery') ||
        json.containsKey('mastery') ||
        json.containsKey('weaponMasteries') ||
        json.containsKey('masteryProperties')) {
      final masteryVal =
          json['weaponMastery'] ?? json['mastery'] ?? json['weaponMasteries'];
      if (masteryVal != null && masteryVal != false && masteryVal != '') {
        throw HomebrewValidationException(
          'Weapon Mastery declarations (2024 SRD) are strictly prohibited under 2014 SRD rules.',
          path: sourcePath,
        );
      }
    }

    // 2014 RAW rejects non-discrete exhaustion models (10 tiers or linear d20 penalties)
    final exhaustion = json['exhaustion'] ?? json['exhaustionRules'];
    if (exhaustion != null) {
      if (exhaustion == 'linear' ||
          (exhaustion is Map && exhaustion['type'] == 'linear') ||
          json['maxExhaustion'] == 10 ||
          json['exhaustionSteps'] == 10) {
        throw HomebrewValidationException(
          'Linear 10-step exhaustion models (2024 SRD) are prohibited under 2014 SRD rules (discrete 6-tier required).',
          path: sourcePath,
        );
      }
    }

    // In 2014, Backgrounds do not grant Ability Score Increases or Origin Feats;
    // 2014 backgrounds from community compendiums/GitHub often contain optional or null 'ability' tags.
    // Our CharacterValidationEngine and CharacterFactory already enforce ASI bifurcation (stripping
    // background ASIs and origin feats in 2014 mode), so we do not reject the entity at the ingestion boundary.
  }

  static void _validateSrd2024Contract(
    Map<String, dynamic> json,
    String entityType,
    String? sourcePath,
  ) {
    // 2024 rejects legacy bonus-action spell restriction clauses
    if (json['legacyBonusActionSpellRule'] == true ||
        json['bonusActionSpellRestriction'] == true) {
      throw HomebrewValidationException(
        'Legacy bonus-action spell restrictions are invalid under 2024 SRD 5.2.1 rules.',
        path: sourcePath,
      );
    }

    // In 2024, Species/Races/Subraces MUST NOT define Ability Score Increases (ASIs belong to Backgrounds)
    if (entityType == 'race' ||
        entityType == 'species' ||
        entityType == 'subrace') {
      if (json.containsKey('asi') ||
          json.containsKey('ability') ||
          json.containsKey('abilityScoreIncrease')) {
        final asiVal =
            json['asi'] ?? json['ability'] ?? json['abilityScoreIncrease'];
        if (asiVal != null && asiVal is! bool && asiVal != '') {
          throw HomebrewValidationException(
            'Species / Race cannot define Ability Score Increases in 2024 SRD (ASIs must be granted by Background).',
            path: sourcePath,
          );
        }
      }
    }
  }

  static String _detectEntityType(Map<String, dynamic> json) {
    // 1. Signature keys that uniquely identify monsters
    if (json.containsKey('cr') ||
        json.containsKey('challengeRating') ||
        json.containsKey('hitDice')) {
      return 'monster';
    }

    // 2. Explicit entityType attribute
    final explicitEntityType = json['entityType']?.toString().toLowerCase();
    if (explicitEntityType != null && explicitEntityType.isNotEmpty) {
      return switch (explicitEntityType) {
        'spell' => 'spell',
        'monster' || 'creature' || 'npc' || 'bestiary' => 'monster',
        'item' ||
        'equipment' ||
        'magicitem' ||
        'weapon' ||
        'armor' =>
          'equipment',
        'class' || 'classdefinition' => 'class',
        'subclass' => 'subclass',
        'subrace' => 'subrace',
        'race' || 'species' => 'race',
        'feat' => 'feat',
        'background' => 'background',
        _ => explicitEntityType,
      };
    }

    // 3. Inspect type attribute (which in standard compendiums can be creature type or item type code)
    final explicitType = json['type'];
    String? typeStr;
    if (explicitType is String) {
      typeStr = explicitType.toLowerCase().trim();
    } else if (explicitType is Map) {
      typeStr = explicitType['type']?.toString().toLowerCase().trim();
    }

    if (typeStr != null && typeStr.isNotEmpty) {
      // 5e standard creature types
      const creatureTypes = {
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

      if (creatureTypes.contains(typeStr) ||
          typeStr == 'monster' ||
          typeStr == 'creature' ||
          typeStr == 'npc' ||
          typeStr == 'bestiary') {
        return 'monster';
      }

      if (typeStr == 'spell') return 'spell';
      if (typeStr == 'item' ||
          typeStr == 'equipment' ||
          typeStr == 'magicitem' ||
          typeStr == 'weapon' ||
          typeStr == 'armor') {
        return 'equipment';
      }
      if (typeStr == 'class') return 'class';
      if (typeStr == 'subclass') return 'subclass';
      if (typeStr == 'race' || typeStr == 'species' || typeStr == 'subrace')
        return 'race';
      if (typeStr == 'feat') return 'feat';
      if (typeStr == 'background') return 'background';
    }

    // 4. Heuristic inference based on signature schema keys
    if (json.containsKey('school') ||
        (json.containsKey('level') && json.containsKey('time'))) {
      return 'spell';
    }
    if (json.containsKey('rarity') ||
        json.containsKey('itemType') ||
        json.containsKey('weaponCategory')) {
      return 'equipment';
    }
    if (json.containsKey('subclassFeature') ||
        json.containsKey('gainSubclassFeature') ||
        (json.containsKey('subclassShortName') &&
            !json.containsKey('subclassFeatures'))) {
      return 'subclassfeature';
    }
    if (json.containsKey('classFeature') ||
        (json.containsKey('className') &&
            json.containsKey('level') &&
            !json.containsKey('hitDie') &&
            !json.containsKey('hd') &&
            !json.containsKey('subclassFeatures') &&
            !json.containsKey('subclasses') &&
            !json.containsKey('shortName') &&
            !json.containsKey('subclassTitle'))) {
      return 'classfeature';
    }
    if (json.containsKey('subclassFeatures')) {
      return 'subclass';
    }
    if (json.containsKey('hitDie') ||
        json.containsKey('classFeatures') ||
        json.containsKey('startingProficiencies')) {
      return 'class';
    }
    if (json.containsKey('raceName') || json.containsKey('subrace')) {
      return 'race';
    }
    if (json.containsKey('speed') &&
        (json.containsKey('size') || json.containsKey('subraces'))) {
      return 'race';
    }
    if (json.containsKey('prerequisite') ||
        json.containsKey('prereq') ||
        json.containsKey('originFeat') ||
        json.containsKey('category') ||
        json.containsKey('repeatable') ||
        (json.containsKey('toolProficiencies') &&
            !json.containsKey('startingProficiencies')) ||
        (json.containsKey('armorProficiencies') &&
            !json.containsKey('hitDie')) ||
        (json.containsKey('weaponProficiencies') &&
            !json.containsKey('hitDie'))) {
      return 'feat';
    }
    if (json.containsKey('startingEquipment') ||
        json.containsKey('featureName')) {
      return 'background';
    }

    return typeStr ?? 'custom';
  }

  static Map<String, dynamic> _normalizeAndClamp(
      Map<String, dynamic> json, String entityType) {
    final normalized = Map<String, dynamic>.from(json);

    // HP Clamping: 0..999
    if (normalized.containsKey('hp')) {
      final hpVal = normalized['hp'];
      if (hpVal is num) {
        normalized['hp'] = hpVal.toInt().clamp(0, 999);
      } else if (hpVal is Map && hpVal.containsKey('average')) {
        final avg = (hpVal['average'] as num?)?.toInt() ?? 10;
        normalized['hp'] = avg.clamp(0, 999);
      }
    }

    // Level Clamping: 1..20 (for spells 0..9)
    if (normalized.containsKey('level')) {
      final lvl = (normalized['level'] as num?)?.toInt();
      if (lvl != null) {
        if (entityType == 'spell') {
          normalized['level'] = lvl.clamp(0, 9);
        } else {
          normalized['level'] = lvl.clamp(1, 20);
        }
      }
    }

    // Ability Scores: 1..30
    for (final ability in ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
      if (normalized.containsKey(ability)) {
        final score = (normalized[ability] as num?)?.toInt();
        if (score != null) {
          normalized[ability] = score.clamp(1, 30);
        }
      }
    }

    // Species / Race / Subrace Ability Extractions (Fixed and Flexible Choice Pools)
    if (entityType == 'race' ||
        entityType == 'species' ||
        entityType == 'subrace') {
      final speciesAbilities = _extractSpeciesAbilities(json);
      if (speciesAbilities.fixed.isNotEmpty) {
        normalized['abilities'] = speciesAbilities.fixed;
      }
      if (speciesAbilities.flexible != null) {
        normalized['flexibleAbilities'] = speciesAbilities.flexible;
      }
    }

    // Background Ingestion: Skills, Starting Equipment, and 2024 ASIs
    if (entityType == 'background') {
      // 1. Skill Proficiencies
      final skillsRaw = normalized['skillProficiencies'] ??
          normalized['skills'] ??
          normalized['skill'];
      if (skillsRaw is List) {
        normalized['skillProficiencies'] = skillsRaw
            .where((s) => s != null)
            .map((s) => s.toString().trim())
            .toList();
      }

      // 2. Starting Equipment
      final equipRaw = normalized['startingEquipment'] ??
          normalized['equipment'] ??
          normalized['items'];
      if (equipRaw != null) {
        normalized['startingEquipment'] = equipRaw;
      }

      // 3. 2024 ASIs
      final bgAbilities = _extractSpeciesAbilities(json);
      if (bgAbilities.fixed.isNotEmpty) {
        normalized['abilities'] = bgAbilities.fixed;
      }
      if (bgAbilities.flexible != null) {
        normalized['flexibleAbilities'] = bgAbilities.flexible;
      }
    }

    // Feat Ingestion: Armor, Weapon, and Tool Proficiencies
    if (entityType == 'feat') {
      final armorRaw =
          normalized['armorProficiencies'] ?? json['armorProficiencies'];
      if (armorRaw is List) {
        final armors = <String>[];
        for (final a in armorRaw) {
          if (a is String && a.trim().isNotEmpty) {
            armors.add(a.trim());
          } else if (a is Map) {
            a.forEach((key, val) {
              if (val == true || val == 1) armors.add(key.toString().trim());
            });
          }
        }
        if (armors.isNotEmpty) normalized['armorProficiencies'] = armors;
      }

      final toolsRaw =
          normalized['toolProficiencies'] ?? json['toolProficiencies'];
      if (toolsRaw is List) {
        final tools = <String>[];
        for (final t in toolsRaw) {
          if (t is String && t.trim().isNotEmpty) {
            tools.add(t.trim());
          } else if (t is Map) {
            t.forEach((key, val) {
              if (val == true || val == 1) tools.add(key.toString().trim());
            });
          }
        }
        if (tools.isNotEmpty) normalized['toolProficiencies'] = tools;
      }

      final weaponsRaw =
          normalized['weaponProficiencies'] ?? json['weaponProficiencies'];
      if (weaponsRaw is List) {
        final weapons = <String>[];
        for (final w in weaponsRaw) {
          if (w is String && w.trim().isNotEmpty) {
            weapons.add(w.trim());
          } else if (w is Map) {
            w.forEach((key, val) {
              if (val == true || val == 1) weapons.add(key.toString().trim());
            });
          }
        }
        if (weapons.isNotEmpty) normalized['weaponProficiencies'] = weapons;
      }
    }

    // Class Ingestion: Skills, Starting Proficiencies, and Choice Pools
    if (entityType == 'class') {
      final classSkills = _extractClassSkills(json);
      if (classSkills.fixed.isNotEmpty) {
        normalized['skillProficiencies'] = classSkills.fixed;
      }
      if (classSkills.flexible != null) {
        normalized['flexibleSkills'] = classSkills.flexible;
      }
      if (classSkills.allowedSkills.isNotEmpty) {
        normalized['allowedSkills'] = classSkills.allowedSkills;
      }
      normalized['skillChoiceCount'] = classSkills.choiceCount;
    }

    return normalized;
  }

  static const _canonicalSkills = {
    'athletics',
    'acrobatics',
    'sleight of hand',
    'stealth',
    'arcana',
    'history',
    'investigation',
    'nature',
    'religion',
    'animal handling',
    'insight',
    'medicine',
    'perception',
    'survival',
    'deception',
    'intimidation',
    'performance',
    'persuasion',
  };

  /// Extracts class skill proficiencies, differentiating fixed skills from choice pools.
  static ({
    List<String> fixed,
    Map<String, dynamic>? flexible,
    List<String> allowedSkills,
    int choiceCount,
  }) _extractClassSkills(Map<String, dynamic> json) {
    final fixedSkills = <String>{};
    final allowedSkills = <String>{};
    int choiceCount = 2;
    Map<String, dynamic>? flexible;

    // Check startingProficiencies (nested community schema or flat map)
    final sources = <dynamic>[];
    final sp = json['startingProficiencies'] ??
        (json['proficiencies'] is Map ? json['proficiencies'] : null);
    if (sp is Map) {
      if (sp['skills'] != null) sources.add(sp['skills']);
      if (sp['skill'] != null) sources.add(sp['skill']);
    } else if (sp != null && sp is! List) {
      sources.add(sp);
    }
    if (json['skills'] != null && json['skills'] != sp)
      sources.add(json['skills']);
    if (json['skillProficiencies'] != null)
      sources.add(json['skillProficiencies']);
    if (json['proficiencyChoices'] != null)
      sources.add(json['proficiencyChoices']);

    void parseSkillChoiceItem(dynamic item) {
      if (item == null) return;
      if (item is Map) {
        if (item.containsKey('any')) {
          final anyVal = item['any'];
          if (anyVal is num) choiceCount = anyVal.toInt();
          allowedSkills.addAll(_canonicalSkills);
          flexible = {
            'count': choiceCount,
            'from': _canonicalSkills.toList(),
          };
          return;
        }

        Map? chooseMap;
        if (item.containsKey('choose') && item['choose'] is Map) {
          chooseMap = item['choose'] as Map;
        } else if (item.containsKey('from')) {
          chooseMap = item;
        }

        if (chooseMap != null) {
          if (chooseMap['count'] is num) {
            choiceCount = (chooseMap['count'] as num).toInt();
          }
          final fromRaw = chooseMap['from'];
          final pool = <String>[];
          if (fromRaw is List) {
            for (final f in fromRaw) {
              if (f == null) continue;
              final str = f.toString().trim();
              final lower = str.toLowerCase();
              if (_canonicalSkills.contains(lower)) {
                pool.add(str);
                allowedSkills.add(str);
              } else {
                final match = RegExp(r'\{@skill\s+([^}]+)\}').firstMatch(str);
                if (match != null) {
                  pool.add(match.group(1)!);
                  allowedSkills.add(match.group(1)!);
                } else if (str.isNotEmpty) {
                  pool.add(str);
                  allowedSkills.add(str);
                }
              }
            }
          }
          if (pool.isNotEmpty) {
            flexible = {
              'count': choiceCount,
              'from': pool,
            };
          }
        }
      } else if (item is String) {
        final lower = item.toLowerCase().trim();
        if (lower.contains('choose') || lower.contains('from')) {
          final countMatch = RegExp(r'choose\s+(one|two|three|four|five|\d+)',
                  caseSensitive: false)
              .firstMatch(lower);
          if (countMatch != null) {
            final countStr = countMatch.group(1)!;
            choiceCount = switch (countStr) {
              'one' || '1' => 1,
              'two' || '2' => 2,
              'three' || '3' => 3,
              'four' || '4' => 4,
              'five' || '5' => 5,
              _ => int.tryParse(countStr) ?? 2,
            };
          }
          final pool = <String>[];
          for (final s in _canonicalSkills) {
            final reg =
                RegExp('\\b${RegExp.escape(s)}\\b', caseSensitive: false);
            if (reg.hasMatch(lower)) {
              pool.add(s);
              allowedSkills.add(s);
            }
          }
          if (pool.isNotEmpty) {
            flexible = {
              'count': choiceCount,
              'from': pool,
            };
          }
        } else if (_canonicalSkills.contains(lower)) {
          fixedSkills.add(item.trim());
        }
      }
    }

    for (final src in sources) {
      if (src is List) {
        for (final elem in src) {
          if (elem is Map) {
            parseSkillChoiceItem(elem);
          } else if (elem is String) {
            final lower = elem.toLowerCase().trim();
            if (lower.contains('choose') || lower.contains('from')) {
              parseSkillChoiceItem(elem);
            } else if (_canonicalSkills.contains(lower)) {
              fixedSkills.add(elem.trim());
            }
          }
        }
      } else if (src is Map) {
        parseSkillChoiceItem(src);
      } else if (src is String) {
        parseSkillChoiceItem(src);
      }
    }

    if (json['skillChoiceCount'] is num) {
      choiceCount = (json['skillChoiceCount'] as num).toInt();
      final flex = flexible;
      if (flex != null) {
        flex['count'] = choiceCount;
      }
    }
    if (json['allowedSkills'] is List) {
      for (final s in json['allowedSkills'] as List) {
        if (s != null) allowedSkills.add(s.toString().trim());
      }
      flexible ??= {
        'count': choiceCount,
        'from': allowedSkills.toList(),
      };
    }

    final className =
        (json['name'] ?? json['id'] ?? '').toString().toLowerCase().trim();
    if (allowedSkills.isEmpty) {
      if (className.contains('warrior sidekick') ||
          className == 'warrior-sidekick') {
        allowedSkills.addAll([
          'acrobatics',
          'animal handling',
          'athletics',
          'intimidation',
          'nature',
          'perception',
          'survival'
        ]);
        choiceCount = 1;
      } else if (className.contains('spellcaster sidekick') ||
          className == 'spellcaster-sidekick') {
        allowedSkills.addAll([
          'arcana',
          'history',
          'insight',
          'investigation',
          'medicine',
          'performance',
          'religion',
          'survival'
        ]);
        choiceCount = 2;
      } else if (className.contains('expert sidekick') ||
          className == 'expert-sidekick') {
        allowedSkills.addAll(_canonicalSkills);
        choiceCount = 2;
      }
    }

    return (
      fixed: fixedSkills.toList(),
      flexible: flexible ??
          (allowedSkills.isNotEmpty
              ? {'count': choiceCount, 'from': allowedSkills.toList()}
              : null),
      allowedSkills: allowedSkills.toList(),
      choiceCount: choiceCount,
    );
  }

  /// Extracts species ability modifiers, parsing root-level stat keys,
  /// compendium nested ability arrays, fixed stat bonuses, and choice blocks.
  static ({Map<String, int> fixed, Map<String, dynamic>? flexible})
      _extractSpeciesAbilities(
    Map<String, dynamic> json,
  ) {
    final fixed = <String, int>{};
    final choices = <Map<String, dynamic>>[];
    int totalCount = 0;
    int maxAmount = 1;
    final Set<String> pooledFrom = {};

    const abilityKeys = {'str', 'dex', 'con', 'int', 'wis', 'cha'};

    // 1. Root-level ability score keys
    for (final key in abilityKeys) {
      if (json.containsKey(key)) {
        final val = json[key];
        if (val is num) {
          fixed[key] = val.toInt();
        }
      }
    }

    // Also support root-level 'abilities' map if pre-populated
    if (json.containsKey('abilities') && json['abilities'] is Map) {
      (json['abilities'] as Map).forEach((k, v) {
        final keyStr = k.toString().toLowerCase().trim();
        if (abilityKeys.contains(keyStr) && v is num) {
          fixed[keyStr] = v.toInt();
        }
      });
    }

    // 2. Parse json['ability'] (list or nested map)
    final abilityData = json['ability'];

    void processAbilityMap(Map<dynamic, dynamic> map) {
      map.forEach((k, v) {
        final keyStr = k.toString().toLowerCase().trim();
        if (abilityKeys.contains(keyStr) && v is num) {
          fixed[keyStr] = v.toInt();
        } else if (keyStr == 'choose' && v is Map) {
          final count = (v['count'] as num?)?.toInt() ?? 1;
          final amount = (v['amount'] as num?)?.toInt() ?? 1;
          final fromRaw = v['from'];
          final fromList = <String>[];
          if (fromRaw is List) {
            for (final f in fromRaw) {
              if (f != null) fromList.add(f.toString().toLowerCase().trim());
            }
          }
          totalCount += count;
          if (amount > maxAmount) maxAmount = amount;
          pooledFrom.addAll(fromList);

          choices.add({
            'count': count,
            'amount': amount,
            if (fromList.isNotEmpty) 'from': fromList,
          });
        }
      });
    }

    if (abilityData is List) {
      for (final item in abilityData) {
        if (item is Map) {
          processAbilityMap(item);
        }
      }
    } else if (abilityData is Map) {
      processAbilityMap(abilityData);
    }

    Map<String, dynamic>? flexible;
    if (totalCount > 0 || choices.isNotEmpty) {
      flexible = {
        'count': totalCount,
        'amount': maxAmount,
        'from': pooledFrom.toList(),
        'choices': choices,
      };
    } else if (json.containsKey('flexibleAbilities') &&
        json['flexibleAbilities'] is Map) {
      flexible = Map<String, dynamic>.from(json['flexibleAbilities'] as Map);
    }

    return (fixed: fixed, flexible: flexible);
  }

  static String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Converts this DTO to pure Domain Entity.
  HomebrewEntity toDomain() {
    return HomebrewEntity(
      id: id,
      name: name,
      entityType: entityType,
      ruleset: ruleset,
      rawPayload: rawPayload,
      normalizedData: normalizedData,
      unparsedPayload: unparsedPayload,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'entityType': entityType,
      'ruleset': ruleset.name,
      'rawPayload': rawPayload,
      'normalizedData': normalizedData,
      'unparsedPayload': unparsedPayload,
    };
  }
}
