import 'package:meta/meta.dart';
import '../../domain/homebrew/models/homebrew_entity.dart';
import '../../domain/homebrew/value_objects/ruleset_version.dart';

/// Validation exception thrown when homebrew schema violates ruleset contracts.
class HomebrewValidationException implements Exception {
  final String message;
  final String? path;

  const HomebrewValidationException(this.message, {this.path});

  @override
  String toString() =>
      path != null ? 'HomebrewValidationException: $message ($path)' : 'HomebrewValidationException: $message';
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
    // 1. Mandatory Name Validation
    final rawName = json['name']?.toString().trim();
    if (rawName == null || rawName.isEmpty) {
      throw HomebrewValidationException('Entity is missing a valid "name" attribute.', path: sourcePath);
    }

    // 2. Explicit Ruleset Mismatch Detection
    final declaredRuleset = json['ruleset']?.toString().toLowerCase();
    if (declaredRuleset != null) {
      if (ruleset == RulesetVersion.srd2014 &&
          (declaredRuleset.contains('2024') || declaredRuleset.contains('5.2') || declaredRuleset.contains('xphb'))) {
        throw HomebrewValidationException(
          'Entity declared ruleset "$declaredRuleset" collides with required 2014 SRD 5.1 target.',
          path: sourcePath,
        );
      }
      if (ruleset == RulesetVersion.srd2024 &&
          (declaredRuleset.contains('2014') || declaredRuleset.contains('5.1') || declaredRuleset.contains('phb14'))) {
        throw HomebrewValidationException(
          'Entity declared ruleset "$declaredRuleset" collides with required 2024 SRD 5.2 target.',
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
      'id', 'name', 'entityType', 'type', 'source', 'ruleset',
      'level', 'school', 'time', 'duration', 'range',
      'cr', 'hp', 'hitDice', 'ac', 'speed', 'abilities', 'str', 'dex', 'con', 'int', 'wis', 'cha',
      'rarity', 'itemType', 'weaponMastery', 'mastery', 'masteryProperties',
      'traits', 'actions', 'bonusActions', 'reactions', 'spells',
      'originFeat', 'asi', 'ability', 'abilityScoreIncrease',
    };

    final unparsed = <String, dynamic>{};
    json.forEach((k, v) {
      if (!recognizedKeys.contains(k)) {
        unparsed[k] = v;
      }
    });

    final id = json['id']?.toString() ??
        json['slug']?.toString() ??
        _slugify(rawName);

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
      final masteryVal = json['weaponMastery'] ?? json['mastery'] ?? json['weaponMasteries'];
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

    // In 2014, Backgrounds do not grant Ability Score Increases or Origin Feats
    if (entityType == 'background') {
      if (json.containsKey('asi') ||
          json.containsKey('ability') ||
          json.containsKey('abilityScoreIncrease')) {
        throw HomebrewValidationException(
          'Backgrounds cannot define Ability Score Increases in 2014 SRD (ASIs belong to Race/Species).',
          path: sourcePath,
        );
      }
      if (json.containsKey('originFeat') || json['isOriginFeat'] == true) {
        throw HomebrewValidationException(
          'Origin Feats on Backgrounds are prohibited under 2014 SRD rules.',
          path: sourcePath,
        );
      }
    }
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
        'Legacy bonus-action spell restrictions are invalid under 2024 SRD 5.2 rules.',
        path: sourcePath,
      );
    }

    // In 2024, Species/Races MUST NOT define Ability Score Increases (ASIs belong to Backgrounds)
    if (entityType == 'race' || entityType == 'species') {
      if (json.containsKey('asi') ||
          json.containsKey('ability') ||
          json.containsKey('abilityScoreIncrease')) {
        final asiVal = json['asi'] ?? json['ability'] ?? json['abilityScoreIncrease'];
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
    final explicit = json['entityType']?.toString().toLowerCase() ??
        json['type']?.toString().toLowerCase();

    if (explicit != null && explicit.isNotEmpty) {
      return switch (explicit) {
        'spell' => 'spell',
        'monster' || 'creature' || 'npc' => 'monster',
        'item' || 'equipment' || 'magicitem' || 'weapon' || 'armor' => 'equipment',
        'class' || 'classdefinition' => 'class',
        'subclass' => 'subclass',
        'race' || 'species' => 'race',
        'feat' => 'feat',
        'background' => 'background',
        _ => explicit,
      };
    }

    // Heuristic inference based on signature schema keys
    if (json.containsKey('school') || json.containsKey('level') && json.containsKey('time')) {
      return 'spell';
    }
    if (json.containsKey('cr') || json.containsKey('hitDice') || json.containsKey('challengeRating')) {
      return 'monster';
    }
    if (json.containsKey('rarity') || json.containsKey('itemType') || json.containsKey('weaponCategory')) {
      return 'equipment';
    }
    if (json.containsKey('hitDie') && json.containsKey('proficiencyChoices')) {
      return 'class';
    }
    if (json.containsKey('classFeatures') || json.containsKey('subclassFeatures')) {
      return 'subclass';
    }
    if (json.containsKey('speed') && (json.containsKey('size') || json.containsKey('subraces'))) {
      return 'race';
    }
    if (json.containsKey('prerequisite') || json.containsKey('originFeat')) {
      return 'feat';
    }
    if (json.containsKey('startingEquipment') || json.containsKey('featureName')) {
      return 'background';
    }

    return 'custom';
  }

  static Map<String, dynamic> _normalizeAndClamp(Map<String, dynamic> json, String entityType) {
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

    return normalized;
  }

  static String _slugify(String name) {
    return name
        .toLowerCase()
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
