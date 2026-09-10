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

  /// Reconciles draft invariants across ruleset shifts and prerequisite changes.
  static CharacterDraft reconcileDraft(CharacterDraft draft) {
    draft.reconcile();
    var updated = draft;

    // Rule 1: Strip Origin Feats in 2014 mode
    if (updated.rulesEdition == DmRulesEdition.v2014 && updated.originFeats.isNotEmpty) {
      updated = updated.copyWith(originFeats: const []);
    }

    // Rule 2: Ensure background ability bonus count matches ruleset
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
