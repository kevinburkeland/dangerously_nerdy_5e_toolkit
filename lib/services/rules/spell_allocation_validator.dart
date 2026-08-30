import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../models/domain/entity_reference.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../repository/reference_resolver.dart';

/// Specification of spell quota limits for a given class slice at a specific level.
@immutable
class SpellAllocationLimits {
  final int maxCantrips;
  final int maxSpellsKnown; // Non-zero for spontaneous/known casters (Sorcerer, Bard, Warlock, Ranger 2014)
  final int maxSpellsPrepared; // Non-zero for prepared casters (Wizard, Cleric, Druid, Paladin, Artificer)
  final int maxSpellbookInitialScribe; // 6 for Level 1 Wizard
  final int maxSpellbookLevelUpScribe; // 2 per level-up for Wizard
  final int maxSpellSlotLevel; // Highest spell slot tier available for this class slice
  final bool isSpellcaster;
  final String castingAbility;

  const SpellAllocationLimits({
    required this.maxCantrips,
    required this.maxSpellsKnown,
    required this.maxSpellsPrepared,
    this.maxSpellbookInitialScribe = 0,
    this.maxSpellbookLevelUpScribe = 0,
    required this.maxSpellSlotLevel,
    required this.isSpellcaster,
    required this.castingAbility,
  });

  const SpellAllocationLimits.nonCaster()
      : maxCantrips = 0,
        maxSpellsKnown = 0,
        maxSpellsPrepared = 0,
        maxSpellbookInitialScribe = 0,
        maxSpellbookLevelUpScribe = 0,
        maxSpellSlotLevel = 0,
        isSpellcaster = false,
        castingAbility = 'Intelligence';
}

/// Validation result container for spell selection.
@immutable
class SpellValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const SpellValidationResult.valid()
      : isValid = true,
        errors = const [],
        warnings = const [];

  const SpellValidationResult.invalid(this.errors, [this.warnings = const []])
      : isValid = false;
}

/// Pure Dart rules validator enforcing SRD 5.1 (2014) and SRD 5.2 (2024) RAW spell invariants.
class SpellAllocationValidator {
  SpellAllocationValidator._();

  /// Known spells progression table for Bard (levels 1-20)
  static const Map<int, int> _bardSpellsKnown = {
    1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 9, 7: 10, 8: 11, 9: 12, 10: 14,
    11: 15, 12: 15, 13: 16, 14: 18, 15: 19, 16: 19, 17: 20, 18: 22, 19: 22, 20: 22,
  };

  /// Known spells progression table for Sorcerer (levels 1-20)
  static const Map<int, int> _sorcererSpellsKnown = {
    1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9, 9: 10, 10: 11,
    11: 12, 12: 12, 13: 13, 14: 13, 15: 14, 16: 14, 17: 15, 18: 15, 19: 15, 20: 15,
  };

  /// Known spells progression table for Warlock (levels 1-20)
  static const Map<int, int> _warlockSpellsKnown = {
    1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8, 8: 9, 9: 10, 10: 11,
    11: 11, 12: 11, 13: 12, 14: 12, 15: 13, 16: 13, 17: 14, 18: 14, 19: 15, 20: 15,
  };

  /// Known spells progression table for Ranger (2014, levels 1-20)
  static const Map<int, int> _rangerSpellsKnown2014 = {
    1: 0, 2: 2, 3: 3, 4: 3, 5: 4, 6: 4, 7: 5, 8: 5, 9: 6, 10: 6,
    11: 7, 12: 7, 13: 8, 14: 8, 15: 9, 16: 9, 17: 10, 18: 10, 19: 11, 20: 11,
  };

