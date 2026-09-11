import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../services/logging_service.dart';
import '../dtos/animated_object_dto.dart';
import '../dtos/character_dto.dart';
import '../dtos/spell_dto.dart';

/// Anti-Corruption Layer (ACL) ingestor for external and homebrew JSON bundles.
///
/// Ensures fault-tolerant parsing where invalid or malformed entries are isolated
/// and logged without failing the ingestion of surviving valid entities.
class HomebrewIngestor {
  const HomebrewIngestor._();

  /// Ingests a raw list of homebrew spell JSON objects into validated [SpellDto] instances.
  ///
  /// Each item is parsed in an isolated try/catch block so that malformed entries
  /// do not abort processing of the remaining batch.
  static List<SpellDto> parseCustomSpells(List<dynamic> rawList) {
    final validSpells = <SpellDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = SpellDto.fromJson(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validSpells.add(dto);
        }
      } catch (e, st) {
        // Isolate the failure so the rest of the JSON bundle survives
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew spell ${map['name']}. Skipping.',
        );
      }
    }

    return validSpells;
  }

  /// Normalizes spatial geometry and range representation into strongly-typed
  /// `rangeDistanceFeet` (int) and `rangeType` (String/enum representation).
  ///
  /// Falls back to 0 for self/touch and extracts the numeric distance for ranged/line/cone attacks.
  /// When [description] is supplied, resolves spatial geometry descriptors (e.g., "A line of roaring flame...")
  /// even if the primary range string was listed generically as "30 feet".
  static Map<String, dynamic> normalizeRange(dynamic rawRange, [String? description]) {
    if (rawRange == null) {
      return {'rangeDistanceFeet': 0, 'rangeType': 'self'};
    }

    int distance = 0;
    String type = 'ranged';

    if (rawRange is Map) {
      final typeStr = (rawRange['type'] ?? '').toString().toLowerCase();
      if (rawRange['distance'] is Map) {
        distance = (rawRange['distance']['amount'] as num?)?.toInt() ?? 0;
      }
      if (typeStr.contains('touch')) {
        type = 'touch';
        distance = 0;
      } else if (typeStr.contains('self')) {
        type = 'self';
        distance = 0;
      } else if (typeStr.contains('cone')) {
        type = 'cone';
      } else if (typeStr.contains('line')) {
        type = 'line';
      } else if (typeStr.contains('radius') || typeStr.contains('sphere')) {
        type = 'radius';
      } else if (typeStr.contains('point')) {
        type = 'ranged';
      }
    } else {
      final rawStr = rawRange.toString();
      final lowerRange = rawStr.toLowerCase();

      if (lowerRange.contains('touch')) {
        type = 'touch';
      } else if (lowerRange.contains('line')) {
        type = 'line';
      } else if (lowerRange.contains('cone')) {
        type = 'cone';
      } else if (lowerRange.contains('radius') || lowerRange.contains('sphere')) {
        type = 'radius';
      } else if (lowerRange.contains('self')) {
        type = 'self';
      }

      final digitMatch = RegExp(r'\d+').firstMatch(rawStr);
      if (digitMatch != null && type != 'self' && type != 'touch') {
        distance = int.tryParse(digitMatch.group(0) ?? '0') ?? 0;
      }
    }

    // Inspect description if spatial geometry was not captured in range field
    if (description != null && description.isNotEmpty) {
      final descLower = description.toLowerCase();
      if (type == 'ranged' || type == 'self') {
        if (descLower.contains('line of') || RegExp(r'\b\d+[- ]foot line\b').hasMatch(descLower)) {
          type = 'line';
          if (distance == 0) {
            final m = RegExp(r'(\d+)[- ]foot line').firstMatch(descLower);
            if (m != null) distance = int.tryParse(m.group(1) ?? '0') ?? 0;
          }
        } else if (descLower.contains('cone of') || RegExp(r'\b\d+[- ]foot cone\b').hasMatch(descLower)) {
          type = 'cone';
          if (distance == 0) {
            final m = RegExp(r'(\d+)[- ]foot cone').firstMatch(descLower);
            if (m != null) distance = int.tryParse(m.group(1) ?? '0') ?? 0;
          }
        } else if (descLower.contains('sphere of') ||
            descLower.contains('radius of') ||
            RegExp(r'\b\d+[- ]foot (?:radius|sphere)\b').hasMatch(descLower)) {
          type = 'radius';
          if (distance == 0) {
            final m = RegExp(r'(\d+)[- ]foot (?:radius|sphere)').firstMatch(descLower);
            if (m != null) distance = int.tryParse(m.group(1) ?? '0') ?? 0;
          }
        }
      }
    }

    return {'rangeDistanceFeet': distance, 'rangeType': type};
  }

  /// Reconciles and corrects damage types in [damageMath] if mislabeled in external JSON
  /// by cross-referencing explicit damage formulas in [description] (e.g. "1d10 piercing damage").
  static List<EvaluationMath> correctDamageTypesFromDescription(
    List<EvaluationMath> damageMath,
    String description,
  ) {
    if (damageMath.isEmpty || description.isEmpty) return damageMath;

    final regex = RegExp(
      r'(\d+d\d+)[^\w\n]*(acid|bludgeoning|cold|fire|force|lightning|necrotic|piercing|poison|psychic|radiant|slashing|thunder)\s+damage',
      caseSensitive: false,
    );

    final matches = regex.allMatches(description);
    if (matches.isEmpty) return damageMath;

    final formulaToType = <String, DamageType>{};
    for (final m in matches) {
      final formula = m.group(1)!.toLowerCase().replaceAll(' ', '');
      final typeStr = m.group(2)!.toLowerCase();
      formulaToType[formula] = DamageType.fromLooseString(typeStr);
    }

    return damageMath.map((dm) {
      final cleanFormula = dm.diceFormula.toLowerCase().replaceAll(' ', '');
      if (formulaToType.containsKey(cleanFormula)) {
        final expectedType = formulaToType[cleanFormula]!;
        if (dm.damageType != expectedType && dm.damageType != DamageType.variable) {
          return dm.copyWith(damageType: expectedType);
        }
      }
      return dm;
    }).toList();
  }

  /// Detects variable or selectable damage types in spell descriptions,
  /// preventing default lock-in to the first matched type (e.g. "acid").
  static String resolveDamageType(String rawDescription, String firstMatchedType) {
    final lowerFirst = firstMatchedType.toLowerCase();
    if (lowerFirst == 'variable' || lowerFirst == 'choose') {
      return 'variable';
    }
    final lower = rawDescription.toLowerCase();
    if (lower.contains('choose acid, cold, fire, lightning') ||
        lower.contains("determines the attack's damage type") ||
        lower.contains("determines the attack’s damage type") ||
        lower.contains('choose acid') ||
        lower.contains('variable damage') ||
        lower.contains('damage type is variable') ||
        (lower.contains('you choose') && lower.contains('damage')) ||
        (lower.contains('choose') && lower.contains('damage type')) ||
        lower.contains('chaotic') ||
        lower.contains('chaos') ||
        lower.contains('chromatic orb') ||
        lower.contains('prismatic spray')) {
      return 'variable';
    }
    return firstMatchedType;
  }

  /// Extracts the dice formula (e.g., "1d6", "1d8") from higherLevelsMarkdown.
  static String? extractHigherLevelsDice(String? higherLevelsMarkdown) {
    if (higherLevelsMarkdown == null || higherLevelsMarkdown.isEmpty) return null;
    final match = RegExp(r'(\d+d\d+)').firstMatch(higherLevelsMarkdown);
    return match?.group(1);
  }

  /// Enriches damage math entries with delivery method flags (isAttackRoll, requiresSave).
  static List<EvaluationMath> enrichDamageDelivery(
    List<EvaluationMath> damageMath,
    String description,
  ) {
    if (damageMath.isEmpty) return damageMath;

    final lower = description.toLowerCase();
    final hasAttack = lower.contains('spell attack') ||
        lower.contains('attack roll') ||
        lower.contains('make a ranged spell attack') ||
        lower.contains('make a melee spell attack');
    final hasSave = lower.contains('saving throw') ||
        lower.contains('must succeed on a') ||
        lower.contains('must make a');

    // If flags are already set on all items, preserve them
    final alreadyAllFlagged = damageMath.every((dm) => dm.isAttackRoll || dm.requiresSave);
    if (alreadyAllFlagged) return damageMath;

    // Multi-stage spell detection (e.g., Frost Shard: 1d10 piercing attack, 2d6 cold DEX save)
    if (damageMath.length >= 2 && hasAttack && hasSave) {
      final attackIdx = lower.contains('spell attack')
          ? lower.indexOf('spell attack')
          : lower.indexOf('attack');
      final saveIdx = lower.contains('saving throw')
          ? lower.indexOf('saving throw')
          : lower.indexOf('succeed on');

      return damageMath.map((dm) {
        if (dm.isAttackRoll || dm.requiresSave) return dm;

        final formula = dm.diceFormula.toLowerCase();
        final typeName = dm.damageType.name.toLowerCase();

        final formulaIdx = formula.isNotEmpty ? lower.indexOf(formula) : -1;
        final typeIdx = typeName.isNotEmpty ? lower.indexOf(typeName) : -1;
        final itemIdx = formulaIdx != -1 ? formulaIdx : typeIdx;

        bool isAttack = false;
        bool isSave = false;

        if (itemIdx != -1) {
          final distToAttack = attackIdx != -1 ? (itemIdx - attackIdx).abs() : 999999;
          final distToSave = saveIdx != -1 ? (itemIdx - saveIdx).abs() : 999999;
          if (distToAttack < distToSave) {
            isAttack = true;
          } else {
            isSave = true;
          }
        } else {
          if (dm == damageMath.first) {
            isAttack = true;
          } else {
            isSave = true;
          }
        }

        return dm.copyWith(
          isAttackRoll: isAttack,
          requiresSave: isSave,
        );
      }).toList();
    }

    // Single delivery mode across entire spell
    if (hasAttack && !hasSave) {
      return damageMath.map((dm) => dm.isAttackRoll || dm.requiresSave ? dm : dm.copyWith(isAttackRoll: true)).toList();
    } else if (hasSave && !hasAttack) {
      return damageMath.map((dm) => dm.isAttackRoll || dm.requiresSave ? dm : dm.copyWith(requiresSave: true)).toList();
    }

    return damageMath;
  }

  /// Ingests a raw list of homebrew character JSON objects into validated [CharacterDto] instances.
  static List<CharacterDto> parseCustomCharacters(List<dynamic> rawList) {
    final validCharacters = <CharacterDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = CharacterDto.fromJson(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validCharacters.add(dto);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew character ${map['name']}. Skipping.',
        );
      }
    }

    return validCharacters;
  }

  /// Ingests a raw list of animated object / minion JSON objects into validated [AnimatedObjectDto] instances.
  static List<AnimatedObjectDto> parseCustomAnimatedObjects(List<dynamic> rawList) {
    final validObjects = <AnimatedObjectDto>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = AnimatedObjectDto.fromMap(map);
        if (dto.id.isNotEmpty && dto.name.isNotEmpty) {
          validObjects.add(dto);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew animated object ${map['name']}. Skipping.',
        );
      }
    }

    return validObjects;
  }
}
