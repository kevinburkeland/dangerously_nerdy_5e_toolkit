import 'dart:math' as math;
import '../../models/domain/character_models.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../../models/spellbook_data.dart';

/// Anti-Corruption Layer (ACL) Boundary Parser.
/// Quarantines all unstructured text scraping, regex heuristics, and legacy JSON
/// transformations to the system boundary so the core domain remains 100% strongly typed.
class StatBlockAclParser {
  StatBlockAclParser._();

  static final _reachPattern = RegExp(r'reach\s*(\d+)\s*ft', caseSensitive: false);
  static final _slotPattern = RegExp(r'(\d+)(?:st|nd|rd|th)\s*level\s*\((\d+)\s*slots?\)', caseSensitive: false);
  static final _casterLvlPattern = RegExp(r'(\d+)(?:st|nd|rd|th)[- ]level\s+spellcaster', caseSensitive: false);
  static final _spellSaveDcPattern = RegExp(r'spell\s*save\s*dc\s*(\d+)', caseSensitive: false);
  static final _spellAttackPattern = RegExp(r'([+-]?\s*\d+)\s*to\s*hit\s*with\s*spell\s*attacks', caseSensitive: false);
  static final _rechargeDayPattern = RegExp(r'(\d+)/day', caseSensitive: false);
  static final _staticAbilitySavePatterns = {
    AbilityType.strength: RegExp(r'\b(?:str|strength)\s*([+-]?\s*\d+)', caseSensitive: false),
    AbilityType.dexterity: RegExp(r'\b(?:dex|dexterity)\s*([+-]?\s*\d+)', caseSensitive: false),
    AbilityType.constitution: RegExp(r'\b(?:con|constitution)\s*([+-]?\s*\d+)', caseSensitive: false),
    AbilityType.intelligence: RegExp(r'\b(?:int|intelligence)\s*([+-]?\s*\d+)', caseSensitive: false),
    AbilityType.wisdom: RegExp(r'\b(?:wis|wisdom)\s*([+-]?\s*\d+)', caseSensitive: false),
    AbilityType.charisma: RegExp(r'\b(?:cha|charisma)\s*([+-]?\s*\d+)', caseSensitive: false),
  };

  /// Parses an unstructured/third-party [MinionStatBlock] at the ingestion boundary
  /// to pre-calculate all combat metrics into explicit typed primitives.
  static ({
    Map<int, int> spellSlots,
    List<String> knownSpellIds,
    int spellSaveDc,
    int spellAttackBonus,
    int maxReachFt,
    bool canFly,
    bool hasHover,
    bool canSwim,
    bool canBurrow,
    bool canClimb,
    bool hasEvasion,
    bool hasFlyby,
    bool hasNimbleEscape,
    int maxLegendaryActions,
    int maxLegendaryResistances,
    Map<AbilityType, int> savingThrows,
  }) parseStatBlockBoundary(
    MinionStatBlock sb, {
    double challengeRating = 0.0,
  }) {
    final spellCorpus = _buildMonsterSpellCorpus(sb);
    final fullCorpus = _buildMonsterCorpus(sb);

    // 1. Spell Slots
    final slots = <int, int>{};
    if (spellCorpus.isNotEmpty) {
      for (final match in _slotPattern.allMatches(spellCorpus)) {
        final lvl = int.tryParse(match.group(1) ?? '');
        final count = int.tryParse(match.group(2) ?? '');
        if (lvl != null && count != null && lvl >= 1 && lvl <= 9) {
          slots[lvl] = count;
        }
      }

      if (slots.isEmpty) {
        final casterLvlMatch = _casterLvlPattern.firstMatch(spellCorpus);
        if (casterLvlMatch != null) {
          final casterLevel = int.tryParse(casterLvlMatch.group(1) ?? '') ?? 1;
          final matrix = MulticlassSlotMatrix.getSpellSlots(casterLevel);
          for (int i = 0; i < matrix.length; i++) {
            if (matrix[i] > 0) slots[i + 1] = matrix[i];
          }
        }
      }

      if (slots.isEmpty && (spellCorpus.contains('/day') || spellCorpus.contains('at will'))) {
        for (final spell in SpellbookLibrary.allSpells) {
          if (spell.level > 0 && _containsSpell(spellCorpus, spell.name)) {
            slots[spell.level] = (slots[spell.level] ?? 0) + 1;
          }
        }
      }
    }

    // 2. Known Spells
    final knownSpells = <String>[];
    if (spellCorpus.isNotEmpty) {
      for (final spell in SpellbookLibrary.allSpells) {
        if (_containsSpell(spellCorpus, spell.name)) {
          knownSpells.add(spell.id);
        }
      }
    }

    // 3. Spell Save DC
    int dc = 10;
    final dcMatch = _spellSaveDcPattern.firstMatch(fullCorpus);
    if (dcMatch != null) {
      final val = int.tryParse(dcMatch.group(1) ?? '');
      if (val != null) dc = val;
    } else {
      final pb = _computeProficiencyBonus(challengeRating);
      final castingMod = math.max(sb.intMod, math.max(sb.wisMod, sb.chaMod));
      dc = 8 + pb + castingMod;
    }

    // 4. Spell Attack Bonus
    int attackBonus = 0;
    final atkMatch = _spellAttackPattern.firstMatch(fullCorpus);
    if (atkMatch != null) {
      final clean = atkMatch.group(1)!.replaceAll('+', '').replaceAll(' ', '');
      final val = int.tryParse(clean);
      if (val != null) attackBonus = val;
    } else {
      final pb = _computeProficiencyBonus(challengeRating);
      final castingMod = math.max(sb.intMod, math.max(sb.wisMod, sb.chaMod));
      attackBonus = pb + castingMod;
    }

    // 5. Reach
    int maxReach = 5;
    for (final a in sb.actions) {
      final match = _reachPattern.firstMatch(a.description);
      if (match != null) {
        final r = int.tryParse(match.group(1) ?? '') ?? 5;
        if (r > maxReach) maxReach = r;
      }
    }

    // 6. Mobility & Aerial
    final speedLower = sb.speed.toLowerCase();
    final traitsText = sb.traits.map((t) => '${t.name} ${t.description}').join(' ').toLowerCase();
    final actionsText = sb.actions.map((a) => '${a.name} ${a.description}').join(' ').toLowerCase();

    final canFly = speedLower.contains('fly') && !speedLower.contains('fly 0');
    final hasHover = speedLower.contains('hover') || traitsText.contains('hover');
    final canSwim = speedLower.contains('swim') || traitsText.contains('amphibious') || traitsText.contains('water breathing');
    final canBurrow = speedLower.contains('burrow');
    final canClimb = speedLower.contains('climb');
    final hasEvasion = traitsText.contains('evasion') || actionsText.contains('evasion');
    final hasFlyby = traitsText.contains('flyby');
    final hasNimbleEscape = traitsText.contains('nimble escape');

    // 7. Legendary Actions & Resistances
    int maxLegendaryActions = 0;
    if (sb.legendaryActions.isNotEmpty || fullCorpus.contains('legendary action')) {
      maxLegendaryActions = 3;
    }

    int maxLegendaryResistances = 0;
    for (final t in sb.traits) {
      if (t.name.toLowerCase().contains('legendary resistance')) {
        final match = _rechargeDayPattern.firstMatch(t.name);
        if (match != null) {
          final count = int.tryParse(match.group(1) ?? '');
          if (count != null) {
            maxLegendaryResistances = count;
            break;
          }
        }
        maxLegendaryResistances = 3;
        break;
      }
    }

    // 8. Saving Throw Bonuses
    final savingThrows = <AbilityType, int>{};
    for (final ab in AbilityType.values) {
      savingThrows[ab] = _computeSavingThrowBonus(sb, ab);
    }

    return (
      spellSlots: slots,
      knownSpellIds: knownSpells,
      spellSaveDc: dc,
      spellAttackBonus: attackBonus,
      maxReachFt: maxReach,
      canFly: canFly,
      hasHover: hasHover,
      canSwim: canSwim,
      canBurrow: canBurrow,
      canClimb: canClimb,
      hasEvasion: hasEvasion,
      hasFlyby: hasFlyby,
      hasNimbleEscape: hasNimbleEscape,
      maxLegendaryActions: maxLegendaryActions,
      maxLegendaryResistances: maxLegendaryResistances,
      savingThrows: savingThrows,
    );
  }