  /// Calculates max spell slot tier available for a single class slice
  static int getMaxSpellTierForClass({
    required String classSlug,
    required int classLevel,
    DmRulesEdition edition = DmRulesEdition.v2014,
  }) {
    final slug = classSlug.toLowerCase();
    final lvl = classLevel.clamp(1, 20);

    if (slug == 'wizard' || slug == 'sorcerer' || slug == 'cleric' || slug == 'druid' || slug == 'bard') {
      return (lvl + 1) ~/ 2; // Full casters: 1-2: 1st, 3-4: 2nd, 5-6: 3rd, ..., 17-20: 9th
    } else if (slug == 'warlock') {
      if (lvl >= 9) return 5;
      return (lvl + 1) ~/ 2;
    } else if (slug == 'paladin' || slug == 'ranger') {
      if (edition == DmRulesEdition.v2024) {
        return ((lvl + 1) ~/ 4) + 1; // 2024 half casters gain 1st level spells at level 1
      }
      if (lvl < 2) return 0;
      return ((lvl + 1) ~/ 4) + 1; // 2014: lvl 2-4: 1st, 5-8: 2nd, 9-12: 3rd, 13-16: 4th, 17-20: 5th
    } else if (slug == 'artificer') {
      return ((lvl + 1) ~/ 4) + 1;
    } else if (slug.contains('eldritch_knight') || slug.contains('arcane_trickster')) {
      if (lvl < 3) return 0;
      if (lvl >= 19) return 4;
      if (lvl >= 13) return 3;
      if (lvl >= 7) return 2;
      return 1;
    }
    return 0;
  }

  /// Returns RAW allocation limits for a class slice at a specific class level.
  static SpellAllocationLimits getLimitsForClass({
    required String classSlug,
    required int classLevel,
    required int abilityModifier,
    DmRulesEdition edition = DmRulesEdition.v2014,
  }) {
    final slug = classSlug.toLowerCase();
    final lvl = classLevel.clamp(1, 20);
    final maxTier = getMaxSpellTierForClass(classSlug: slug, classLevel: lvl, edition: edition);

    switch (slug) {
      case 'wizard':
        final cantrips = (lvl >= 10) ? 5 : ((lvl >= 4) ? 4 : 3);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellbookInitialScribe: 6,
          maxSpellbookLevelUpScribe: 2,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Intelligence',
        );

      case 'sorcerer':
        final cantrips = (lvl >= 10) ? 6 : ((lvl >= 4) ? 5 : 4);
        final known = _sorcererSpellsKnown[lvl] ?? 2;
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known,
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
        );

