import '../models/dm_screen_data.dart' show DmRulesEdition;
import '../models/domain/character_models.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../models/spellbook_data.dart'
    show SpellScalingFormula, SpellbookLibrary;

/// Parsed result of a spell damage or scaling formula field.
typedef ParsedSpellFormula = ({
  List<DiceRollTerm> dice,
  int constantSum,
  int modCount,
});

/// Resolved formula plan for [CharacterSheetController.castSpell], or an error
/// message when the formula cannot be rolled.
typedef CastSpellPlan = ({
  ParsedSpellFormula? parsedBase,
  ParsedSpellFormula? parsedScale,
  int spellModContribution,
  String? errorMessage,
});

/// Pure helpers for parsing spell cast formulas and selecting the caster's
/// spellcasting modifier class for `CharacterSheetController.castSpell`.
class SpellCastFormulaResolver {
  SpellCastFormulaResolver._();

  /// Validates and resolves base formula, upcast scaling formula, and
  /// spellcasting modifier contribution for [spell] at [delta] levels above base.
  static CastSpellPlan resolvePlan(
    Spell spell, {
    required int delta,
    required EvaluatedCharacterStats stats,
    required RulesetEdition rulesEdition,
    SpellScalingFormula? scalingRule,
  }) {
    final baseFormula = spell.damageMath.firstOrNull?.diceFormula ??
        spell.customProperties['rollFormula']?.toString() ??
        '';
    final hasBaseFormula = baseFormula.trim().isNotEmpty;
    ParsedSpellFormula? parsedBase;
    if (hasBaseFormula) {
      parsedBase = parseSpellFormulaField(baseFormula);
      if (parsedBase == null) {
        return (
          parsedBase: null,
          parsedScale: null,
          spellModContribution: 0,
          errorMessage: 'Can\'t roll "$baseFormula": not dice notation',
        );
      }
    }

    ParsedSpellFormula? parsedScale;
    String? activeScalingFormula;
    if (delta > 0) {
      String? scalingStr;
      for (final dm in spell.damageMath) {
        if (dm.scalingFormula != null && dm.scalingFormula!.trim().isNotEmpty) {
          scalingStr = dm.scalingFormula;
          break;
        }
      }
      scalingStr ??= spell.customProperties['scalingFormula']?.toString();

      if (scalingStr != null && scalingStr.trim().isNotEmpty) {
        activeScalingFormula = scalingStr;
        parsedScale = parseSpellFormulaField(scalingStr);
        if (parsedScale == null) {
          return (
            parsedBase: null,
            parsedScale: null,
            spellModContribution: 0,
            errorMessage: 'Can\'t roll "$scalingStr": not dice notation',
          );
        }
      } else if (spell.higherLevelsMarkdown != null) {
        final proseMatch =
            DiceExpression.findAll(spell.higherLevelsMarkdown!).firstOrNull;
        if (proseMatch != null &&
            !proseMatch.expression.diceTerms.any((t) => t.isNegative)) {
          final proseDice = <DiceRollTerm>[
            for (final dt in proseMatch.expression.diceTerms) dt,
          ];
          var proseModCount = 0;
          for (final term in proseMatch.expression.terms) {
            if (term is DiceModTerm) {
              proseModCount += term.isNegative ? -1 : 1;
            }
          }
          parsedScale = (
            dice: proseDice,
            constantSum: proseMatch.expression.constantSum,
            modCount: proseModCount,
          );
        }
      }
    }

    final baseModCount = parsedBase?.modCount ?? 0;
    final scaleModCount = delta > 0 ? (parsedScale?.modCount ?? 0) : 0;
    final dmEdition = rulesEdition == RulesetEdition.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final effectiveScalingRule = scalingRule ??
        (SpellbookLibrary.getSpellById(spell.id.slug) ??
                SpellbookLibrary.getSpellByName(spell.name))
            ?.getRules(dmEdition)
            .scalingFormula;
    final addsAbilityModOnce =
        (effectiveScalingRule?.addsAbilityMod ?? false) && baseModCount == 0;
    final totalModMultiplier =
        baseModCount + (delta * scaleModCount) + (addsAbilityModOnce ? 1 : 0);

    var spellModContribution = 0;
    if (totalModMultiplier != 0) {
      final castMod = resolveSpellcastingModifierForSpell(
        spell,
        stats: stats,
        rulesEdition: rulesEdition,
      );
      if (castMod == null) {
        final displayFormula =
            hasBaseFormula ? baseFormula : (activeScalingFormula ?? '');
        return (
          parsedBase: null,
          parsedScale: null,
          spellModContribution: 0,
          errorMessage:
              'Can\'t roll "$displayFormula": no spellcasting modifier',
        );
      }
      spellModContribution = totalModMultiplier * castMod;
    }

    return (
      parsedBase: parsedBase,
      parsedScale: parsedScale,
      spellModContribution: spellModContribution,
      errorMessage: null,
    );
  }

