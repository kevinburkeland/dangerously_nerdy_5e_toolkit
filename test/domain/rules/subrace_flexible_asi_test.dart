import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart' show DmRulesEdition;
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';

void main() {
  group('Subrace Flexible ASI Selection & Pool Constraints', () {
    test('Subrace serialization preserves flexibleAbilityPool, count, and bonus', () {
      const subrace = Subrace(
        id: EntityId(slug: 'custom-artifice-lineage', ruleset: RulesetVersion.v2014),
        name: 'Custom Artifice Lineage',
        raceSlug: 'human',
        traitsMarkdown: 'Inventive tinkering traits.',
        fixedAbilityBonuses: {'con': 2},
        flexibleAbilityCount: 1,
        flexibleAbilityBonus: 1,
        flexibleAbilityPool: ['dex', 'int'],
      );

      final map = subrace.toMap();
      expect(map['flexibleAbilityPool'], equals(['dex', 'int']));
      expect(map['flexibleAbilityCount'], equals(1));
      expect(map['flexibleAbilityBonus'], equals(1));

      final restored = Subrace.fromMap(map);
      expect(restored.flexibleAbilityPool, equals(['dex', 'int']));
      expect(restored.flexibleAbilityCount, equals(1));
      expect(restored.flexibleAbilityBonus, equals(1));
      expect(restored.fixedAbilityBonuses2014, equals({'con': 2}));
    });

    test('CharacterDraft.reconcile in 2014 mode honors flexibleAbilityPool and does not default to Strength', () {
      const subraceRef = EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: 'custom-artifice-lineage',
        displayName: 'Custom Artifice Lineage',
        customProperties: {
          'flexibleAbilityPool': ['dex', 'int'],
          'flexibleAbilityCount': 1,
          'flexibleAbilityBonus': 1,
          'fixedAbilityBonuses': {'con': 2},
        },
      );

      final draft = CharacterDraft(
        characterName: 'Artificer Scholar',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        subraceRef: subraceRef,
      );

      // Verify that reconcile populated pendingFlexibleAbilityChoices from the pool
      expect(draft.pendingFlexibleAbilityChoices, isNotEmpty);
      expect(draft.pendingFlexibleAbilityChoices.first, equals(AbilityType.dexterity));
      expect(draft.pendingFlexibleAbilityChoices.contains(AbilityType.strength), isFalse);
    });

    test('CharacterDraft.reconcile purges invalid selections outside the flexibleAbilityPool', () {
      const subraceRef = EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: 'custom-artifice-lineage',
        displayName: 'Custom Artifice Lineage',
        customProperties: {
          'flexibleAbilityPool': ['dex', 'int'],
          'flexibleAbilityCount': 1,
        },
      );

      final draft = CharacterDraft(
        characterName: 'Artificer Scholar',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        subraceRef: subraceRef,
        pendingFlexibleAbilityChoices: [AbilityType.strength],
      );

      // Reconcile must purge Strength and fallback to first in pool (Dexterity)
      draft.reconcile();
      expect(draft.pendingFlexibleAbilityChoices, equals([AbilityType.dexterity]));
    });

    test('CharacterDraft.reconcile retains valid selections inside flexibleAbilityPool', () {
      const subraceRef = EntityReference<DomainEntity>(
        refType: EntityType.species,
        slug: 'custom-artifice-lineage',
        displayName: 'Custom Artifice Lineage',
        customProperties: {
          'flexibleAbilityPool': ['dex', 'int'],
          'flexibleAbilityCount': 1,
        },
      );

      final draft = CharacterDraft(
        characterName: 'Artificer Scholar',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        subraceRef: subraceRef,
        pendingFlexibleAbilityChoices: [AbilityType.intelligence],
      );

      draft.reconcile();
      expect(draft.pendingFlexibleAbilityChoices, equals([AbilityType.intelligence]));
    });
  });
}