  static bool _containsSpell(String corpus, String spellName) {
    final lowerName = spellName.toLowerCase();
    final escaped = RegExp.escape(lowerName);
    return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(corpus);
  }

  static String _buildMonsterSpellCorpus(MinionStatBlock sb) {
    final buffer = StringBuffer();
    for (final t in sb.traits) {
      final nameLower = t.name.toLowerCase();
      if (nameLower.contains('spell') ||
          nameLower.contains('magic') ||
          nameLower.contains('casting') ||
          nameLower.contains('pact') ||
          nameLower.contains('innate')) {
        buffer.writeln('${t.name}: ${t.description}');
      }
    }
    for (final a in sb.actions) {
      final nameLower = a.name.toLowerCase();
      if (nameLower.contains('spell') || nameLower.contains('cast')) {
        buffer.writeln('${a.name}: ${a.description}');
      }
    }
    return buffer.toString().toLowerCase().replaceAll('_', ' ').replaceAll('*', ' ');
  }

  static String _buildMonsterCorpus(MinionStatBlock sb) {
    final buffer = StringBuffer();
    for (final t in sb.traits) {
      buffer.writeln('${t.name}: ${t.description}');
    }
    for (final a in sb.actions) {
      buffer.writeln('${a.name}: ${a.description}');
    }
    for (final r in sb.reactions) {
      buffer.writeln('${r.name}: ${r.description}');
    }
    if (sb.specialTrait != null) {
      buffer.writeln(sb.specialTrait);
    }
    return buffer.toString().toLowerCase().replaceAll('_', ' ').replaceAll('*', ' ');
  }

  static int _computeProficiencyBonus(double cr) {
    if (cr >= 17) return 6;
    if (cr >= 13) return 5;
    if (cr >= 9) return 4;
    if (cr >= 5) return 3;
    return 2;
  }

  static int _computeSavingThrowBonus(MinionStatBlock sb, AbilityType ab) {
    final rawSaves = sb.savingThrows;
    if (rawSaves != null && rawSaves.isNotEmpty) {
      final pattern = _staticAbilitySavePatterns[ab];
      if (pattern != null) {
        final match = pattern.firstMatch(rawSaves);
        if (match != null) {
          final parsed = int.tryParse(match.group(1)!.replaceAll(' ', ''));
          if (parsed != null) return parsed;
        }
      }
    }

    return switch (ab) {
      AbilityType.strength => sb.strMod,
      AbilityType.dexterity => sb.dexMod,
      AbilityType.constitution => sb.conMod,
      AbilityType.intelligence => sb.intMod,
      AbilityType.wisdom => sb.wisMod,
      AbilityType.charisma => sb.chaMod,
    };
  }
}