  /// Resolves the spellcasting ability modifier for [spell] given [stats] and
  /// the caster's [rulesEdition].
  ///
  /// Class selection rule:
  /// - If the character has no spellcasting class (`stats.spellcastingModifiers`
  ///   is empty), returns `null`.
  /// - If the character has one spellcasting class, returns that class's modifier.
  /// - If the character has multiple spellcasting classes, looks up [spell] in
  ///   [SpellbookLibrary] (by id slug, then by name) and checks each class's spell
  ///   list (`rules.classes`) in the same order as `stats.spellAttackBonuses`
  ///   (matching `LevelUpWizardDialog._targetSpellClass` slug-to-[SpellClass]
  ///   mapping), returning the first spellcasting class whose spell list holds
  ///   the spell.
  /// - If none of the character's spellcasting classes lists the spell (or the
  ///   spell is custom/unlisted), falls back to the primary class
  ///   (`stats.spellcastingModifiers.values.first`, matching
  ///   `stats.spellAttackBonus`).
  static int? resolveSpellcastingModifierForSpell(
    Spell spell, {
    required EvaluatedCharacterStats stats,
    required RulesetEdition rulesEdition,
  }) {
    final mods = stats.spellcastingModifiers;
    if (mods.isEmpty) return null;

    final dmEdition = rulesEdition == RulesetEdition.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final spellItem = SpellbookLibrary.getSpellById(spell.id.slug) ??
        SpellbookLibrary.getSpellByName(spell.name);

    if (spellItem != null) {
      final spellClasses = spellItem.getRules(dmEdition).classes;
      for (final entry in mods.entries) {
        final spellClass = _spellClassFromKey(entry.key);
        if (spellClass != null && spellClasses.contains(spellClass)) {
          return entry.value;
        }
      }
    }

    return mods.values.first;
  }

  static SpellClass? _spellClassFromKey(String key) {
    final lower = key.trim().toLowerCase();
    if (lower.contains('wizard') ||
        lower.contains('eldritch_knight') ||
        lower.contains('eldritch-knight') ||
        lower.contains('arcane_trickster') ||
        lower.contains('arcane-trickster')) {
      return SpellClass.wizard;
    }
    if (lower.contains('cleric')) return SpellClass.cleric;
    if (lower.contains('druid')) return SpellClass.druid;
    if (lower.contains('bard')) return SpellClass.bard;
    if (lower.contains('sorcerer')) return SpellClass.sorcerer;
    if (lower.contains('warlock')) return SpellClass.warlock;
    if (lower.contains('ranger')) return SpellClass.ranger;
    if (lower.contains('paladin')) return SpellClass.paladin;
    return null;
  }

  /// Parses a spell damage or scaling formula field into combined positive die
  /// terms, flat constant bonus, and signed `mod` term count.
  ///
  /// Fallback rule when [DiceExpression.tryParse] cannot parse the entire string
  /// (after also accepting a leading `+` prefix such as `"+1d8"`):
  /// - Extracts all [DiceExpression.findAll] matches.
  /// - Inspects every non-match gap (before the first match, between consecutive
  ///   matches, and after the last match). If any gap contains a `+` or `-` sign,
  ///   or if a non-empty gap immediately precedes a match that begins with `+` or
  ///   `-` (placing a sign next to a non-match token such as `spellmod`, a stray
  ///   number, or a trailing operator), returns `null` so the formula is treated
  ///   as unreadable and never partially rolled.
  /// - Plain descriptive words with no `+` or `-` sign next to them (e.g.
  ///   `"2d6 fire"`, `"1d8 cold damage"`) remain allowed.
  /// - Also returns `null` if any die group is negative (which
  ///   [DiceRollResult.rollPool] cannot represent) or if no dice, constant, or
  ///   `mod` terms are present.
  static ParsedSpellFormula? parseSpellFormulaField(String rawFormula) {
    final trimmed = rawFormula.trim();
    if (trimmed.isEmpty) return null;

    var whole = DiceExpression.tryParse(trimmed);
    if (whole == null && trimmed.startsWith('+')) {
      final afterPlus = trimmed.substring(1).trimLeft();
      if (afterPlus.isNotEmpty &&
          !afterPlus.startsWith('+') &&
          !afterPlus.startsWith('-')) {
        whole = DiceExpression.tryParse(afterPlus);
      }
    }

    final List<DiceExpression> expressions;
    if (whole != null) {
      expressions = <DiceExpression>[whole];
    } else {
      final matches = DiceExpression.findAll(rawFormula);
      if (matches.isEmpty) return null;

      var cursor = 0;
      for (final m in matches) {
        final gap = rawFormula.substring(cursor, m.start);
        final isBareLeadingPlus = cursor == 0 && gap.trim() == '+';
        if (!isBareLeadingPlus && (gap.contains('+') || gap.contains('-'))) {
          return null;
        }
        final matchLead = rawFormula.substring(m.start, m.end).trimLeft();
        if (!isBareLeadingPlus &&
            gap.trim().isNotEmpty &&
            (matchLead.startsWith('+') || matchLead.startsWith('-'))) {
          return null;
        }
        cursor = m.end;
      }
      final trailing = rawFormula.substring(cursor);
      if (trailing.contains('+') || trailing.contains('-')) {
        return null;
      }

      expressions = [for (final m in matches) m.expression];
    }

    final dice = <DiceRollTerm>[];
    var constantSum = 0;
    var modCount = 0;
    for (final expr in expressions) {
      if (expr.diceTerms.any((t) => t.isNegative)) {
        return null;
      }
      for (final dt in expr.diceTerms) {
        dice.add(dt);
      }
      constantSum += expr.constantSum;
      for (final term in expr.terms) {
        if (term is DiceModTerm) {
          modCount += term.isNegative ? -1 : 1;
        }
      }
    }
    if (dice.isEmpty && constantSum == 0 && modCount == 0) return null;
    return (dice: dice, constantSum: constantSum, modCount: modCount);
  }
}
