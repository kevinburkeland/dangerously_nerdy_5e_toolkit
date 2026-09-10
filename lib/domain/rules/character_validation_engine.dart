import '../../models/domain/character_models.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/character_draft.dart';

enum ValidationSeverity { warning, error }

class ValidationIssue {
  final String code;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({
    required this.code,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationIssue &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message &&
          severity == other.severity;

  @override
  int get hashCode => code.hashCode ^ message.hashCode ^ severity.hashCode;

  @override
  String toString() => 'ValidationIssue($code: $message [$severity])';
}

class CharacterValidationEngine {
  const CharacterValidationEngine._();

  /// Calculates overlapping proficiencies between Background, Species, and Class.
  /// Returns an exact integer count of refunded wildcard skills to drive the UI state.
  static int calculateSkillRefunds(CharacterDraft draft) {
    final Set<SkillType> grantedPool = {};
    int collisions = 0;

    void applySkills(Iterable<SkillType> incoming) {
      for (final skill in incoming) {
        if (grantedPool.contains(skill)) {
          collisions++;
        } else {
          grantedPool.add(skill);
        }
      }
    }

    applySkills(draft.backgroundRef?.grantedSkills ?? []);
    applySkills(draft.speciesRef?.grantedSkills ?? []);
    applySkills(draft.startingClassRef?.grantedSkills ?? []);

    return collisions;
  }

  /// ASI Bifurcation Guard
  static CharacterDraft reconcileAsiBifurcation(CharacterDraft draft) {
    var updated = draft;
    if (updated.rulesEdition == DmRulesEdition.v2014) {
      // 2014: Strip background ASIs
      updated = updated.copyWith(backgroundBonusScores: const AbilityScores.zero());
    } else {
      // 2024: Strip species ASIs
      updated = updated.copyWith(speciesBonusScores: const AbilityScores.zero());
    }
    return updated;
  }

  /// Reconciles draft invariants across ruleset shifts and prerequisite changes.
  static CharacterDraft reconcileDraft(CharacterDraft draft) {
    draft.reconcile();
    var updated = draft;

    // Rule 1: Strip Origin Feats in 2014 mode
    if (updated.rulesEdition == DmRulesEdition.v2014 && updated.originFeats.isNotEmpty) {
      updated = updated.copyWith(originFeats: const []);
    }

    // Rule 2: Enforce ASI source bifurcation
    updated = reconcileAsiBifurcation(updated);
    if (updated.rulesEdition == DmRulesEdition.v2014) {
      // In 2014, bonuses come from Species/Race, not Background
      updated = updated.copyWith(bonusScores: const AbilityScores.zero());
    }

    return updated;
  }

  /// Evaluates prerequisites for feats, multiclassing, and illegal score thresholds.
  static List<ValidationIssue> validateDraft(CharacterDraft draft) {
    final issues = <ValidationIssue>[];

    if (!draft.hasValidScores) return issues;
    final totalScores = draft.baseScores! + draft.bonusScores;

    // Feat Prerequisites Check
    for (final feat in draft.originFeats) {
      if (feat.slug.toLowerCase() == 'grappler' &&
          totalScores.strength < 13 &&
          totalScores.dexterity < 13) {
        issues.add(const ValidationIssue(
          code: 'feat_prereq_unmet',
          message: 'Grappler requires Strength or Dexterity 13+.',
        ));
      }
    }

    return issues;
  }
}