      case 'bard':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final known = _bardSpellsKnown[lvl] ?? 4;
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known,
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
        );

      case 'cleric':
        final cantrips = (lvl >= 10) ? 5 : ((lvl >= 4) ? 4 : 3);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Wisdom',
        );

      case 'druid':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final maxPrepared = math.max(1, lvl + abilityModifier);
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Wisdom',
        );

      case 'warlock':
        final cantrips = (lvl >= 10) ? 4 : ((lvl >= 4) ? 3 : 2);
        final known = _warlockSpellsKnown[lvl] ?? 2;
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: known,
          maxSpellsPrepared: 0,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Charisma',
        );

      case 'paladin':
        final maxPrepared = (edition == DmRulesEdition.v2024)
            ? math.max(1, ((lvl + 1) ~/ 2) + abilityModifier)
            : (lvl < 2 ? 0 : math.max(1, (lvl ~/ 2) + abilityModifier));
        return SpellAllocationLimits(
          maxCantrips: 0,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: lvl >= (edition == DmRulesEdition.v2024 ? 1 : 2),
          castingAbility: 'Charisma',
        );

      case 'ranger':
        if (edition == DmRulesEdition.v2024) {
          const cantrips = 2;
          final maxPrepared = math.max(1, ((lvl + 1) ~/ 2) + abilityModifier);
          return SpellAllocationLimits(
            maxCantrips: cantrips,
            maxSpellsKnown: 0,
            maxSpellsPrepared: maxPrepared,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: true,
            castingAbility: 'Wisdom',
          );
        } else {
          final known = _rangerSpellsKnown2014[lvl] ?? 0;
          return SpellAllocationLimits(
            maxCantrips: 0,
            maxSpellsKnown: known,
            maxSpellsPrepared: 0,
            maxSpellSlotLevel: maxTier,
            isSpellcaster: lvl >= 2,
            castingAbility: 'Wisdom',
          );
        }

      case 'artificer':
        final cantrips = (lvl >= 14) ? 4 : ((lvl >= 10) ? 3 : 2);
        final maxPrepared = math.max(1, (lvl ~/ 2) + abilityModifier);
        return SpellAllocationLimits(
          maxCantrips: cantrips,
          maxSpellsKnown: 0,
          maxSpellsPrepared: maxPrepared,
          maxSpellSlotLevel: maxTier,
          isSpellcaster: true,
          castingAbility: 'Intelligence',
        );

      default:
        return const SpellAllocationLimits.nonCaster();
    }
  }

  /// Audits and validates a character creation or level-up spell payload against RAW restrictions.
  static SpellValidationResult validateSpellSelection({
    required String targetClassSlug,
    required int targetClassLevel,
    required int castingAbilityModifier,
    required List<EntityReference<Spell>> cantrips,
    required List<EntityReference<Spell>> spellsKnown,
    required List<EntityReference<Spell>> spellsPrepared,
    List<EntityReference<Spell>> spellbookSpells = const [],
    required DmRulesEdition edition,
    ReferenceResolver? resolver,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    final limits = getLimitsForClass(
      classSlug: targetClassSlug,
      classLevel: targetClassLevel,
      abilityModifier: castingAbilityModifier,
      edition: edition,
    );

    if (!limits.isSpellcaster) {
      if (cantrips.isNotEmpty || spellsKnown.isNotEmpty || spellsPrepared.isNotEmpty) {
        errors.add('Class $targetClassSlug is not a spellcasting class at level $targetClassLevel.');
      }
      return SpellValidationResult.invalid(errors);
    }

    // 1. Cantrip Count Check
    if (cantrips.length > limits.maxCantrips) {
      errors.add(
        'Selected ${cantrips.length} cantrips, but $targetClassSlug at level $targetClassLevel allows a maximum of ${limits.maxCantrips}.',
      );
    }

    // 2. Wizard Spellbook Initial Scribing Check
    if (targetClassSlug.toLowerCase() == 'wizard' && targetClassLevel == 1) {
      final effectiveScribeCount = spellbookSpells.isNotEmpty ? spellbookSpells.length : spellsKnown.length;
      if (effectiveScribeCount != 6) {
        errors.add(
          'A Level 1 Wizard must start with exactly 6 1st-level spells in their spellbook (selected $effectiveScribeCount).',
        );
      }
    }

    // 3. Spontaneous Spells Known Count Check
    if (limits.maxSpellsKnown > 0) {
      if (spellsKnown.length > limits.maxSpellsKnown) {
        errors.add(
          'Selected ${spellsKnown.length} spells known, exceeding the maximum allowed limit of ${limits.maxSpellsKnown} for $targetClassSlug level $targetClassLevel.',
        );
      }
    }

    // 4. Prepared Spells Limit Check
    if (limits.maxSpellsPrepared > 0) {
      if (spellsPrepared.length > limits.maxSpellsPrepared) {
        errors.add(
          'Prepared ${spellsPrepared.length} spells, exceeding the prepared limit of ${limits.maxSpellsPrepared} (Level $targetClassLevel + Ability Mod $castingAbilityModifier).',
        );
      }
    }

    // 5. Spell Tier Gating Check (Resolving actual spell entity if resolver is provided)
    if (resolver != null) {
      final allSelectedSpells = {...cantrips, ...spellsKnown, ...spellsPrepared, ...spellbookSpells};
      for (final ref in allSelectedSpells) {
        final res = resolver.resolveTyped<Spell>(ref);
        if (res.isResolved && res.entity != null) {
          final spell = res.entity!;
          final isCantrip = cantrips.any((c) => c.slug == ref.slug);

          if (isCantrip && spell.level != 0) {
            errors.add('Spell "${spell.name}" is Level ${spell.level} but was assigned as a cantrip.');
          } else if (!isCantrip && spell.level > limits.maxSpellSlotLevel) {
            errors.add(
              'Spell "${spell.name}" is Level ${spell.level}, but $targetClassSlug at level $targetClassLevel can only cast up to Level ${limits.maxSpellSlotLevel} spells.',
            );
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      return SpellValidationResult.invalid(errors, warnings);
    }
    return const SpellValidationResult.valid();
  }
}
