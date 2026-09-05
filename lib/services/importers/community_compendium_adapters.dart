import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/domain/spell_monster_equipment.dart';
import 'compendium_tag_parser.dart';

/// Adapters to transform community compendium raw JSON maps into strongly-typed domain entities.
class CommunityCompendiumAdapters {
  final CompendiumTagParser parser;

  CommunityCompendiumAdapters({CompendiumTagParser? parser})
      : parser = parser ?? CompendiumTagParser();

  /// Creates a slug from entity name.
  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  /// Parses community compendium Spell map into canonical [Spell].
  Spell parseSpell(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Spell';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);
    final level = (json['level'] as num?)?.toInt() ?? 0;

    // School mapping
    final schoolCode = json['school']?.toString().toUpperCase() ?? 'V';
    final school = switch (schoolCode) {
      'A' => 'Abjuration',
      'C' => 'Conjuration',
      'D' => 'Divination',
      'E' => 'Enchantment',
      'I' => 'Illusion',
      'N' => 'Necromancy',
      'T' => 'Transmutation',
      _ => schoolCode.length > 2 ? schoolCode : 'Evocation',
    };

    // Casting time
    final timeList = json['time'] as List? ?? [];
    int cost = 1;
    ActionType actionType = ActionType.action;
    String? trigger;

    if (timeList.isNotEmpty && timeList.first is Map) {
      final timeMap = timeList.first as Map;
      cost = (timeMap['number'] as num?)?.toInt() ?? 1;
      final unit = timeMap['unit']?.toString().toLowerCase() ?? 'action';
      actionType = switch (unit) {
        'bonus' || 'bonus action' => ActionType.bonusAction,
        'reaction' => ActionType.reaction,
        'minute' => ActionType.minute,
        'hour' => ActionType.hour,
        'action' => ActionType.action,
        _ => ActionType.special,
      };
      trigger = timeMap['condition']?.toString();
    }
    final castingTime = CastingTime(
      cost: cost,
      actionType: actionType,
      triggerCondition: trigger,
    );

    // Duration
    final durationList = json['duration'] as List? ?? [];
    DurationType durationType = DurationType.instantaneous;
    int durationSec = 0;
    bool isConcentration = false;
    String? rawDuration;

    if (durationList.isNotEmpty && durationList.first is Map) {
      final durMap = durationList.first as Map;
      final type = durMap['type']?.toString().toLowerCase() ?? 'instant';
      isConcentration = durMap['concentration'] == true;

      if (type == 'timed' && durMap['duration'] is Map) {
        final dObj = durMap['duration'] as Map;
        final amount = (dObj['amount'] as num?)?.toInt() ?? 1;
        final unit = dObj['type']?.toString().toLowerCase() ?? 'minute';
        durationType = DurationType.timed;
        durationSec = switch (unit) {
          'round' => amount * 6,
          'minute' => amount * 60,
          'hour' => amount * 3600,
          'day' => amount * 86400,
          _ => amount * 60,
        };
        rawDuration = '$amount $unit${amount > 1 ? 's' : ''}';
      } else if (type == 'permanent') {
        durationType = DurationType.permanent;
        rawDuration = 'Permanent';
      } else if (type == 'special') {
        durationType = DurationType.special;
        rawDuration = 'Special';
      } else {
        durationType = DurationType.instantaneous;
        rawDuration = 'Instantaneous';
      }
    }
    final spellDuration = SpellDuration(
      type: durationType,
      durationSeconds: durationSec,
      requiresConcentration: isConcentration,
      rawText: rawDuration,
    );

    // Range
    String rangeStr = 'Self';
    final rangeObj = json['range'];
    if (rangeObj is Map) {
      final rType = rangeObj['type']?.toString() ?? 'point';
      if (rangeObj['distance'] is Map) {
        final dist = rangeObj['distance'] as Map;
        final amt = dist['amount'];
        final distType = dist['type']?.toString() ?? 'feet';
        rangeStr = amt != null ? '$amt $distType' : distType;
      } else {
        rangeStr = rType;
      }
    } else if (rangeObj != null) {
      rangeStr = rangeObj.toString();
    }

    // Components
    final compObj = json['components'];
    bool hasV = false;
    bool hasS = false;
    bool hasM = false;
    String? matDesc;
    int matCost = 0;
    bool consumesMat = false;

    if (compObj is Map) {
      hasV = compObj['v'] == true;
      hasS = compObj['s'] == true;
      if (compObj.containsKey('m')) {
        hasM = true;
        final mVal = compObj['m'];
        if (mVal is String) {
          matDesc = mVal;
        } else if (mVal is Map) {
          matDesc = mVal['text']?.toString();
          matCost = (mVal['cost'] as num?)?.toInt() ?? 0;
          consumesMat = mVal['consume'] == true;
        }
      }
    }

    // Entries AST Parsing
    final parsedEntries = parser.parseEntries(
      json['entries'],
      defaultRuleset: ruleset,
    );

    String? higherLevels;
    if (json.containsKey('entriesHigherLevel')) {
      final parsedHigher = parser.parseEntries(
        json['entriesHigherLevel'],
        defaultRuleset: ruleset,
      );
      higherLevels = parsedHigher.cleanMarkdown.isNotEmpty ? parsedHigher.cleanMarkdown : null;
    }

    return Spell(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      level: level,
      school: school,
      castingTime: castingTime,
      duration: spellDuration,
      range: rangeStr,
      components: SpellComponents(
        v: hasV,
        s: hasS,
        m: hasM,
        materialDescription: matDesc,
        materialCostGp: matCost,
        consumesMaterial: consumesMat,
      ),
      descriptionMarkdown: parsedEntries.cleanMarkdown,
      higherLevelsMarkdown: higherLevels,
      damageMath: parsedEntries.extractedMath,
      relatedEntityRefs: parsedEntries.extractedReferences,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Monster map into canonical [Monster].
  Monster parseMonster(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Monster';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    // Size
    final sizeArr = json['size'] as List? ?? ['M'];
    final sizeCode = sizeArr.isNotEmpty ? sizeArr.first.toString().toUpperCase() : 'M';
    final size = switch (sizeCode) {
      'T' => 'Tiny',
      'S' => 'Small',
      'M' => 'Medium',
      'L' => 'Large',
      'H' => 'Huge',
      'G' => 'Gargantuan',
      _ => sizeCode,
    };

    // Type
    String typeStr = 'Humanoid';
    final typeObj = json['type'];
    if (typeObj is String) {
      typeStr = typeObj;
    } else if (typeObj is Map) {
      typeStr = typeObj['type']?.toString() ?? 'Humanoid';
    }

    // Alignment
    String alignStr = 'unaligned';
    final alignObj = json['alignment'];
    if (alignObj is List) {
      alignStr = alignObj.map((e) => e.toString()).join(' ');
    } else if (alignObj is String) {
      alignStr = alignObj;
    }

    // AC
    int ac = 10;
    final acObj = json['ac'];
    if (acObj is List && acObj.isNotEmpty) {
      final first = acObj.first;
      if (first is num) {
        ac = first.toInt();
      } else if (first is Map) {
        ac = (first['ac'] as num?)?.toInt() ?? 10;
      }
    } else if (acObj is num) {
      ac = acObj.toInt();
    }

    // HP
    int hp = 10;
    String formula = '2d8';
    final hpObj = json['hp'];
    if (hpObj is Map) {
      hp = (hpObj['average'] as num?)?.toInt() ?? 10;
      formula = hpObj['formula']?.toString() ?? '2d8';
    } else if (hpObj is num) {
      hp = hpObj.toInt();
    }

    // CR
    String cr = '1';
    final crObj = json['cr'];
    if (crObj is String) {
      cr = crObj;
    } else if (crObj is Map) {
      cr = crObj['cr']?.toString() ?? '1';
    } else if (crObj is num) {
      cr = crObj.toString();
    }

    // Action & Trait AST parsing
    final actionEntries = json['action'] as List? ?? [];
    final traitEntries = json['trait'] as List? ?? [];
    final combined = <dynamic>[];
    if (traitEntries.isNotEmpty) {
      combined.add({'type': 'section', 'name': 'Traits', 'entries': traitEntries});
    }
    if (actionEntries.isNotEmpty) {
      combined.add({'type': 'section', 'name': 'Actions', 'entries': actionEntries});
    }

    final parsedActions = parser.parseEntries(combined, defaultRuleset: ruleset);

    return Monster(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      monsterType: typeStr,
      alignment: alignStr,
      armorClass: ac,
      hitPoints: hp,
      hitDieFormula: formula,
      challengeRating: cr,
      actionsMarkdown: parsedActions.cleanMarkdown,
      attackMath: parsedActions.extractedMath,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Item map into canonical [EquipmentItem].
  EquipmentItem parseItem(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Item';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    final rarity = json['rarity']?.toString() ?? 'Common';
    final typeCode = json['type']?.toString() ?? 'Wondrous Item';
    final itemType = switch (typeCode.toUpperCase()) {
      'M' || 'R' => 'Weapon',
      'A' || 'LA' || 'MA' || 'HA' || 'S' => 'Armor',
      'W' => 'Wondrous Item',
      'P' => 'Potion',
      'SC' => 'Scroll',
      'RG' => 'Ring',
      'RD' => 'Rod',
      'ST' => 'Staff',
      'WD' => 'Wand',
      'G' => 'Adventuring Gear',
      _ => (name.toLowerCase().contains('armor') || name.toLowerCase().contains('shield'))
          ? 'Armor'
          : (typeCode.length > 3 ? typeCode : 'Wondrous Item'),
    };

    final reqAttune = json['reqAttune'] != null && json['reqAttune'] != false;
    final parsedEntries = parser.parseEntries(json['entries'], defaultRuleset: ruleset);

    return EquipmentItem(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      itemType: itemType,
      rarity: rarity,
      requiresAttunement: reqAttune,
      descriptionMarkdown: parsedEntries.cleanMarkdown,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Class map into canonical [CharacterClass].
  CharacterClass parseClass(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Class';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    final hdObj = json['hd'];
    String hitDie = 'd8';
    if (hdObj is Map) {
      final faces = hdObj['faces'];
      if (faces != null) hitDie = 'd$faces';
    } else if (hdObj != null) {
      hitDie = hdObj.toString();
    }

    final parsed = parser.parseEntries(json['classFeatures'] ?? json['entries'], defaultRuleset: ruleset);

    // Extract subclass level (e.g. from subclassTitle, subclassProgression, or explicit field)
    int subclassLevel = (json['subclassSelectionLevel'] as num?)?.toInt() ??
        (json['subclassLevel'] as num?)?.toInt() ??
        3;

    // Parse explicit featureDecisions or optionalfeatureProg
    final featureDecisions = <ClassFeatureDecision>[];
    if (json['featureDecisions'] is List) {
      for (final decMap in json['featureDecisions']) {
        if (decMap is Map<String, dynamic>) {
          featureDecisions.add(ClassFeatureDecision.fromMap(decMap));
        }
      }
    } else if (json['optionalfeatureProg'] is List) {
      // Community optional feature progression
      for (final prog in json['optionalfeatureProg']) {
        if (prog is Map) {
          final progName = prog['name']?.toString() ?? 'Class Choice';
          final progTypeStr = prog['featureType']?.toString().toLowerCase() ?? '';
          final progLevel = (prog['progression'] as Map?)?.keys.map((k) => int.tryParse(k.toString()) ?? 1).firstOrNull ?? 1;

          FeatureChoiceType choiceType = FeatureChoiceType.customOption;
          if (progTypeStr.contains('fs') || progName.toLowerCase().contains('fighting style')) {
            choiceType = FeatureChoiceType.fightingStyle;
          } else if (progTypeStr.contains('ei') || progName.toLowerCase().contains('invocation')) {
            choiceType = FeatureChoiceType.invocations;
          } else if (progTypeStr.contains('pb') || progName.toLowerCase().contains('pact boon')) {
            choiceType = FeatureChoiceType.pactBoon;
          }

          featureDecisions.add(ClassFeatureDecision(
            id: '$slug-${_slugify(progName)}-$progLevel',
            name: progName,
            prompt: 'Select $progName',
            levelRequired: progLevel,
            type: choiceType,
            ruleset: ruleset,
          ));
        }
      }
    }

    return CharacterClass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      hitDie: hitDie,
      featuresMarkdown: parsed.cleanMarkdown,
      subclassSelectionLevel: subclassLevel,
      featureDecisions: featureDecisions,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Subclass map into canonical [Subclass].
  Subclass parseSubclass(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Subclass';
    final className = json['className']?.toString() ?? 'Fighter';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify('$className-$name');
    final classSlug = _slugify(className);

    final parsed = parser.parseEntries(json['subclassFeatures'] ?? json['entries'], defaultRuleset: ruleset);

    return Subclass(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      classSlug: classSlug,
      shortName: json['shortName']?.toString() ?? name,
      featuresMarkdown: parsed.cleanMarkdown,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Race map into canonical [Race].
  Race parseRace(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Race';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    String size = 'Medium';
    final sizeArr = json['size'] as List?;
    if (sizeArr != null && sizeArr.isNotEmpty) {
      size = sizeArr.first.toString();
    }

    String speed = '30 ft.';
    final speedObj = json['speed'];
    if (speedObj is num) {
      speed = '$speedObj ft.';
    } else if (speedObj is Map) {
      final walk = speedObj['walk'];
      if (walk != null) speed = '$walk ft.';
    }

    final parsed = parser.parseEntries(json['entries'], defaultRuleset: ruleset);

    return Race(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      size: size,
      speed: speed,
      traitsMarkdown: parsed.cleanMarkdown,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Feat map into canonical [Feat].
  Feat parseFeat(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Feat';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    String? prereq;
    final prereqArr = json['prerequisite'] as List?;
    if (prereqArr != null && prereqArr.isNotEmpty) {
      prereq = prereqArr.map((e) => e.toString()).join(', ');
    }

    final category = json['category']?.toString() ?? 'General';
    final parsed = parser.parseEntries(json['entries'], defaultRuleset: ruleset);

    return Feat(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      prerequisite: prereq,
      category: category,
      descriptionMarkdown: parsed.cleanMarkdown,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }

  /// Parses community compendium Background map into canonical [Background].
  Background parseBackground(Map<String, dynamic> json, {RulesetVersion? forceRuleset}) {
    final name = json['name']?.toString() ?? 'Unnamed Background';
    final source = json['source']?.toString();
    final ruleset = forceRuleset ?? parser.detectRuleset(source);
    final slug = _slugify(name);

    final parsed = parser.parseEntries(json['entries'], defaultRuleset: ruleset);

    return Background(
      id: EntityId(slug: slug, ruleset: ruleset),
      name: name,
      descriptionMarkdown: parsed.cleanMarkdown,
      customProperties: {
        'source': source ?? 'HOMEBREW',
        'rawJson': json,
      },
    );
  }
}
