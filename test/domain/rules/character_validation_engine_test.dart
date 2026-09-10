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

    test('Skill Overlap Resolver: calculateSkillRefunds accurately detects overlaps across sources', () {
      final draftNoCollision = CharacterDraft(
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
          grantedSkills: [SkillType.insight, SkillType.religion],
        ),
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
          grantedSkills: [SkillType.perception],
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'fighter',
          displayName: 'Fighter',
          grantedSkills: [SkillType.athletics],
        ),
      );

      expect(CharacterValidationEngine.calculateSkillRefunds(draftNoCollision), equals(0));

      // 1 Collision: Elf (Perception) + Sailor (Perception, Athletics)
      final draftOneCollision = CharacterDraft(
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'sailor',
          displayName: 'Sailor',
          grantedSkills: [SkillType.athletics, SkillType.perception],
        ),
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
          grantedSkills: [SkillType.perception],
        ),
      );
      expect(CharacterValidationEngine.calculateSkillRefunds(draftOneCollision), equals(1));

      // 2 Collisions: Background (Perception, Athletics) + Species (Perception) + Class (Athletics)
      final draftTwoCollisions = CharacterDraft(
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'sailor',
          displayName: 'Sailor',
          grantedSkills: [SkillType.athletics, SkillType.perception],
        ),
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'elf',
          displayName: 'Elf',
          grantedSkills: [SkillType.perception],
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'fighter',
          displayName: 'Fighter',
          grantedSkills: [SkillType.athletics],
        ),
      );
      expect(CharacterValidationEngine.calculateSkillRefunds(draftTwoCollisions), equals(2));
    });

    test('ASI Bifurcation: 2014 strips background ASIs while 2024 strips species ASIs', () {
      final initialDraft2014 = CharacterDraft(
        rulesEdition: DmRulesEdition.v2014,
        backgroundBonusScores: const AbilityScores(strength: 2, constitution: 1),
        speciesBonusScores: const AbilityScores(dexterity: 2),
      );

      final bifurcated2014 = CharacterValidationEngine.reconcileAsiBifurcation(initialDraft2014);
      expect(bifurcated2014.backgroundBonusScores, equals(const AbilityScores.zero()));
      expect(bifurcated2014.speciesBonusScores.dexterity, equals(2));

      final initialDraft2024 = CharacterDraft(
        rulesEdition: DmRulesEdition.v2024,
        backgroundBonusScores: const AbilityScores(strength: 2, constitution: 1),
        speciesBonusScores: const AbilityScores(dexterity: 2),
      );

      final bifurcated2024 = CharacterValidationEngine.reconcileAsiBifurcation(initialDraft2024);
      expect(bifurcated2024.speciesBonusScores, equals(const AbilityScores.zero()));
      expect(bifurcated2024.backgroundBonusScores.strength, equals(2));
      expect(bifurcated2024.backgroundBonusScores.constitution, equals(1));
    });
  });
}
