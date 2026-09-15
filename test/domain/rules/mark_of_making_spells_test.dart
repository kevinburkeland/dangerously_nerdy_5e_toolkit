import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_draft.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/character_models.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_race_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/character_factory.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/skill_trait_resolver.dart';

void main() {
  group('Mark of Making / Lineage Spells Tests', () {
    test('CompendiumRaceParser extracts innate and expanded spells from additionalSpells', () {
      final parser = CompendiumRaceParser();
      final rawSubrace = {
        'name': 'Human (Lineage of Making)',
        'source': 'ERLW',
        'raceName': 'Human',
        'raceSource': 'PHB',
        'additionalSpells': [
          {
            'innate': {
              '_': ['mending#c'],
              'daily': {
                '1e': ['magic weapon'],
              },
            },
            'expanded': {
              's1': ['identify', "tenser's floating disk"],
              's2': ['continual flame', 'magic weapon'],
              's3': ['conjure barrage', 'elemental weapon'],
              's4': ['fabricate', 'stone shape'],
              's5': ['creation'],
            },
          }
        ],
      };

      final subrace = parser.parseSubrace(rawSubrace);

      // Verify FeatureGrants contains all extracted spells
      final spellGrants = subrace.grants.where((g) => g.type.name == 'bonusSpell').toList();
      final slugs = spellGrants.map((g) => g.payload['slug'].toString()).toSet();

      expect(slugs, contains('mending'));
      expect(slugs, contains('magic-weapon'));
      expect(slugs, contains('identify'));
      expect(slugs, contains('tensers-floating-disk'));
      expect(slugs, contains('continual-flame'));
      expect(slugs, contains('conjure-barrage'));
      expect(slugs, contains('elemental-weapon'));
      expect(slugs, contains('fabricate'));
      expect(slugs, contains('stone-shape'));
      expect(slugs, contains('creation'));

      // Check mending is marked as a cantrip
      final mendingGrant = spellGrants.firstWhere((g) => g.payload['slug'] == 'mending');
      expect(mendingGrant.payload['isCantrip'], isTrue);
    });

    test('SkillTraitResolver.getInnateSpeciesSpells returns innate cantrip and leveled spells', () {
      final parser = CompendiumRaceParser();
      final subrace = parser.parseSubrace({
        'name': 'Lineage of Making',
        'source': 'ERLW',
        'raceName': 'Human',
        'additionalSpells': [
          {
            'innate': {
              '_': ['mending#c'],
              'daily': {
                '1e': ['magic weapon'],
              },
            },
            'expanded': {
              's1': ['identify', "tenser's floating disk"],
            },
          }
        ],
      });

      // Register into customSubraces so findSubraceBySlug resolves it
      SrdSpeciesLibrary.addCustomSubrace(subrace);

      final level1Spells = SkillTraitResolver.getInnateSpeciesSpells(
        speciesSlug: 'human',
        subraceSlug: subrace.id.slug,
        totalCharacterLevel: 1,
        subraceRef: EntityReference(
          refType: EntityType.custom,
          slug: subrace.id.slug,
          displayName: subrace.name,
          customProperties: subrace.customProperties,
        ),
      );

      final slugs = level1Spells.map((s) => s.spellRef.slug).toList();
      expect(slugs, contains('mending'));
      expect(slugs, contains('identify'));
      expect(slugs, contains('tensers-floating-disk'));

      final mending = level1Spells.firstWhere((s) => s.spellRef.slug == 'mending');
      expect(mending.isCantrip, isTrue);
    });

    test('CharacterFactory.buildFromDraft auto-merges species and subrace spells into cantrips and spellsKnown', () {
      final parser = CompendiumRaceParser();
      final subrace = parser.parseSubrace({
        'name': 'Lineage of Making',
        'source': 'ERLW',
        'raceName': 'Human',
        'additionalSpells': [
          {
            'innate': {
              '_': ['mending#c'],
              'daily': {
                '1e': ['magic weapon'],
              },
            },
            'expanded': {
              's1': ['identify'],
            },
          }
        ],
      });
      SrdSpeciesLibrary.addCustomSubrace(subrace);

      final draft = CharacterDraft(
        characterName: 'Artisan Hero',
        rulesEdition: DmRulesEdition.v2014,
        speciesRef: const EntityReference(
          refType: EntityType.species,
          slug: 'human',
          displayName: 'Human',
        ),
        subraceRef: EntityReference(
          refType: EntityType.custom,
          slug: subrace.id.slug,
          displayName: subrace.name,
          customProperties: subrace.customProperties,
        ),
        backgroundRef: const EntityReference(
          refType: EntityType.background,
          slug: 'artisan',
          displayName: 'Guild Artisan',
        ),
        startingClassRef: const EntityReference(
          refType: EntityType.classDefinition,
          slug: 'artificer',
          displayName: 'Artificer',
        ),
        baseScores: const AbilityScores(
          strength: 10,
          dexterity: 14,
          constitution: 14,
          intelligence: 16,
          wisdom: 12,
          charisma: 8,
        ),
      );

      final character = CharacterFactory.buildFromDraft(draft);

      // Verify character.cantrips has mending
      final cantripSlugs = character.cantrips.map((c) => c.slug).toSet();
      expect(cantripSlugs, contains('mending'));

      // Verify character.spellsKnown has magic-weapon and identify
      final spellSlugs = character.spellsKnown.map((s) => s.slug).toSet();
      expect(spellSlugs, contains('magic-weapon'));
      expect(spellSlugs, contains('identify'));
    });
  });
}
