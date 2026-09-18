import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/party_purse.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_reparse_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_progression_engine.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';

void main() {
  group('CharacterReparseEngine Tests', () {
    test('reparses 2014 Acolyte and populates missing backgroundFeature and description', () {
      const request = CharacterCreationRequest(
        characterName: 'Faithful Cleric',
        ruleset: RulesetVersion.v2014,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'acolyte',
          displayName: 'Acolyte',
        ),
        startingClassSlug: 'cleric',
        startingClassDisplayName: 'Cleric',
        startingClassHitDie: 'd8',
        baseScores: AbilityScores.standardArray(),
        bonusScores: AbilityScores.zero(),
        startingEquipment: [],
        startingPurse: PartyPurse(),
      );

      final char = CharacterFactory.createLevel1Character(request);
      // Artificially wipe customProperties backgroundFeature
      final staleChar = char.copyWith(
        customProperties: {
          ...char.customProperties,
          'backgroundFeature': '',
          'backgroundFeatureDescription': '',
        },
      );

      final reparsed = CharacterReparseEngine.reparse(staleChar);

      expect(reparsed.customProperties['backgroundFeature'], equals('Shelter of the Faithful'));
      expect(
        reparsed.customProperties['backgroundFeatureDescription'],
        contains('command the respect of those who share your faith'),
      );
    });

    test('heals contaminated 18-skill allowedSkills list to true class skills', () {
      const request = CharacterCreationRequest(
        characterName: 'Wizard Scholar',
        ruleset: RulesetVersion.v2014,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        ),
        startingClassSlug: 'wizard',
        startingClassDisplayName: 'Wizard',
        startingClassHitDie: 'd6',
        baseScores: AbilityScores.standardArray(),
        bonusScores: AbilityScores.zero(),
        startingEquipment: [],
        startingPurse: PartyPurse(),
      );

      final char = CharacterFactory.createLevel1Character(request);
      // Artificially contaminate allowedSkills with all 18 skills
      final all18 = SkillType.values.map((s) => s.name).toList();
      final contaminated = char.copyWith(
        customProperties: {
          ...char.customProperties,
          'allowedSkills': all18,
        },
      );
      expect((contaminated.customProperties['allowedSkills'] as List).length, equals(18));

      final healed = CharacterReparseEngine.reparse(contaminated);
      final allowed = healed.customProperties['allowedSkills'] as List<String>;

      // Wizard allowed skills are 6 skills: arcana, history, insight, investigation, medicine, religion
      expect(allowed.length, equals(6));
      expect(allowed.contains('arcana'), isTrue);
      expect(allowed.contains('athletics'), isFalse);
      expect(allowed.contains('stealth'), isFalse);
    });

    test('re-resolves armor and weapon proficiencies granted by feats', () {
      const request = CharacterCreationRequest(
        characterName: 'Armored Mage',
        ruleset: RulesetVersion.v2014,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'sage',
          displayName: 'Sage',
        ),
        startingClassSlug: 'wizard',
        startingClassDisplayName: 'Wizard',
        startingClassHitDie: 'd6',
        baseScores: AbilityScores.standardArray(),
        bonusScores: AbilityScores.zero(),
        startingEquipment: [],
        startingPurse: PartyPurse(),
      );

      final char = CharacterFactory.createLevel1Character(request);
      const armorFeat = Feat(
        id: EntityId(slug: 'armor-training', ruleset: RulesetVersion.v2014),
        name: 'Armor Training',
        prerequisite: 'Proficiency with light armor',
        category: 'General',
        descriptionMarkdown: 'Grants medium armor and shield proficiency.',
        customProperties: {
          'armorProficiencies': ['medium', 'shields'],
        },
      );
      SrdFeatsLibrary.addCustomFeat(armorFeat);

      final featRef = EntityReference<DomainEntity>(
        refType: EntityType.feat,
        slug: armorFeat.slug,
        displayName: armorFeat.name,
      );

      final staleChar = char.copyWith(
        feats: [featRef],
        customProperties: {
          ...char.customProperties,
          'armorProficiencies': <String>[],
        },
      );

      final reparsed = CharacterReparseEngine.reparse(staleChar);
      final armors = reparsed.customProperties['armorProficiencies'] as List;

      // Moderately armored grants Medium Armor and Shields
      expect(armors.contains('Medium Armor'), isTrue);
      expect(armors.contains('Shields'), isTrue);
    });

    test('merges innate species cantrips and spells into spellsKnown', () {
      const request = CharacterCreationRequest(
        characterName: 'Tiefling Rogue',
        ruleset: RulesetVersion.v2014,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'tiefling',
          displayName: 'Tiefling',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'criminal',
          displayName: 'Criminal',
        ),
        startingClassSlug: 'rogue',
        startingClassDisplayName: 'Rogue',
        startingClassHitDie: 'd8',
        baseScores: AbilityScores.standardArray(),
        bonusScores: AbilityScores.zero(),
        startingEquipment: [],
        startingPurse: PartyPurse(),
      );

      final char = CharacterFactory.createLevel1Character(request);
      // Empty cantrips
      final staleChar = char.copyWith(
        cantrips: [],
      );

      final reparsed = CharacterReparseEngine.reparse(staleChar);

      // Tiefling grants Thaumaturgy cantrip
      expect(reparsed.cantrips.any((c) => c.slug == 'thaumaturgy'), isTrue);
    });

    test('recomputes maxHp and clamps currentHp when out of bounds', () {
      const request = CharacterCreationRequest(
        characterName: 'Sturdy Barbarian',
        ruleset: RulesetVersion.v2014,
        speciesRef: EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        backgroundRef: EntityReference(
          refType: EntityType.background,
          slug: 'soldier',
          displayName: 'Soldier',
        ),
        startingClassSlug: 'barbarian',
        startingClassDisplayName: 'Barbarian',
        startingClassHitDie: 'd12',
        baseScores: AbilityScores(
          strength: 15,
          dexterity: 14,
          constitution: 14, // +2 CON
          intelligence: 10,
          wisdom: 10,
          charisma: 10,
        ),
        bonusScores: AbilityScores.zero(),
        startingEquipment: [],
        startingPurse: PartyPurse(),
      );

      final char = CharacterFactory.createLevel1Character(request);
      // Level 1 Barbarian: 12 + 2 = 14 HP.
      // Give stale character currentHp 99.
      final staleChar = char.copyWith(
        resources: char.resources.copyWith(
          currentHp: 99,
        ),
      );

      final reparsed = CharacterReparseEngine.reparse(staleChar);

      expect(CharacterProgressionEngine.computeMaxHp(reparsed), equals(14));
      expect(reparsed.resources.currentHp, equals(14));
    });
  });
}
