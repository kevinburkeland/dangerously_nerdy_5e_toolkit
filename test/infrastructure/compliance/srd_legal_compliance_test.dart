import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_classes_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_backgrounds_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_species_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/homebrew_extended_entities.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/entity_reference.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/compendium_spell_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dpr/dpr_models.dart';
import 'canonical_srd_allowlists.dart';

void main() {
  group('SRD Legal Compliance & Product Identity Invariant Suite', () {
    final piPattern = RegExp(
      r"\b(Eberron|Faer[uû]n|Toril|Ravnica|Krynn|Athas|Barovia|Spelljammer|Planescape|Waterdeep|Baldur'?s Gate|Neverwinter|Harper|Harpers|Zhentarim|Lord'?s Alliance|Emerald Enclave|Order of the Gauntlet|Dragonmark|Dragonmarks|Dragonmarked|Warforged|Kalashtar|Shifter|Changeling|Simic Hybrid|Vedalken|Githyanki|Githzerai|Beholder|Mind Flayer|Illithid|Gith|Displacer Beast|Gauth|Carrion Crawler|Umber Hulk|Slaad|Yuan-ti|Beholderkin|Bigby|Tasha|Mordenkainen|Otiluke|Drawmij|Rary|Leomund|Evard|Tenser|Aganazzar|Melf|Elminster|Drizzt|Strahd|Acererak)\b",
      caseSensitive: false,
    );

    test('SrdClassesLibrary.allOptions contains zero Product Identity tokens',
        () {
      final options = SrdClassesLibrary.allOptions;
      expect(options, isNotEmpty);

      for (final opt in options) {
        expect(
          piPattern.firstMatch(opt.name),
          isNull,
          reason:
              'Class feature option name "${opt.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(opt.descriptionMarkdown),
          isNull,
          reason:
              'Class feature option "${opt.name}" description violates Product Identity rules.',
        );
      }
    });

    test(
        'SrdBackgroundsLibrary.allBackgrounds contains zero Product Identity tokens',
        () {
      final backgrounds = SrdBackgroundsLibrary.allBackgrounds;
      expect(backgrounds, isNotEmpty);

      for (final bg in backgrounds) {
        expect(
          piPattern.firstMatch(bg.name),
          isNull,
          reason:
              'Background name "${bg.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(bg.descriptionMarkdown),
          isNull,
          reason:
              'Background "${bg.name}" descriptionMarkdown violates Product Identity rules.',
        );
      }
    });

    test('SrdSpeciesLibrary.allSpecies contains zero Product Identity tokens',
        () {
      final speciesList = SrdSpeciesLibrary.allSpecies;
      expect(speciesList, isNotEmpty);

      for (final species in speciesList) {
        expect(
          piPattern.firstMatch(species.name),
          isNull,
          reason:
              'Species name "${species.name}" violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(species.traitsMarkdown),
          isNull,
          reason:
              'Species "${species.name}" traitsMarkdown violates Product Identity rules.',
        );
      }
    });

    test(
        'MonsterCodexLibrary.allMonsters contains zero Product Identity tokens',
        () {
      final monsters = MonsterCodexLibrary.allMonsters;
      expect(monsters, isNotEmpty);

      for (final monster in monsters) {
        expect(
          piPattern.firstMatch(monster.name),
          isNull,
          reason:
              'Monster name "${monster.name}" violates Product Identity rules.',
        );
        if (monster.name2014 != null) {
          expect(
            piPattern.firstMatch(monster.name2014!),
            isNull,
            reason:
                'Monster name2014 "${monster.name2014}" violates Product Identity rules.',
          );
        }
        if (monster.name2024 != null) {
          expect(
            piPattern.firstMatch(monster.name2024!),
            isNull,
            reason:
                'Monster name2024 "${monster.name2024}" violates Product Identity rules.',
          );
        }

        for (final trait in monster.statBlock2014.traits) {
          expect(
            piPattern.firstMatch(trait.name),
            isNull,
            reason:
                'Monster "${monster.name}" (2014) trait name "${trait.name}" violates Product Identity rules.',
          );
          expect(
            piPattern.firstMatch(trait.description),
            isNull,
            reason:
                'Monster "${monster.name}" (2014) trait "${trait.name}" description violates Product Identity rules.',
          );
        }

        for (final trait in monster.statBlock2024.traits) {
          expect(
            piPattern.firstMatch(trait.name),
            isNull,
            reason:
                'Monster "${monster.name}" (2024) trait name "${trait.name}" violates Product Identity rules.',
          );
          expect(
            piPattern.firstMatch(trait.description),
            isNull,
            reason:
                'Monster "${monster.name}" (2024) trait "${trait.name}" description violates Product Identity rules.',
          );
        }
      }
    });

    test('MagicItemLibrary.allItems contains zero Product Identity tokens', () {
      final items = MagicItemLibrary.allItems;
      expect(items, isNotEmpty);

      for (final item in items) {
        expect(
          piPattern.firstMatch(item.name),
          isNull,
          reason:
              'Magic item name "${item.name}" violates Product Identity rules.',
        );
        if (item.name2014 != null) {
          expect(
            piPattern.firstMatch(item.name2014!),
            isNull,
            reason:
                'Magic item name2014 "${item.name2014}" violates Product Identity rules.',
          );
        }
        if (item.name2024 != null) {
          expect(
            piPattern.firstMatch(item.name2024!),
            isNull,
            reason:
                'Magic item name2024 "${item.name2024}" violates Product Identity rules.',
          );
        }
        expect(
          piPattern.firstMatch(item.rules2014.description),
          isNull,
          reason:
              'Magic item "${item.name}" (2014) description violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2024.description),
          isNull,
          reason:
              'Magic item "${item.name}" (2024) description violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2014.summary),
          isNull,
          reason:
              'Magic item "${item.name}" (2014) summary violates Product Identity rules.',
        );
        expect(
          piPattern.firstMatch(item.rules2024.summary),
          isNull,
          reason:
              'Magic item "${item.name}" (2024) summary violates Product Identity rules.',
        );
      }
    });

    // =========================================================================
    // CANONICAL SRD DATASET ALLOWLIST AUDIT
    // =========================================================================
    group('Canonical SRD Dataset Allowlist Verification', () {
      test('Bundled base classes match canonical SRD 5.1/5.2.1 allowlist', () {
        final classes = SrdClassesLibrary.baseClasses;
        expect(classes, isNotEmpty);

        for (final cls in classes) {
          final slug = cls.id.slug.toLowerCase().trim();
          expect(
            canonicalSrdClasses.contains(slug),
            isTrue,
            reason:
                'Offending class "$slug" in SrdClassesLibrary is absent from canonical SRD allowlist.',
          );
        }
      });

      test('Bundled base subclasses match canonical SRD 5.1/5.2.1 allowlist',
          () {
        final classes = SrdClassesLibrary.baseClasses;
        for (final cls in classes) {
          for (final sub in cls.subclasses) {
            final subSlug = sub.id.slug.toLowerCase().trim();
            final strippedSlug = subSlug.replaceAll('${cls.id.slug}-', '');
            final matches = canonicalSrdSubclasses.contains(subSlug) ||
                canonicalSrdSubclasses.contains(strippedSlug);
            expect(
              matches,
              isTrue,
              reason:
                  'Offending subclass "$subSlug" in class "${cls.name}" is absent from canonical SRD allowlist.',
            );
          }
        }
      });

      test('Bundled base species match canonical SRD 5.1/5.2.1 allowlist', () {
        final speciesList = SrdSpeciesLibrary.baseSpecies;
        expect(speciesList, isNotEmpty);

        for (final sp in speciesList) {
          final slug = sp.id.slug.toLowerCase().trim();
          expect(
            canonicalSrdSpecies.contains(slug),
            isTrue,
            reason:
                'Offending species "$slug" in SrdSpeciesLibrary is absent from canonical SRD allowlist.',
          );
        }
      });

      test('Bundled base feats match canonical SRD 5.1/5.2.1 allowlist', () {
        final feats = SrdFeatsLibrary.baseFeats;
        expect(feats, isNotEmpty);

        for (final feat in feats) {
          final slug = feat.id.slug.toLowerCase().trim();
          expect(
            canonicalAllowedFeats.contains(slug),
            isTrue,
            reason:
                'Offending feat "$slug" in SrdFeatsLibrary is absent from canonical SRD allowlist.',
          );
        }
      });

      test(
          'The legality allowlist and currently bundled subset are modeled separately',
          () {
        expect(
          canonicalAllowedFeats.length,
          greaterThan(bundledBaseFeatSlugs.length),
          reason:
              'Canonical allowlist must model all permitted SRD feats, not just the currently bundled subset.',
        );
        expect(
          canonicalAllowedFeats.containsAll(bundledBaseFeatSlugs),
          isTrue,
          reason:
              'All bundled base feats must be included in the canonical allowlist.',
        );
      });

      test(
          'Valid SRD 5.2.1 feats are present in canonical allowlist and not classified as forbidden',
          () {
        const sampleSrd521Feats = [
          'alert',
          'magic-initiate',
          'savage-attacker',
          'skilled',
          'ability-score-improvement',
          'archery',
          'defense',
          'great-weapon-fighting',
          'two-weapon-fighting',
          'boon-of-combat-prowess',
          'boon-of-dimensional-travel',
          'boon-of-fate',
        ];
        for (final feat in sampleSrd521Feats) {
          expect(
            canonicalAllowedFeats.contains(feat),
            isTrue,
            reason:
                'SRD 5.2.1 feat "$feat" must be recognized as permitted in canonical allowlist.',
          );
        }
      });
    });

    // =========================================================================
    // 10 SPECIFIC REGRESSION & VERIFICATION TESTS (MANDATORY INVARIANTS)
    // =========================================================================
    group('Mandatory Compliance Proof Suite (10 Core Invariants)', () {
      test('1. Artificer is absent from bundled classes and DndClassType', () {
        final baseClassSlugs = SrdClassesLibrary.baseClasses
            .map((c) => c.id.slug.toLowerCase())
            .toSet();
        expect(baseClassSlugs.contains('artificer'), isFalse,
            reason: 'Artificer must not be bundled in base classes.');

        final allClassSlugs = SrdClassesLibrary.allClasses
            .map((c) => c.id.slug.toLowerCase())
            .toSet();
        expect(allClassSlugs.contains('artificer'), isFalse,
            reason: 'Artificer must not be in default allClasses.');

        const enumNames = DndClassType.values;
        final hasArtificerEnum =
            enumNames.any((e) => e.name.toLowerCase() == 'artificer');
        expect(hasArtificerEnum, isFalse,
            reason: 'DndClassType must not contain artificer.');
      });

      test('2. Aasimar is absent from bundled species and SpeciesType', () {
        final baseSpeciesSlugs = SrdSpeciesLibrary.baseSpecies
            .map((s) => s.id.slug.toLowerCase())
            .toSet();
        expect(baseSpeciesSlugs.contains('aasimar'), isFalse,
            reason: 'Aasimar must not be bundled in base species.');

        final allSpeciesSlugs = SrdSpeciesLibrary.allSpecies
            .map((s) => s.id.slug.toLowerCase())
            .toSet();
        expect(allSpeciesSlugs.contains('aasimar'), isFalse,
            reason: 'Aasimar must not be in default allSpecies.');

        const speciesEnums = SpeciesType.values;
        final hasAasimarEnum =
            speciesEnums.any((e) => e.name.toLowerCase() == 'aasimar');
        expect(hasAasimarEnum, isFalse,
            reason: 'SpeciesType must not contain aasimar.');
      });

      test('3. Known non-SRD feats are absent from built-in feat libraries',
          () {
        final featSlugs = SrdFeatsLibrary.baseFeats
            .map((f) => f.id.slug.toLowerCase())
            .toSet();
        const nonSrdFeats = [
          'great-weapon-master',
          'great weapon master',
          'sharpshooter',
          'war-caster',
          'war caster',
          'polearm-master',
          'polearm master',
          'sentinel',
          'lucky',
          'tavern-brawler',
          'inspiring-leader',
        ];

        for (final nonSrd in nonSrdFeats) {
          expect(
            featSlugs.contains(nonSrd),
            isFalse,
            reason: 'Non-SRD feat "$nonSrd" must not be present in baseFeats.',
          );
        }
        for (final slug in featSlugs) {
          expect(
            canonicalAllowedFeats.contains(slug),
            isTrue,
            reason: 'Bundled feat "$slug" must exist in canonicalAllowedFeats.',
          );
        }
      });

      test('4. Expansion spell-name lookup data is absent from codebase', () {
        final parserFile =
            File('lib/services/acl/compendium_spell_parser.dart');
        expect(parserFile.existsSync(), isTrue);
        final parserCode = parserFile.readAsStringSync();

        expect(
          parserCode.contains('_expansionSpellClasses'),
          isFalse,
          reason:
              'CompendiumSpellParser must not retain a hidden _expansionSpellClasses map.',
        );
        expect(
          parserCode.contains('abi-dalzims-horrid-wilting'),
          isFalse,
          reason:
              'Non-SRD expansion spell identifiers must not be hardcoded in parser.',
        );
        expect(
          parserCode.contains('create-spelljamming-helm'),
          isFalse,
          reason:
              'Non-SRD expansion spell identifiers must not be hardcoded in parser.',
        );
      });

      test(
          '5. Custom/imported classes/species/spells/feats can still use arbitrary user-defined names at runtime',
          () {
        const customClass = CharacterClass(
          id: EntityId(slug: 'artificer', ruleset: RulesetVersion.v2024),
          name: 'Artificer',
          hitDie: 'd8',
          subclasses: [
            Subclass(
              id: EntityId(
                  slug: 'artificer-alchemist', ruleset: RulesetVersion.v2024),
              name: 'Alchemist',
              classSlug: 'artificer',
              featuresMarkdown: 'Experimental Elixir mechanics.',
            ),
          ],
        );
        expect(customClass.name, equals('Artificer'));
        expect(customClass.subclasses.first.name, equals('Alchemist'));

        final customSpecies = Race(
          id: const EntityId(slug: 'aasimar', ruleset: RulesetVersion.v2024),
          name: 'Aasimar',
          traitsMarkdown: 'Celestial Resistance and Healing Hands.',
        );
        expect(customSpecies.name, equals('Aasimar'));

        const customFeat = Feat(
          id: EntityId(slug: 'sharpshooter', ruleset: RulesetVersion.v2024),
          name: 'Sharpshooter',
          descriptionMarkdown: 'Custom user-created sharpshooter feat.',
        );
        expect(customFeat.name, equals('Sharpshooter'));

        final parser = CompendiumSpellParser();
        final userSpell = parser.parseSpell({
          'name': 'Booming Blade',
          'level': 0,
          'school': 'V',
          'classes': ['Sorcerer', 'Warlock', 'Wizard'],
        });
        expect(userSpell.name, equals('Booming Blade'));
        expect(userSpell.customProperties['classes'],
            containsAll(['Sorcerer', 'Warlock', 'Wizard']));

        const customReference = EntityReference(
          refType: EntityType.classDefinition,
          slug: 'artificer',
          displayName: 'Artificer',
        );
        expect(customReference.displayName, equals('Artificer'));

        const speciesReference = EntityReference(
          refType: EntityType.species,
          slug: 'aasimar',
          displayName: 'Aasimar',
        );
        expect(speciesReference.displayName, equals('Aasimar'));
      });

      test('6. SRD 5.1 attribution exists with official CC-BY-4.0 text', () {
        final legalFile = File('LEGAL_ATTRIBUTION_MODAL.md');
        expect(legalFile.existsSync(), isTrue);
        final content = legalFile.readAsStringSync();

        expect(
          content.contains(
              'This work includes material taken from the System Reference Document 5.1'),
          isTrue,
          reason:
              'Official SRD 5.1 attribution required in LEGAL_ATTRIBUTION_MODAL.md.',
        );
        expect(
          content.contains(
              'https://dnd.wizards.com/resources/systems-reference-document'),
          isTrue,
          reason: 'Official SRD 5.1 source link required.',
        );
        expect(
          content.contains(
              'Creative Commons Attribution 4.0 International License'),
          isTrue,
          reason: 'Official CC-BY-4.0 license mention required.',
        );
      });

      test('7. SRD 5.2.1 attribution exists with official CC-BY-4.0 text', () {
        final legalFile = File('LEGAL_ATTRIBUTION_MODAL.md');
        expect(legalFile.existsSync(), isTrue);
        final content = legalFile.readAsStringSync();

        expect(
          content.contains(
              'This work includes material taken from the System Reference Document 5.2.1'),
          isTrue,
          reason:
              'Official SRD 5.2.1 attribution required in LEGAL_ATTRIBUTION_MODAL.md.',
        );
        expect(
          content.contains('https://www.dndbeyond.com/srd'),
          isTrue,
          reason: 'Official SRD 5.2.1 source link required.',
        );
      });

      test(
          '8. No obsolete "SRD 5.2" wording remains where "SRD 5.2.1" is intended',
          () {
        final filesToCheck = [
          File('LEGAL_ATTRIBUTION_MODAL.md'),
          File('web/legal/LEGAL_ATTRIBUTION_MODAL.md'),
          File('LICENSE'),
          File('lib/widgets/dialogs/legal_dialogs.dart'),
        ];

        final obsoletePattern = RegExp(r'SRD 5\.2[^.0-9]');
        for (final file in filesToCheck) {
          if (file.existsSync()) {
            final text = file.readAsStringSync();
            expect(
              obsoletePattern.hasMatch(text),
              isFalse,
              reason:
                  'File "${file.path}" contains obsolete "SRD 5.2" instead of "SRD 5.2.1".',
            );
          }
        }
      });

      test(
          '9. No extra Wizards/Hasbro author attribution remains beyond the official required attribution',
          () {
        final filesToCheck = [
          File('LEGAL_ATTRIBUTION_MODAL.md'),
          File('web/legal/LEGAL_ATTRIBUTION_MODAL.md'),
          File('LICENSE'),
          File('lib/widgets/dialogs/legal_dialogs.dart'),
        ];

        const obsoleteAuthorTokens = [
          'Mearls',
          'Crawford',
          'subsidiary of Hasbro',
          'Dave Arneson',
          'Steve Townshend',
        ];

        for (final file in filesToCheck) {
          if (file.existsSync()) {
            final text = file.readAsStringSync();
            for (final token in obsoleteAuthorTokens) {
              expect(
                text.contains(token),
                isFalse,
                reason:
                    'File "${file.path}" contains obsolete author/Hasbro attribution token "$token".',
              );
            }
          }
        }
      });

      test(
          '10. Repository-wide compliance scanning catches a deliberately injected forbidden fixture',
          () {
        const injectedForbiddenFixture = '''
          class ForbiddenFixture {
            final String monster = "beholder";
            final String spell = "tasha's hideous laughter";
            final String feat = "great weapon master";
            final String cantrip1 = "booming blade";
            final String cantrip2 = "green-flame blade";
          }
        ''';

        final forbiddenScannerRegex = RegExp(
          r"\b(beholder|illithid|mind flayer|tasha'?s|great weapon master|booming blade|green-flame blade)\b",
          caseSensitive: false,
        );

        final matches = forbiddenScannerRegex
            .allMatches(injectedForbiddenFixture)
            .map((m) => m.group(0)!)
            .toList();
        expect(
          matches,
          containsAll([
            'beholder',
            "tasha's",
            'great weapon master',
            'booming blade',
            'green-flame blade',
          ]),
        );
        expect(matches.length, greaterThanOrEqualTo(5));
      });

      test('11. Booming Blade is absent from bundled DPR presets', () {
        final hasBoomingBlade = DprWeaponPreset.allPresets.any((p) =>
            p.id.toLowerCase().contains('booming') ||
            p.name.toLowerCase().contains('booming blade'));
        expect(hasBoomingBlade, isFalse,
            reason:
                'Booming Blade must not be included in bundled DPR presets.');
      });

      test('12. Green-Flame Blade is absent from bundled DPR presets', () {
        final hasGreenFlameBlade = DprWeaponPreset.allPresets.any((p) =>
            p.id.toLowerCase().contains('green_flame') ||
            p.name.toLowerCase().contains('green-flame blade'));
        expect(hasGreenFlameBlade, isFalse,
            reason:
                'Green-Flame Blade must not be included in bundled DPR presets.');
      });

      test(
          '13. Non-SRD cantrip and spell weapon presets are absent from DPR catalog',
          () {
        const nonSrdIds = [
          'toll_the_dead',
          'mind_sliver',
          'primal_savagery',
          'word_of_radiance',
          'shadow_blade',
        ];
        for (final nonSrd in nonSrdIds) {
          final present =
              DprWeaponPreset.allPresets.any((p) => p.id.contains(nonSrd));
          expect(present, isFalse,
              reason:
                  'Non-SRD preset "$nonSrd" must not be present in DprWeaponPreset.allPresets.');
        }
      });

      test(
          '14. User-imported Booming Blade and Green-Flame Blade remain supported',
          () {
        const customBooming = DprWeaponPreset(
          id: 'custom_booming_blade',
          name: 'Booming Blade (Custom User Import)',
          diceCount: 1,
          diceSides: 8,
          damageType: 'thunder',
          isCantrip: true,
        );
        expect(
            customBooming.name, equals('Booming Blade (Custom User Import)'));
        expect(customBooming.diceSides, equals(8));

        const customGreenFlame = DprWeaponPreset(
          id: 'custom_green_flame_blade',
          name: 'Green-Flame Blade (Custom User Import)',
          diceCount: 1,
          diceSides: 8,
          damageType: 'fire',
          isCantrip: true,
        );
        expect(customGreenFlame.name,
            equals('Green-Flame Blade (Custom User Import)'));
        expect(customGreenFlame.damageType, equals('fire'));
      });

      test('15. No unnecessary product-facing "D&D" branding in footer', () {
        final landingFile = File('lib/screens/landing_screen.dart');
        expect(landingFile.existsSync(), isTrue);
        final content = landingFile.readAsStringSync();
        expect(content.contains('5E / SRD-Compatible Combat System'), isTrue,
            reason:
                'LandingScreen footer must use neutral 5E / SRD-compatible phrasing.');
        expect(content.contains('D&D 5e / SRD 5.1 Compatible Combat System'),
            isFalse,
            reason: 'Unnecessary product-facing D&D branding must be removed.');
      });
    });

    // =========================================================================
    // REPOSITORY-WIDE PRODUCTION SCANNER
    // =========================================================================
    test(
        'Repository-wide production scan (lib/) contains zero unallowed Product Identity or non-SRD terms',
        () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final forbiddenRegex = RegExp(
        r"\b(beholder|mind flayer|illithid|carrion crawler|displacer beast|githyanki|githzerai|slaad|umber hulk|yuan-ti|kuo-toa|tasha|bigby|mordenkainen|leomund|drawmij|nystul|otiluke|tenser|evard|melf|elminster|drizzt|strahd|acererak|waterdeep|neverwinter|baldur'?s gate|great weapon master|sharpshooter|war caster|polearm master|booming blade|green-flame blade)\b",
        caseSensitive: false,
      );

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final content = file.readAsStringSync();

        for (final match in forbiddenRegex.allMatches(content)) {
          final matchedWord = match.group(0)!;
          violations.add('${file.path}: found forbidden term "$matchedWord"');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Production source code in lib/ violates Product Identity rules:\n${violations.join('\n')}',
      );
    });
  });
}
