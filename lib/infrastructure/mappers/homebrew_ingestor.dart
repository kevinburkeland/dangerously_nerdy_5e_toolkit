import '../../domain/homebrew/value_objects/ruleset_version.dart' as domain_rules;
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../services/logging_service.dart';
import '../dtos/animated_object_dto.dart';
import '../dtos/character_dto.dart';
import '../dtos/homebrew_entity_dto.dart';
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

  /// Ingests a raw list of homebrew race / species JSON objects into validated [Race] instances.
  static List<Race> parseCustomRaces(
    List<dynamic> rawList, {
    domain_rules.RulesetVersion ruleset = domain_rules.RulesetVersion.srd2014,
  }) {
    final validRaces = <Race>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final race = parseRace(map, ruleset: ruleset);
        if (race.id.slug.isNotEmpty && race.name.isNotEmpty) {
          validRaces.add(race);
        }
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew race ${map['name']}. Skipping.',
        );
      }
    }

    return validRaces;
  }

  /// Parses a single raw homebrew race/species map into a strongly-typed [Race].
  static Race parseRace(
    Map<String, dynamic> raw, {
    domain_rules.RulesetVersion ruleset = domain_rules.RulesetVersion.srd2014,
  }) {
    final dto = HomebrewEntityDto.fromJson(raw, ruleset: ruleset);
    return mapRaceFromDto(dto);
  }

  /// Maps a validated [HomebrewEntityDto] into a domain [Race] entity,
  /// reading normalized abilities and flexible abilities to assign species bonuses accurately.
  static Race mapRaceFromDto(HomebrewEntityDto dto) {
    final raw = dto.rawPayload;
    final normalized = dto.normalizedData;

    final fixedBonuses = <String, int>{};
    final rawAbilities = normalized['abilities'] ?? raw['abilities'];
    if (rawAbilities is Map) {
      rawAbilities.forEach((k, v) {
        if (v is num) {
          final keyLower = k.toString().toLowerCase().trim();
          fixedBonuses[keyLower] = v.toInt();
          final canonical = switch (keyLower) {
            'str' => 'strength',
            'dex' => 'dexterity',
            'con' => 'constitution',
            'int' => 'intelligence',
            'wis' => 'wisdom',
            'cha' => 'charisma',
            _ => null,
          };
          if (canonical != null) {
            fixedBonuses[canonical] = v.toInt();
          }
        }
      });
    }

    int? flexCount;
    int? flexBonus;
    final flexData = normalized['flexibleAbilities'] ?? raw['flexibleAbilities'];
    if (flexData is Map) {
      if (flexData['count'] is num) {
        flexCount = (flexData['count'] as num).toInt();
      }
      if (flexData['amount'] is num) {
        flexBonus = (flexData['amount'] as num).toInt();
      }
    }

    // Size
    String size = 'Medium';
    final sizeVal = normalized['size'] ?? raw['size'];
    if (sizeVal is List && sizeVal.isNotEmpty) {
      size = sizeVal.first.toString();
    } else if (sizeVal is String && sizeVal.isNotEmpty) {
      size = sizeVal;
    }

    // Speed
    String speed = '30 ft.';
    final speedVal = normalized['speed'] ?? raw['speed'];
    if (speedVal is num) {
      speed = '$speedVal ft.';
    } else if (speedVal is Map) {
      final walk = speedVal['walk'] ?? speedVal['speed'];
      if (walk != null) speed = '$walk ft.';
    } else if (speedVal is String && speedVal.isNotEmpty) {
      speed = speedVal.contains('ft') ? speedVal : '$speedVal ft.';
    }

    // Subraces
    final subraces = <Subrace>[];
    final rawSubList = raw['subraces'] ?? raw['subrace'];
    if (rawSubList is List) {
      for (final rawSub in rawSubList) {
        if (rawSub is Map) {
          final subMap = Map<String, dynamic>.from(rawSub);
          final subName = subMap['name']?.toString().trim() ?? '';
          if (subName.isNotEmpty) {
            final subTraits = subMap['entries'] ?? subMap['traits'] ?? subMap['desc'] ?? '';
            final subTraitsMarkdown = subTraits is List
                ? subTraits.map((e) => e is Map ? (e['name'] != null ? '### ${e['name']}\n${e['entries'] ?? ''}' : e.toString()) : e.toString()).join('\n\n')
                : subTraits.toString();

            final subFixed = <String, int>{};
            final subRawAb = subMap['abilities'] ?? subMap['ability'];
            if (subRawAb is Map) {
              subRawAb.forEach((k, v) {
                final keyLower = k.toString().toLowerCase().trim();
                if (v is num && ['str', 'dex', 'con', 'int', 'wis', 'cha'].contains(keyLower)) {
                  subFixed[keyLower] = v.toInt();
                }
              });
            } else if (subRawAb is List) {
              for (final item in subRawAb) {
                if (item is Map) {
                  item.forEach((k, v) {
                    final keyLower = k.toString().toLowerCase().trim();
                    if (v is num && ['str', 'dex', 'con', 'int', 'wis', 'cha'].contains(keyLower)) {
                      subFixed[keyLower] = v.toInt();
                    }
                  });
                }
              }
            }
            for (final k in ['str', 'dex', 'con', 'int', 'wis', 'cha']) {
              if (subMap.containsKey(k) && subMap[k] is num) {
                subFixed[k] = (subMap[k] as num).toInt();
              }
            }

            int? subFlexCount;
            int? subFlexBonus;
            List<String>? subFlexPool;
            final subFlexData = subMap['flexibleAbilities'] ?? subMap['choose'];
            if (subFlexData is Map) {
              if (subFlexData['count'] is num) subFlexCount = (subFlexData['count'] as num).toInt();
              if (subFlexData['amount'] is num) subFlexBonus = (subFlexData['amount'] as num).toInt();
              if (subFlexData['from'] is List) {
                subFlexPool = (subFlexData['from'] as List).map((e) => e.toString().toLowerCase().trim()).toList();
              }
            }
            if (subRawAb is List) {
              for (final item in subRawAb) {
                if (item is Map && item.containsKey('choose') && item['choose'] is Map) {
                  final ch = item['choose'] as Map;
                  if (ch['count'] is num) subFlexCount = (ch['count'] as num).toInt();
                  if (ch['amount'] is num) subFlexBonus = (ch['amount'] as num).toInt();
                  if (ch['from'] is List) {
                    subFlexPool = (ch['from'] as List).map((e) => e.toString().toLowerCase().trim()).toList();
                  }
                }
              }
            }

            subraces.add(Subrace(
              id: EntityId(
                slug: subMap['id']?.toString() ??
                    subMap['slug']?.toString() ??
                    subName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
                ruleset: dto.ruleset == domain_rules.RulesetVersion.srd2024
                    ? RulesetVersion.v2024
                    : RulesetVersion.v2014,
              ),
              name: subName,
              raceSlug: dto.id,
              traitsMarkdown: subTraitsMarkdown,
              fixedAbilityBonuses: subFixed,
              flexibleAbilityCount: subFlexCount ?? 0,
              flexibleAbilityBonus: subFlexBonus ?? 0,
              flexibleAbilityPool: subFlexPool,
              customProperties: subMap,
            ));
          }
        }
      }
    }

    // Traits Markdown
    String traitsMarkdown = '';
    final rawEntries = raw['entries'] ?? raw['traits'] ?? raw['trait'] ?? raw['desc'] ?? raw['description'];
    if (rawEntries is List) {
      traitsMarkdown = rawEntries.map((e) {
        if (e is Map) {
          final entryName = e['name']?.toString() ?? '';
          final entryText = e['entries'] ?? e['text'] ?? '';
          return entryName.isNotEmpty ? '### $entryName\n$entryText' : entryText.toString();
        }
        return e.toString();
      }).join('\n\n');
    } else if (rawEntries is String) {
      traitsMarkdown = rawEntries;
    }

    final customProps = Map<String, dynamic>.from(dto.unparsedPayload);
    customProps.addAll(dto.rawPayload);
    if (fixedBonuses.isNotEmpty) {
      customProps['abilityBonuses'] = fixedBonuses;
    }
    if (flexCount != null && flexCount > 0) {
      customProps['flexibleAbilityCount'] = flexCount;
      customProps['flexibleAbilityBonus'] = flexBonus ?? 1;
    }
    if (flexData != null) {
      customProps['flexibleAbilities'] = flexData;
    }

    // Ability Score Summary
    final summaryParts = <String>[];
    const shortAbilities = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    for (final ab in shortAbilities) {
      if (fixedBonuses.containsKey(ab)) {
        summaryParts.add('${ab.toUpperCase()} +${fixedBonuses[ab]}');
      }
    }
    if (flexCount != null && flexCount > 0) {
      final bonusVal = flexBonus ?? 1;
      final bonusStr = '+$bonusVal';
      final fromList = flexData is Map && flexData['from'] is List
          ? (flexData['from'] as List).map((e) => e.toString().toUpperCase()).join('/')
          : 'any';
      summaryParts.add('$bonusStr to $flexCount ($fromList)');
    }
    final abilitySummary = summaryParts.isNotEmpty ? summaryParts.join(', ') : null;

    return Race(
      id: EntityId(
        slug: dto.id,
        ruleset: dto.ruleset == domain_rules.RulesetVersion.srd2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: dto.name,
      size: size,
      speed: speed,
      abilityScoreSummary: abilitySummary,
      traitsMarkdown: traitsMarkdown,
      subraces: subraces,
      flexibleAbilityCount: flexCount,
      flexibleAbilityBonus: flexBonus,
      fixedAbilityBonuses: fixedBonuses.isNotEmpty ? fixedBonuses : null,
      customProperties: customProps,
    );
  }

  /// Maps a validated [HomebrewEntityDto] into a Domain [Background].
  static Background mapBackgroundFromDto(HomebrewEntityDto dto) {
    final raw = dto.rawPayload;
    final normalized = dto.normalizedData;

    // 1. Skill Proficiencies
    final skillList = <String>[];
    final rawSkills = normalized['skillProficiencies'] ??
        raw['skillProficiencies'] ??
        raw['skills'] ??
        raw['skill'];
    if (rawSkills is List) {
      for (final s in rawSkills) {
        if (s != null && s.toString().trim().isNotEmpty) {
          skillList.add(s.toString().trim());
        }
      }
    } else if (rawSkills is String && rawSkills.isNotEmpty) {
      skillList.addAll(rawSkills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }

    // 2. Tool Proficiencies
    final toolList = <String>[];
    final rawTools = normalized['toolProficiencies'] ??
        raw['toolProficiencies'] ??
        raw['tools'] ??
        raw['tool'];
    if (rawTools is List) {
      for (final t in rawTools) {
        if (t != null && t.toString().trim().isNotEmpty) {
          toolList.add(t.toString().trim());
        }
      }
    } else if (rawTools is String && rawTools.isNotEmpty) {
      toolList.addAll(rawTools.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
    }

    // 3. Languages
    final langList = <String>[];
    final rawLangs = normalized['languages'] ?? raw['languages'] ?? raw['language'];
    if (rawLangs is List) {
      for (final l in rawLangs) {
        if (l != null && l.toString().trim().isNotEmpty) {
          langList.add(l.toString().trim());
        }
      }
    } else if (rawLangs is String && rawLangs.isNotEmpty) {
      langList.addAll(rawLangs.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty));
    }

    // 4. Starting Equipment & Origin Feat
    final originFeat = normalized['originFeat']?.toString() ??
        raw['originFeat']?.toString() ??
        raw['feat']?.toString();

    // 5. Description Markdown
    String desc = '';
    final rawEntries = raw['entries'] ?? raw['desc'] ?? raw['description'];
    if (rawEntries is List) {
      desc = rawEntries.map((e) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          final txt = e['entries'] ?? e['text'] ?? '';
          return name.isNotEmpty ? '### $name\n$txt' : txt.toString();
        }
        return e.toString();
      }).join('\n\n');
    } else if (rawEntries is String) {
      desc = rawEntries;
    }

    // 6. Custom Properties & 2024 ASIs
    final customProps = Map<String, dynamic>.from(dto.unparsedPayload);
    customProps.addAll(raw);
    if (normalized.containsKey('abilities')) {
      customProps['abilities'] = normalized['abilities'];
    }
    if (normalized.containsKey('flexibleAbilities')) {
      customProps['flexibleAbilities'] = normalized['flexibleAbilities'];
    }
    if (normalized.containsKey('startingEquipment')) {
      customProps['startingEquipment'] = normalized['startingEquipment'];
    }

    // Format abilityScoreSummary for 2024 ASIs if present
    String? abilityScoreSummary;
    if (normalized['abilities'] is Map) {
      final abMap = normalized['abilities'] as Map;
      final parts = <String>[];
      abMap.forEach((k, v) {
        parts.add('${k.toString().toUpperCase()} +$v');
      });
      if (parts.isNotEmpty) {
        abilityScoreSummary = parts.join(', ');
      }
    }

    return Background(
      id: EntityId(
        slug: dto.id,
        ruleset: dto.ruleset == domain_rules.RulesetVersion.srd2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: dto.name,
      abilityScoreSummary: abilityScoreSummary,
      originFeat: originFeat,
      skillProficiencies: skillList,
      toolProficiencies: toolList,
      languages: langList,
      descriptionMarkdown: desc,
      customProperties: customProps,
    );
  }

  /// Parses a batch of raw background payloads into domain [Background] entities.
  static List<Background> parseCustomBackgrounds(
    List<dynamic> rawList, {
    required domain_rules.RulesetVersion ruleset,
  }) {
    final backgrounds = <Background>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = HomebrewEntityDto.fromJson(map, ruleset: ruleset);
        backgrounds.add(mapBackgroundFromDto(dto));
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew background ${map['name']}. Skipping.',
        );
      }
    }

    return backgrounds;
  }

  /// Maps a validated [HomebrewEntityDto] into a Domain [CharacterClass] / [ClassDefinition].
  static CharacterClass mapClassFromDto(HomebrewEntityDto dto) {
    final raw = dto.rawPayload;
    final normalized = dto.normalizedData;

    // Hit Die
    String hitDie = 'd8';
    final hdVal = raw['hitDie'] ?? raw['hd'] ?? raw['hitDice'];
    if (hdVal != null) {
      final hdStr = hdVal.toString().trim();
      hitDie = hdStr.startsWith('d') ? hdStr : 'd$hdStr';
    }

    // Saving Throws
    final savingThrows = <String>[];
    final rawSaves = raw['savingThrows'] ?? raw['proficiency'] ?? raw['proficiencies'];
    if (rawSaves is List) {
      for (final s in rawSaves) {
        if (s != null && s.toString().trim().isNotEmpty) {
          savingThrows.add(s.toString().toLowerCase().trim());
        }
      }
    }

    // Armor and Weapon Proficiencies
    final armorProficiencies = <String>[];
    final weaponProficiencies = <String>[];
    final sp = raw['startingProficiencies'];
    if (sp is Map) {
      if (sp['armor'] is List) {
        armorProficiencies.addAll((sp['armor'] as List).map((e) => e.toString().trim()));
      }
      if (sp['weapons'] is List) {
        weaponProficiencies.addAll((sp['weapons'] as List).map((e) => e.toString().trim()));
      }
    }

    // Features Markdown
    String featuresMarkdown = '';
    final rawEntries = raw['entries'] ?? raw['classFeatures'] ?? raw['features'] ?? raw['desc'];
    if (rawEntries is List) {
      featuresMarkdown = rawEntries.map((e) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          final txt = e['entries'] ?? e['text'] ?? '';
          return name.isNotEmpty ? '### $name\n$txt' : txt.toString();
        }
        return e.toString();
      }).join('\n\n');
    } else if (rawEntries is String) {
      featuresMarkdown = rawEntries;
    }

    // Custom Properties (preserve 100% data + normalized skill metadata)
    final customProps = Map<String, dynamic>.from(dto.unparsedPayload);
    customProps.addAll(raw);

    // Populate normalized skills into custom properties for domain consumption
    if (normalized.containsKey('skillProficiencies')) {
      customProps['skillProficiencies'] = normalized['skillProficiencies'];
    }
    if (normalized.containsKey('flexibleSkills')) {
      customProps['flexibleSkills'] = normalized['flexibleSkills'];
    }
    if (normalized.containsKey('allowedSkills')) {
      customProps['allowedSkills'] = normalized['allowedSkills'];
    }
    if (normalized.containsKey('skillChoiceCount')) {
      customProps['skillChoiceCount'] = normalized['skillChoiceCount'];
    }

    return CharacterClass(
      id: EntityId(
        slug: dto.id,
        ruleset: dto.ruleset == domain_rules.RulesetVersion.srd2024
            ? RulesetVersion.v2024
            : RulesetVersion.v2014,
      ),
      name: dto.name,
      hitDie: hitDie,
      primaryAbility: raw['primaryAbility']?.toString(),
      spellcastingAbility: raw['spellcastingAbility']?.toString(),
      savingThrows: savingThrows,
      armorProficiencies: armorProficiencies,
      weaponProficiencies: weaponProficiencies,
      featuresMarkdown: featuresMarkdown,
      customProperties: customProps,
    );
  }

  /// Parses a batch of raw class payloads into domain [CharacterClass] entities.
  static List<CharacterClass> parseCustomClasses(
    List<dynamic> rawList, {
    required domain_rules.RulesetVersion ruleset,
  }) {
    final classes = <CharacterClass>[];

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item);

      try {
        final dto = HomebrewEntityDto.fromJson(map, ruleset: ruleset);
        classes.add(mapClassFromDto(dto));
      } catch (e, st) {
        LoggingService().logNonFatal(
          e,
          st,
          reason: 'Failed to ingest homebrew class ${map['name']}. Skipping.',
        );
      }
    }

    return classes;
  }
}
