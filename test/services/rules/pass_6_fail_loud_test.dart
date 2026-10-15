import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';

void main() {
  setUp(() {
    Dnd5eRuleset.resetForTesting();
  });

  tearDown(() {
    // Restore production catalog so subsequent tests in the suite have it installed
    Dnd5eRuleset.resetForTesting();
    installRulesetCatalog();
  });

  group('Pass 6: Fail-Loud Collaborator Invariant Tests', () {
    test('1. Class lookup through CharacterEvaluationEngine.evaluate throws StateError', () {
      const hero = Character(
        id: EntityId(slug: 'hero-1', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>.empty(
                refType: EntityType.classDefinition,
                slug: 'alchemist',
                displayName: 'Alchemist',
              ),
              level: 1,
              hitDie: 'd8',
            ),
          ],
        ),
      );
      expect(
        () => CharacterEvaluationEngine.evaluate(hero),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('2. Spell slots through MulticlassSlotMatrix throws StateError', () {
      const hero = Character(
        id: EntityId(slug: 'hero-2', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference<DomainEntity>.empty(
                refType: EntityType.classDefinition,
                slug: 'custom-mage',
                displayName: 'Custom Mage',
              ),
              level: 1,
              hitDie: 'd6',
            ),
          ],
        ),
      );
      expect(
        () => MulticlassSlotMatrix.calculateSpellSlots(hero),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('3. Feat lookup through CharacterEvaluationEngine.evaluate throws StateError', () {
      const hero = Character(
        id: EntityId(slug: 'hero-3', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        feats: [
          EntityReference<DomainEntity>.empty(
            refType: EntityType.feat,
            slug: 'tough',
            displayName: 'Tough',
          ),
        ],
      );
      expect(
        () => CharacterEvaluationEngine.evaluate(hero),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('4. Magic item lookup through CharacterEvaluationEngine.evaluate throws StateError', () {
      final hero = Character(
        id: const EntityId(slug: 'hero-4', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: const EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        inventory: [
          InventoryItemInstance(
            instanceId: 'ring-1',
            itemRef: const EntityReference<DomainEntity>.empty(
              refType: EntityType.item,
              slug: 'ring-of-protection',
              displayName: 'Ring of Protection',
            ),
            isAttuned: true,
            isEquipped: true,
          ),
        ],
      );
      expect(
        () => CharacterEvaluationEngine.evaluate(hero),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('5. Always-prepared spells through SpellAllocationValidator throws StateError', () {
      expect(
        () => SpellAllocationValidator.getLimitsForClass(
          classSlug: 'cleric',
          subclassSlug: 'life-domain',
          classLevel: 1,
          abilityModifier: 2,
          edition: RulesetEdition.v2014,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('6. Spell level resolution via Character.cantrips throws StateError', () {
      const hero = Character(
        id: EntityId(slug: 'hero-6', ruleset: RulesetVersion.v2024),
        name: 'Hero',
        speciesRef: EntityReference<DomainEntity>.empty(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        allocatedSpells: {
          'spells': [
            EntityReference<Spell>.empty(
              refType: EntityType.spell,
              slug: 'fire-bolt',
              displayName: 'Fire Bolt',
            ),
          ],
        },
      );
      expect(
        () => hero.cantrips,
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('7. Rider extraction via Spell.fromMap throws StateError', () {
      expect(
        () => Spell.fromMap({
          'name': 'Trip',
          'descriptionMarkdown': 'Target is knocked prone.',
        }),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('8. FeatureGrant.extractSpellDescriptors throws StateError', () {
      expect(
        () => FeatureGrant.extractSpellDescriptors({'spells': ['fire-bolt']}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('9. FeatureGrant.extractSpellNames throws StateError', () {
      expect(
        () => FeatureGrant.extractSpellNames({'spells': ['fire-bolt']}),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });

    test('10. FeatureGrant.extractBonusSpells throws StateError', () {
      expect(
        () => FeatureGrant.extractBonusSpells({'spells': ['fire-bolt']}, 'class', 'cleric'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Dnd5eCatalog has not been installed'),
        )),
      );
    });
  });
}
