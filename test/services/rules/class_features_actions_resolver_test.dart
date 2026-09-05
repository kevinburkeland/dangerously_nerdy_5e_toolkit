import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/character_sheet_controller.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_actions_resolver.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_evaluation_engine.dart';

void main() {
  group('CharacterActionsResolver Class Features Translation', () {
    test('Paladin level 3 features translate to Actions and Bonus/Special actions', () {
      const paladin2024 = Character(
        id: EntityId(slug: 'pally-test', ruleset: RulesetVersion.v2024),
        name: 'Sir Arthur',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'paladin', displayName: 'Paladin'),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16, charisma: 14),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: paladin2024);
      final stats = CharacterEvaluationEngine.evaluate(paladin2024);
      final resolved = CharacterActionsResolver.resolve(
        character: paladin2024,
        stats: stats,
        controller: controller,
      );

      final actionNames = resolved.actions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();

      expect(actionNames, contains('Lay on Hands'));
      expect(actionNames, contains('Divine Sense'));
      expect(actionNames, contains('Channel Divinity: Sacred Weapon'));
      expect(bonusActionNames, contains('Divine Smite'));
    });

    test('Cleric level 2 Light Domain translates Turn Undead, Radiance of Dawn, and Warding Flare', () {
      const clericLight = Character(
        id: EntityId(slug: 'cleric-light', ruleset: RulesetVersion.v2024),
        name: 'Sister Dawn',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'cleric', displayName: 'Cleric'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'light-domain', displayName: 'Light Domain'),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(wisdom: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: clericLight);
      final stats = CharacterEvaluationEngine.evaluate(clericLight);
      final resolved = CharacterActionsResolver.resolve(
        character: clericLight,
        stats: stats,
        controller: controller,
      );

      final actionNames = resolved.actions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      final reactionNames = resolved.reactions.map((a) => a.name).toList();

      expect(actionNames, contains('Channel Divinity: Turn Undead'));
      expect(actionNames, contains('Channel Divinity: Radiance of the Dawn'));
      expect(bonusActionNames, contains('Channel Divinity: Harness Divine Power'));
      expect(reactionNames, contains('Warding Flare'));
    });

    test('Druid Moon Druid gets Combat Wild Shape as Bonus Action and healing', () {
      const moonDruid = Character(
        id: EntityId(slug: 'druid-moon', ruleset: RulesetVersion.v2024),
        name: 'Ursoc',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'druid', displayName: 'Druid'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'circle-of-the-moon', displayName: 'Circle of the Moon'),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(wisdom: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: moonDruid);
      final stats = CharacterEvaluationEngine.evaluate(moonDruid);
      final resolved = CharacterActionsResolver.resolve(
        character: moonDruid,
        stats: stats,
        controller: controller,
      );

      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      final actionNames = resolved.actions.map((a) => a.name).toList();

      expect(bonusActionNames, contains('Combat Wild Shape'));
      expect(bonusActionNames, contains('Combat Wild Shape: Spell Slot Healing'));
      expect(actionNames, contains('Wild Companion'));
    });

    test('Rogue Level 5 translates Sneak Attack, Cunning Action, Steady Aim, and Uncanny Dodge', () {
      const rogue5 = Character(
        id: EntityId(slug: 'rogue-5', ruleset: RulesetVersion.v2024),
        name: 'Vax',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'rogue', displayName: 'Rogue'),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(dexterity: 18),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: rogue5);
      final stats = CharacterEvaluationEngine.evaluate(rogue5);
      final resolved = CharacterActionsResolver.resolve(
        character: rogue5,
        stats: stats,
        controller: controller,
      );

      final specialNames = resolved.specialActions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      final reactionNames = resolved.reactions.map((a) => a.name).toList();

      expect(specialNames, contains('Sneak Attack'));
      final sneakAtk = resolved.specialActions.firstWhere((a) => a.name == 'Sneak Attack');
      expect(sneakAtk.damageFormula, equals('3d6'));

      expect(bonusActionNames, contains('Cunning Action'));
      expect(bonusActionNames, contains('Steady Aim'));
      expect(reactionNames, contains('Uncanny Dodge'));
    });

    test('Monk Level 5 translates Deflect Missiles to Reactions and Stunning Strike to Special', () {
      const monk5 = Character(
        id: EntityId(slug: 'monk-5', ruleset: RulesetVersion.v2024),
        name: 'Oogway',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'monk', displayName: 'Monk'),
              level: 5,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(dexterity: 16, wisdom: 14),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: monk5);
      final stats = CharacterEvaluationEngine.evaluate(monk5);
      final resolved = CharacterActionsResolver.resolve(
        character: monk5,
        stats: stats,
        controller: controller,
      );

      final reactionNames = resolved.reactions.map((a) => a.name).toList();
      final specialNames = resolved.specialActions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();

      expect(reactionNames, contains('Deflect Missiles'));
      expect(specialNames, contains('Stunning Strike'));
      expect(bonusActionNames, contains('Flurry of Blows'));
      expect(bonusActionNames, contains('Patient Defense'));
      expect(bonusActionNames, contains('Step of the Wind'));
    });

    test('Wizard Level 2 translates Arcane Recovery (Action) and Bladesong (Bonus Action)', () {
      const wizardBladesinger = Character(
        id: EntityId(slug: 'wiz-blade', ruleset: RulesetVersion.v2024),
        name: 'Elrond',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'elf', displayName: 'Elf'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'wizard', displayName: 'Wizard'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'bladesinging', displayName: 'Bladesinging'),
              level: 2,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(intelligence: 18),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: wizardBladesinger);
      final stats = CharacterEvaluationEngine.evaluate(wizardBladesinger);
      final resolved = CharacterActionsResolver.resolve(
        character: wizardBladesinger,
        stats: stats,
        controller: controller,
      );

      final actionNames = resolved.actions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();

      expect(actionNames, contains('Arcane Recovery'));
      expect(bonusActionNames, contains('Bladesong'));
    });

    test('Fighting Style: Protection and Interception translate to Reactions', () {
      const fighterProtection = Character(
        id: EntityId(slug: 'fighter-prot', ruleset: RulesetVersion.v2024),
        name: 'Shield Master',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              level: 1,
              hitDie: 'd10',
              isStartingClass: true,
              selectedFeatureOptions: {
                'fighting-style': ['protection'],
              },
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: fighterProtection);
      final stats = CharacterEvaluationEngine.evaluate(fighterProtection);
      final resolved = CharacterActionsResolver.resolve(
        character: fighterProtection,
        stats: stats,
        controller: controller,
      );

      final reactionNames = resolved.reactions.map((a) => a.name).toList();
      expect(reactionNames, contains('Fighting Style: Protection'));
    });
  });

  group('Homebrew Parsing Robustness & Action Economy Extraction', () {
    test('Header-based homebrew features (### Name (Level X)) translate correctly and obey level gating', () {
      const homebrewMarkdown = '''
### Blood Surge (Level 3)
As a bonus action, you can sacrifice 5 hit points to empower your next strike with 2d6 necrotic damage.

### Unholy Retribution (Level 7)
When a creature within 5 feet hits you, use your reaction to deal 3d8 necrotic damage.

### Dread Presence (Level 1)
As an action, emit a horrific aura that forces creatures within 30 feet to make a Wisdom save.
''';

      const customClass = CharacterClass(
        id: EntityId(slug: 'blood-knight', ruleset: RulesetVersion.v2024),
        name: 'Blood Knight',
        hitDie: 'd10',
        featuresMarkdown: homebrewMarkdown,
      );
      SrdClassesLibrary.addCustomClass(customClass);

      // Character is Level 3 Blood Knight:
      // Should have: Dread Presence (Action, Lvl 1), Blood Surge (Bonus Action, Lvl 3)
      // Should NOT have: Unholy Retribution (Lvl 7 gated)
      const characterLvl3 = Character(
        id: EntityId(slug: 'blood-knight-3', ruleset: RulesetVersion.v2024),
        name: 'Vampiric Champion',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'blood-knight', displayName: 'Blood Knight'),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: characterLvl3);
      final stats = CharacterEvaluationEngine.evaluate(characterLvl3);
      final resolved = CharacterActionsResolver.resolve(
        character: characterLvl3,
        stats: stats,
        controller: controller,
      );

      final actionNames = resolved.actions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      final reactionNames = resolved.reactions.map((a) => a.name).toList();

      expect(actionNames, contains('Dread Presence'));
      expect(bonusActionNames, contains('Blood Surge'));
      expect(reactionNames, isNot(contains('Unholy Retribution')));

      // Validate damage formula extraction on Blood Surge
      final bloodSurge = resolved.bonusActions.firstWhere((a) => a.name == 'Blood Surge');
      expect(bloodSurge.damageFormula, equals('2d6'));
      expect(bloodSurge.damageType, equals(DamageType.necrotic));
    });

    test('Bold lead-in homebrew features (**Name.** Description) translate correctly', () {
      const boldMarkdown = '''
**Warden's Ward.** When an ally within 10 feet of you is hit by an attack, you can use your reaction to interpose your shield and halve the damage.

**Spirit Burst.** As an action, you release celestial light dealing 2d8 radiant damage to all hostiles within 15 feet.
''';

      const customSubclass = Subclass(
        id: EntityId(slug: 'warden-subclass', ruleset: RulesetVersion.v2024),
        name: 'Warden Archetype',
        classSlug: 'fighter',
        featuresMarkdown: boldMarkdown,
      );
      SrdClassesLibrary.addCustomSubclass(customSubclass);

      const characterWarden = Character(
        id: EntityId(slug: 'fighter-warden', ruleset: RulesetVersion.v2024),
        name: 'Warden Fighter',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'fighter', displayName: 'Fighter'),
              subclassRef: EntityReference(refType: EntityType.subclass, slug: 'warden-subclass', displayName: 'Warden Archetype'),
              level: 3,
              hitDie: 'd10',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(strength: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: characterWarden);
      final stats = CharacterEvaluationEngine.evaluate(characterWarden);
      final resolved = CharacterActionsResolver.resolve(
        character: characterWarden,
        stats: stats,
        controller: controller,
      );

      final reactionNames = resolved.reactions.map((a) => a.name).toList();
      final actionNames = resolved.actions.map((a) => a.name).toList();

      expect(reactionNames, contains("Warden's Ward"));
      expect(actionNames, contains('Spirit Burst'));

      final spiritBurst = resolved.actions.firstWhere((a) => a.name == 'Spirit Burst');
      expect(spiritBurst.damageFormula, equals('2d8'));
      expect(spiritBurst.damageType, equals(DamageType.radiant));
    });

    test('Colon / Dash list homebrew features translate correctly', () {
      const listMarkdown = '''
- Kinetic Discharge: As a bonus action, you convert absorbed momentum into 1d10 force damage on your next hit.
- Shockwave: As an action, slam the ground forcing adjacent enemies to make a DEX save.
''';

      const customClass = CharacterClass(
        id: EntityId(slug: 'force-adept', ruleset: RulesetVersion.v2024),
        name: 'Force Adept',
        hitDie: 'd8',
        featuresMarkdown: listMarkdown,
      );
      SrdClassesLibrary.addCustomClass(customClass);

      const characterAdept = Character(
        id: EntityId(slug: 'force-adept-char', ruleset: RulesetVersion.v2024),
        name: 'Kineticist',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'force-adept', displayName: 'Force Adept'),
              level: 2,
              hitDie: 'd8',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(intelligence: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: characterAdept);
      final stats = CharacterEvaluationEngine.evaluate(characterAdept);
      final resolved = CharacterActionsResolver.resolve(
        character: characterAdept,
        stats: stats,
        controller: controller,
      );

      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();
      final actionNames = resolved.actions.map((a) => a.name).toList();

      expect(bonusActionNames, contains('Kinetic Discharge'));
      expect(actionNames, contains('Shockwave'));

      final kd = resolved.bonusActions.firstWhere((a) => a.name == 'Kinetic Discharge');
      expect(kd.damageFormula, equals('1d10'));
      expect(kd.damageType, equals(DamageType.force));
    });

    test('Community Compendium rawJson structure translates features properly', () {
      const customClass = CharacterClass(
        id: EntityId(slug: 'psion', ruleset: RulesetVersion.v2024),
        name: 'Psion',
        hitDie: 'd6',
        customProperties: {
          'rawJson': {
            'classFeatures': [
              {
                'name': 'Psychic Thrust',
                'level': 1,
                'entries': ['As an action, focus mental force to blast a target with 1d8 psychic damage.'],
              },
              {
                'name': 'Thought Shield',
                'level': 2,
                'entries': ['When targeted by an attack, you can use your reaction to raise a psychic barrier.'],
              },
              {
                'name': 'Psionic Leap',
                'level': 6,
                'entries': ['As a bonus action, launch yourself into the air.'],
              },
            ],
          },
        },
      );
      SrdClassesLibrary.addCustomClass(customClass);

      // Character is Level 2 Psion:
      // Psychic Thrust (Action, Lvl 1): YES
      // Thought Shield (Reaction, Lvl 2): YES
      // Psionic Leap (Bonus Action, Lvl 6): NO (gated)
      const psionChar = Character(
        id: EntityId(slug: 'psion-char', ruleset: RulesetVersion.v2024),
        name: 'Mindbender',
        speciesRef: EntityReference(refType: EntityType.species, slug: 'human', displayName: 'Human'),
        progression: CharacterProgression(
          classes: [
            ClassLevelProgression(
              classRef: EntityReference(refType: EntityType.classDefinition, slug: 'psion', displayName: 'Psion'),
              level: 2,
              hitDie: 'd6',
              isStartingClass: true,
            ),
          ],
        ),
        baseScores: AbilityScores(intelligence: 16),
        resources: CharacterResourcePool(),
      );

      final controller = CharacterSheetController(character: psionChar);
      final stats = CharacterEvaluationEngine.evaluate(psionChar);
      final resolved = CharacterActionsResolver.resolve(
        character: psionChar,
        stats: stats,
        controller: controller,
      );

      final actionNames = resolved.actions.map((a) => a.name).toList();
      final reactionNames = resolved.reactions.map((a) => a.name).toList();
      final bonusActionNames = resolved.bonusActions.map((a) => a.name).toList();

      expect(actionNames, contains('Psychic Thrust'));
      expect(reactionNames, contains('Thought Shield'));
      expect(bonusActionNames, isNot(contains('Psionic Leap')));

      final thrust = resolved.actions.firstWhere((a) => a.name == 'Psychic Thrust');
      expect(thrust.damageFormula, equals('1d8'));
      expect(thrust.damageType, equals(DamageType.psychic));
    });
  });
}
