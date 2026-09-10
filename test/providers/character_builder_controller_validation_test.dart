import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_builder_controller.dart';

void main() {
  group('CharacterBuilderController Invariant & Refund Tests', () {
    test('Resetting orphaned skill refunds when overlapping skills change', () {
      final controller = CharacterBuilderController(initialMode: 'standard');
      // Set background to Acolyte which grants Insight and Religion
      controller.setBackgroundSlug('acolyte');

      // Select Insight and Religion directly in the draft to force 2 overlaps
      controller.setSelectedSkills({SkillType.insight, SkillType.religion});

      expect(controller.grantedBackgroundSkills, containsAll([SkillType.insight, SkillType.religion]));
      // Overlaps should require 2 refunds
      expect(controller.refundedSkillChoices, equals(2));

      // Resolve both refunds by choosing Acrobatics and Stealth
      controller.resolveRefundedSkill(SkillType.acrobatics);
      controller.resolveRefundedSkill(SkillType.stealth);
      expect(controller.bonusReplacementSkills, containsAll([SkillType.acrobatics, SkillType.stealth]));
      expect(controller.refundedSkillChoices, equals(0));

      // Now deselect Religion from selectedSkills so only 1 overlap remains (Insight)
      controller.setSelectedSkills({SkillType.insight});

      // Orphaned skill refund should be automatically pruned so replacement count does not exceed 1
      expect(controller.bonusReplacementSkills.length, equals(1));
      expect(controller.refundedSkillChoices, equals(0));

      // Now clear background entirely (0 overlaps)
      controller.setBackgroundSlug(null);
      expect(controller.bonusReplacementSkills, isEmpty);
      expect(controller.refundedSkillChoices, equals(0));
    });

    test('Controller reconciles origin feats when switching from 2024 to 2014', () {
      final controller = CharacterBuilderController(
        initialEdition: DmRulesEdition.v2024,
      );

      controller.addOriginFeat(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'magic-initiate',
        displayName: 'Magic Initiate',
      ));
      expect(controller.draft.originFeats, isNotEmpty);

      controller.setRulesEdition(DmRulesEdition.v2014);
      expect(controller.draft.originFeats, isEmpty);
    });

    test('Controller evaluates validation issues on draft mutation', () {
      final controller = CharacterBuilderController(
        initialMode: 'manual',
        initialEdition: DmRulesEdition.v2024,
      );
      controller.setManualScore(AbilityType.strength, 8);
      controller.setManualScore(AbilityType.dexterity, 10);
      controller.setScores(const AbilityScores(
        strength: 8,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      ));

      controller.addOriginFeat(const EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: 'grappler',
        displayName: 'Grappler',
      ));

      final issues = controller.validationIssues;
      expect(issues.any((i) => i.code == 'feat_prereq_unmet'), isTrue);

      // Now boost STR to 14
      controller.setScores(const AbilityScores(
        strength: 14,
        dexterity: 10,
        constitution: 10,
        intelligence: 10,
        wisdom: 10,
        charisma: 10,
      ));

      expect(controller.validationIssues.where((i) => i.code == 'feat_prereq_unmet'), isEmpty);
    });
  });
}
