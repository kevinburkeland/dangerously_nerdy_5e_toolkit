import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/rules/character_validation_engine.dart';

void main() {
  group('CharacterValidationEngine & Draft Invariants', () {
    test('Draft Reconciliation Test: switching rulesEdition to 2014 strips origin feats and resets background bonuses', () {
      final draft = CharacterDraft(rulesEdition: DmRulesEdition.v2024);
      draft.originFeats.add(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'alert',
        displayName: 'Alert',
      ));
      draft.bonusScores = const AbilityScores(strength: 2, constitution: 1);

      expect(draft.originFeats, isNotEmpty);
      expect(draft.bonusScores.strength, equals(2));

      // Switch rules edition to 2014
      draft.rulesEdition = DmRulesEdition.v2014;

      // Invariant reconciliation should have automatically sanitized originFeats and bonusScores
      expect(draft.originFeats, isEmpty);
      expect(draft.bonusScores, equals(const AbilityScores.zero()));

      // Also verify via CharacterValidationEngine.reconcileDraft
      final reconciled = CharacterValidationEngine.reconcileDraft(draft);
      expect(reconciled.originFeats, isEmpty);
      expect(reconciled.bonusScores, equals(const AbilityScores.zero()));
    });

    test('Prerequisite Validation Test: Grappler requires STR or DEX 13+', () {
      final draft = CharacterDraft(
        rulesEdition: DmRulesEdition.v2024,
        baseScores: const AbilityScores(
          strength: 14,
          dexterity: 10,
          constitution: 10,
          intelligence: 10,
          wisdom: 10,
          charisma: 10,
        ),
      );
      draft.originFeats.add(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'grappler',
        displayName: 'Grappler',
      ));

      // With STR 14, Grappler prerequisite is met
      var issues = CharacterValidationEngine.validateDraft(draft);
      expect(issues.where((i) => i.code == 'feat_prereq_unmet'), isEmpty);

      // Mutate STR to 8 (and DEX remains 10, so both < 13)
      draft.baseScores = const AbilityScores(
        strength: 8,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      );

      issues = CharacterValidationEngine.validateDraft(draft);
      expect(issues.any((i) => i.code == 'feat_prereq_unmet'), isTrue);
      final issue = issues.firstWhere((i) => i.code == 'feat_prereq_unmet');
      expect(issue.message, contains('Grappler requires Strength or Dexterity 13+'));
    });

    test('Prerequisite met when DEX is 13+ even if STR is below 13', () {
      final draft = CharacterDraft(
        rulesEdition: DmRulesEdition.v2024,
        baseScores: const AbilityScores(
          strength: 8,
          dexterity: 14,
          constitution: 10,
          intelligence: 10,
          wisdom: 10,
          charisma: 10,
        ),
      );
      draft.originFeats.add(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'grappler',
        displayName: 'Grappler',
      ));

      final issues = CharacterValidationEngine.validateDraft(draft);
      expect(issues.where((i) => i.code == 'feat_prereq_unmet'), isEmpty);
    });

    test('Validation skips cleanly if baseScores are null', () {
      final draft = CharacterDraft(
        rulesEdition: DmRulesEdition.v2024,
      );
      draft.originFeats.add(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'grappler',
        displayName: 'Grappler',
      ));

      final issues = CharacterValidationEngine.validateDraft(draft);
      expect(issues, isEmpty);
    });
  });
}
