import 'dart:math' as math;
import 'package:collection/collection.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/entity_reference.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../../models/characters/srd_classes_library.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/characters/srd_feats_library.dart';
import '../../models/dm_screen_data.dart' show DmRulesEdition;
import 'character_progression_engine.dart';
import 'skill_trait_resolver.dart';

/// Pure rules engine that reparses, refreshes, and heals existing [Character] sheets
/// against the latest compendiums, homebrew registries, and 5e RAW rulesets.
class CharacterReparseEngine {
  CharacterReparseEngine._();

  /// Reparses an existing [Character] against current libraries and rulesets:
  /// - Extracts and resolves feat armor, weapon, and tool proficiencies.
  /// - Cleanses contaminated `allowedSkills` pools.
  /// - Updates species and lineage innate spells and cantrips.
  /// - Resolves missing 2014 narrative background features.
  /// - Recomputes hit point maxima and clamps current hit points.
  static Character reparse(Character character) {
    final edition = character.rulesEdition;
    final startingClass = character.progression.startingClass;
    final classSlug = startingClass?.classRef.slug;
    final speciesSlug = character.speciesRef.slug;
    final subraceSlug = (character.customProperties['subrace'] is Map
            ? character.customProperties['subrace']['slug']
            : null) ??
        character.customProperties['subspecies']?.toString();
    final backgroundSlug = character.backgroundRef?.slug;
    final featSlugs = character.feats.map((f) => f.slug).toList();

    final customProps = Map<String, dynamic>.from(character.customProperties);

    // 1. Tool Proficiencies Re-evaluation (Class + Species + Background + Feats + Existing)
    final compiledTools = SkillTraitResolver.resolveTools(
      draftTools: character.toolProficiencies,
      classSlug: classSlug,
      speciesSlug: speciesSlug,
      subraceSlug: subraceSlug,
      backgroundSlug: backgroundSlug,
      featSlugs: featSlugs,
      customProperties: character.speciesRef.customProperties,
    );

    // Also inspect character.feats directly for any tool proficiencies
    for (final fRef in character.feats) {
      final feat = SrdFeatsLibrary.allFeats.firstWhereOrNull(
        (f) =>
            f.id.slug == fRef.slug ||
            f.name.toLowerCase() == fRef.displayName.toLowerCase(),
      );
      if (feat != null) {
        for (final g in feat.grants) {
          if (g.type == GrantType.bonusTool && g.payload['tool'] != null) {
            final tName = g.payload['tool'].toString().trim();
            if (tName.isNotEmpty &&
                !compiledTools
                    .any((t) => t.toLowerCase() == tName.toLowerCase())) {
              compiledTools.add(tName);
            }
          } else if (g.type == GrantType.proficiency &&
              g.payload['proficiency'] != null) {
            final pName = g.payload['proficiency'].toString().trim();
            if (_isToolProficiency(pName) &&
                !compiledTools
                    .any((t) => t.toLowerCase() == pName.toLowerCase())) {
              compiledTools.add(pName);
            }
          }
        }
        // Direct property check
        final featTools = feat.customProperties['toolProficiencies'] ??
            (feat.customProperties['rawJson'] is Map
                ? feat.customProperties['rawJson']['toolProficiencies']
                : null);
        if (featTools is List) {
          for (final t in featTools) {
            if (t is String && t.trim().isNotEmpty) {
              final tStr = t.trim();
              if (!compiledTools.any(
                  (existing) => existing.toLowerCase() == tStr.toLowerCase())) {
                compiledTools.add(tStr);
              }
            } else if (t is Map) {
              t.forEach((toolName, enabled) {
                if (enabled == true || enabled == 1) {
                  final tStr = toolName.toString().trim();
                  if (tStr != 'any' &&
                      tStr != 'anyArtisansTool' &&
                      !compiledTools.any((existing) =>
                          existing.toLowerCase() == tStr.toLowerCase())) {
                    compiledTools.add(tStr);
                  }
                }
              });
            }
          }
        }
      }
    }

    // 2. Armor Proficiencies Re-evaluation
    final compiledArmor = SkillTraitResolver.resolveArmorProficiencies(
      classSlug: classSlug,
      speciesSlug: speciesSlug,
      subraceSlug: subraceSlug,
      featSlugs: featSlugs,
      customProperties: customProps,
    );
    if (compiledArmor.isNotEmpty) {
      customProps['armorProficiencies'] = compiledArmor;
    }

    // 3. Weapon Proficiencies Re-evaluation
    final compiledWeapons = SkillTraitResolver.resolveWeaponProficiencies(
      classSlug: classSlug,
      speciesSlug: speciesSlug,
      subraceSlug: subraceSlug,
      featSlugs: featSlugs,
      customProperties: customProps,
    );
    if (compiledWeapons.isNotEmpty) {
      customProps['weaponProficiencies'] = compiledWeapons;
    }

    // 4. Lineage Spells & Innate Cantrips
    final updatedCantrips =
        List<EntityReference<Spell>>.from(character.cantrips);
    final updatedSpellsKnown =
        List<EntityReference<Spell>>.from(character.spellsKnown);

    final innateSpells = SkillTraitResolver.getInnateSpeciesSpells(
      speciesSlug: speciesSlug,
      subraceSlug: subraceSlug,
      totalCharacterLevel: character.totalLevel,
      edition: edition,
    );
    for (final s in innateSpells) {
      if (s.isCantrip) {
        if (!updatedCantrips
            .any((existing) => existing.slug == s.spellRef.slug)) {
          updatedCantrips.add(s.spellRef);
        }
      } else {
        if (!updatedSpellsKnown
            .any((existing) => existing.slug == s.spellRef.slug)) {
          updatedSpellsKnown.add(s.spellRef);
        }
      }
    }

    // Feat bonus spells
    for (final fRef in character.feats) {
      final feat = SrdFeatsLibrary.allFeats.firstWhereOrNull(
        (f) =>
            f.id.slug == fRef.slug ||
            f.name.toLowerCase() == fRef.displayName.toLowerCase(),
      );
      if (feat != null) {
        for (final g in feat.grants) {
          if (g.type == GrantType.bonusSpell && g.payload['spell'] != null) {
            final spellSlug = g.payload['spell'].toString();
            final isCantrip = g.payload['isCantrip'] == true;
            final spellRef = EntityReference<Spell>(
              refType: EntityType.spell,
              slug: spellSlug,
              displayName: g.payload['spellName']?.toString() ?? spellSlug,
            );
            if (isCantrip) {
              if (!updatedCantrips
                  .any((existing) => existing.slug == spellSlug)) {
                updatedCantrips.add(spellRef);
              }
            } else {
              if (!updatedSpellsKnown
                  .any((existing) => existing.slug == spellSlug)) {
                updatedSpellsKnown.add(spellRef);
              }
            }
          }
        }
      }
    }

    // 5. Cleansing Contaminated allowedSkills
    if (classSlug != null && classSlug.isNotEmpty) {
      final cls = SrdClassesLibrary.findBySlug(classSlug);
      if (cls != null) {
        final existingAllowed = customProps['allowedSkills'];
        if (existingAllowed is List &&
            existingAllowed.length >= 18 &&
            cls.allowedSkills.isNotEmpty &&
            cls.allowedSkills.length < 18) {
          customProps['allowedSkills'] =
              cls.allowedSkills.map((s) => s.name).toList();
          customProps['skillChoiceCount'] = cls.skillChoiceCount;
        } else if (existingAllowed == null && cls.allowedSkills.isNotEmpty) {
          customProps['allowedSkills'] =
              cls.allowedSkills.map((s) => s.name).toList();
          customProps['skillChoiceCount'] = cls.skillChoiceCount;
        }
      }
    }

    // 6. 2014 Background Feature & Skills Self-Healing
    final updatedSkills = Map<SkillType, SkillProficiencyLevel>.from(
        character.skillProficiencies);
    if (backgroundSlug != null && backgroundSlug.isNotEmpty) {
      final bg = SrdBackgroundsLibrary.findBySlug(backgroundSlug);
      if (edition == DmRulesEdition.v2014) {
        if (customProps['backgroundFeature'] == null ||
            customProps['backgroundFeature'].toString().isEmpty) {
          final feat = SrdBackgroundsLibrary.get2014Feature(backgroundSlug, bg);
          if (feat != null) {
            customProps['backgroundFeature'] = feat.name;
            customProps['backgroundFeatureDescription'] = feat.description;
          }
        }
      }

      // Backfill missing background skills dynamically
      final bgSkills = bg?.skillProficiencies ??
          (character.backgroundRef?.customProperties['skillProficiencies']
                  as List?)
              ?.map((e) => e.toString())
              .toList() ??
          (character.backgroundRef?.customProperties['skills'] as List?)
              ?.map((e) => e.toString())
              .toList();
      if (bgSkills != null && bgSkills.isNotEmpty) {
        for (final s in bgSkills) {
          final clean = s
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('_', '')
              .replaceAll('-', '');
          for (final st in SkillType.values) {
            if (st.name.toLowerCase() == clean ||
                st.displayName.toLowerCase().replaceAll(' ', '') == clean) {
              if (!updatedSkills.containsKey(st) ||
                  updatedSkills[st] == SkillProficiencyLevel.none) {
                updatedSkills[st] = SkillProficiencyLevel.proficient;
              }
              break;
            }
          }
        }
      }
    }

    // 7. Subclass Healing & Data Hydration
    final updatedClasses = character.progression.classes.map((cls) {
      if (cls.subclassRef != null) {
        final sub = SrdClassesLibrary.findSubclass(
          cls.subclassRef!.slug,
          classSlug: cls.classRef.slug,
          displayName: cls.subclassRef!.displayName,
        );
        if (sub != null) {
          final existingCp =
              Map<String, dynamic>.from(cls.subclassRef!.customProperties);
          existingCp['featuresMarkdown'] = sub.featuresMarkdown;
          existingCp['classSlug'] = sub.classSlug;
          existingCp['shortName'] = sub.shortName;
          existingCp['grants'] = sub.grants.map((g) => g.toMap()).toList();
          sub.customProperties.forEach((k, v) {
            existingCp[k] = v;
          });
          return cls.copyWith(
            subclassRef: cls.subclassRef!.copyWith(
              slug: sub.id.slug,
              displayName: sub.name,
              customProperties: existingCp,
            ),
          );
        }
      }
      return cls;
    }).toList();

    // 8. Recompute Resources & Max HP
    final maxHp = CharacterProgressionEngine.computeMaxHp(character);
    final clampedCurrentHp = math.min(character.resources.currentHp, maxHp);
    final updatedResources = character.resources.copyWith(
      currentHp: clampedCurrentHp,
    );

    return character.copyWith(
      progression: character.progression.copyWith(classes: updatedClasses),
      toolProficiencies: compiledTools,
      cantrips: updatedCantrips,
      spellsKnown: updatedSpellsKnown,
      skillProficiencies: updatedSkills,
      customProperties: customProps,
      resources: updatedResources,
    );
  }

  static bool _isToolProficiency(String name) {
    final lower = name.toLowerCase().trim();
    return lower.contains('tool') ||
        lower.contains('kit') ||
        lower.contains('supplies') ||
        lower.contains('utensil') ||
        lower.contains('instrument') ||
        lower.contains('set') ||
        lower.contains('vehicle');
  }
}
