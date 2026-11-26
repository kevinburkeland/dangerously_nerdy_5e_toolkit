import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/subclass_spells_library.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/spellbook_data.dart';

class LevelUpWizardController extends ChangeNotifier {
  final Character character;

  int currentStep = 0;

  // Step 1: Class Selection
  late String selectedClassSlug;
  bool isMulticlass = false;

  // Step 2: Hit Points Increase
  bool useFixedAverage = true;
  late int rolledHp;
  bool isRolling = false;

  // Step 3: Subclass Selection
  String? selectedSubclass;
  final Map<String, List<String>> selectedFeatureOptions = {};

  // Step 4: ASI / Feat
  bool isAsiSelected = true;
  bool isAsiPlusTwo = true;
  AbilityType asiSingleAbility = AbilityType.strength;
  AbilityType asiDualAbility1 = AbilityType.strength;
  AbilityType asiDualAbility2 = AbilityType.dexterity;
  String selectedFeatSlug = 'tough';
  String selectedFeatName = 'Tough';
  AbilityType? selectedFeatAbility;
  SkillType? selectedFeatSkill;
  SkillType? selectedFeatExpertise;
  String? selectedFeatOption;
  String featSearchQuery = '';

  // Step 5: Spells
  final List<String> newCantrips = [];
  final List<String> newSpells = [];
  String? replacedSpellId;
  String? selectedMysticArcanumSpellId;
  String spellSearchQuery = '';
  SpellClass? selectedSpellListSource;
  bool showAllSpellListsForSecrets = false;
  final TextEditingController customCantripController =
      TextEditingController();
  final TextEditingController customSpellController = TextEditingController();

  // Languages & Tools gained on level up
  final Set<String> newToolProficiencies = {};
  final Set<String> newLanguages = {};

  LevelUpWizardController({required this.character}) {
    // Default target class to starting class or first class
    final starting = character.progression.startingClass ??
        (character.progression.classes.isNotEmpty
            ? character.progression.classes.first
            : null);
    selectedClassSlug = starting?.classRef.slug.toLowerCase() ?? 'fighter';
    isMulticlass = false;

    final hitDie = starting?.hitDie ?? 'd8';
    rolledHp = CharacterProgressionEngine.getAverageHpForHitDie(hitDie);

    final feats = availableFeats;
    if (feats.isNotEmpty) {
      final initialFeat = feats.firstWhere((f) => f.id.slug == 'tough',
          orElse: () => feats.first);
      selectedFeatSlug = initialFeat.id.slug;
      selectedFeatName = initialFeat.name;
      if (initialFeat.hasAbilityScoreIncrease) {
        selectedFeatAbility = initialFeat.selectableAbilities.first;
      }
      if (initialFeat.hasSkillProficiencyChoice) {
        selectedFeatSkill = initialFeat.selectableSkills.isNotEmpty
            ? initialFeat.selectableSkills.first
            : SkillType.athletics;
      }
      if (initialFeat.hasExpertiseChoice) {
        selectedFeatExpertise = selectedFeatSkill ?? SkillType.athletics;
      }
      if (initialFeat.hasInvocationChoice) {
        final eligible = getEligibleInvocations(initialFeat);
        selectedFeatOption = eligible.isNotEmpty ? eligible.first.id : null;
      } else if (initialFeat.hasFightingStyleChoice) {
        selectedFeatOption = SrdFeatureOptions.fightingStyles.isNotEmpty
            ? SrdFeatureOptions.fightingStyles.first.id
            : null;
      }
    }
  }

  void mutate(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  @override
  void dispose() {
    customCantripController.dispose();
    customSpellController.dispose();
    super.dispose();
  }

  static String formatMulticlassPrerequisite(String classSlug) {
    final options =
        CharacterProgressionEngine.getMulticlassPrerequisites()[
            classSlug.toLowerCase()];
    if (options == null || options.isEmpty) return 'None';
    return options
        .map((req) => req.entries
            .map((e) => '${e.key.shortName.toUpperCase()} ${e.value}')
            .join(' & '))
        .join(' or ');
  }

  List<CharacterClass> get availableClasses => [
        ...SrdClassesLibrary.baseClasses,
        ...SrdClassesLibrary.customClasses,
      ];

  Map<AbilityType, int> get pendingAsiIncreases {
    if (!isAsiEligible || !isAsiSelected) return const {};
    if (isAsiPlusTwo) return {asiSingleAbility: 2};
    final increases = <AbilityType, int>{};
    increases[asiDualAbility1] = (increases[asiDualAbility1] ?? 0) + 1;
    increases[asiDualAbility2] = (increases[asiDualAbility2] ?? 0) + 1;
    return increases;
  }

  AbilityScores get effectiveScoresWithPendingAsi {
    final increases = pendingAsiIncreases;
    if (increases.isEmpty) return character.rawAbilityScores;
    final maxOverrides = <AbilityType, int>{
      for (final ab in increases.keys)
        ab: character.getAbilityScoreMaximum(ab),
    };
    return applyAbilityScoreIncreases(
      currentScores: character.rawAbilityScores,
      increases: increases,
      maximumScoreOverrides: maxOverrides,
    );
  }

  ClassSpellcasterProfile get casterProfile {
    final edition = character.id.ruleset == RulesetVersion.v2024
        ? RulesetEdition.v2024
        : RulesetEdition.v2014;
    final cls = SrdClassesLibrary.findBySlug(
      selectedClassSlug,
      ruleset: character.id.ruleset,
    );
    return resolveClassSpellcasterProfile(
      classSlug: selectedClassSlug,
      classLevel: targetClassNewLevel,
      subclassSlug: effectiveSubclassSlug,
      edition: edition,
      fallbackCastingAbility: cls?.parsedSpellcastingAbility,
      casterProgression: cls?.casterProgression,
    );
  }

  List<Feat> get availableFeats {
    final allFeats =
        SrdFeatsLibrary.getFeatsForRuleset(character.id.ruleset);
    final existingFeatSlugs =
        character.feats.map((f) => f.slug.toLowerCase()).toSet();
    return allFeats.where((f) {
      if (f.id.slug == 'elemental_adept' || f.id.slug == 'elemental-adept')
        return true;
      return !existingFeatSlugs.contains(f.id.slug.toLowerCase());
    }).toList();
  }

  Set<String> getAllAlreadySelectedFeatureOptionIds(
      {String? excludeDecisionId}) {
    final ids = <String>{};
    final existing =
        character.progression.getAllSelectedFeatureOptions();
    for (final list in existing.values) {
      for (final id in list) {
        ids.add(id.toLowerCase().trim());
      }
    }
    for (final entry in selectedFeatureOptions.entries) {
      if (excludeDecisionId != null && entry.key == excludeDecisionId) continue;
      for (final id in entry.value) {
        ids.add(id.toLowerCase().trim());
      }
    }
    if (character.customProperties.containsKey('featInvocationChoice')) {
      ids.add(character.customProperties['featInvocationChoice']
          .toString()
          .toLowerCase()
          .trim());
    }
    return ids;
  }

  bool isOptionRepeatable(FeatureOption opt) {
    if (opt.customProperties['repeatable'] == true ||
        opt.grants['repeatable'] == true) {
      return true;
    }
    final desc = opt.descriptionMarkdown.toLowerCase();
    if (desc.contains('you can take this') ||
        (desc.contains('you can choose this') &&
            desc.contains('more than once'))) {
      return true;
    }
    return false;
  }

  List<FeatureOption> getEligibleInvocations(Feat feat) {
    final isWarlock = character.progression.classes
            .any((c) => c.classRef.slug.toLowerCase() == 'warlock') ||
        selectedClassSlug.toLowerCase() == 'warlock';
    final warlockClass = character.progression.classes
        .where((c) => c.classRef.slug.toLowerCase() == 'warlock')
        .firstOrNull;
    final warlockLevel = (warlockClass?.level ?? 0) +
        (selectedClassSlug.toLowerCase() == 'warlock' ? 1 : 0);
    final selectedPacts = character.progression.classes
        .expand((c) => c.selectedFeatureOptions.values.expand((opts) => opts));
    final knownSpells = {
      ...character.spellsKnown.map((s) => s.slug),
      ...newSpells
    };
    final alreadySelected = getAllAlreadySelectedFeatureOptionIds();

    return SrdFeatureOptions.warlockInvocations.where((opt) {
      if (!isOptionRepeatable(opt)) {
        final optId = opt.id.toLowerCase().trim();
        final optName = opt.name.toLowerCase().trim();
        if (alreadySelected.contains(optId) ||
            alreadySelected.contains(optName)) {
          return false;
        }
      }
      final eval = feat.evaluateInvocationPrerequisite(
        opt,
        isWarlock: isWarlock,
        warlockLevel: warlockLevel,
        selectedPacts: selectedPacts,
        knownSpellSlugs: knownSpells,
      );
      return eval.isMet;
    }).toList();
  }

  int get targetClassCurrentLevel {
    final match = character.progression.classes.where(
      (c) => c.classRef.slug.toLowerCase() == selectedClassSlug.toLowerCase(),
    );
    return match.isNotEmpty ? match.first.level : 0;
  }

  int get targetClassNewLevel => targetClassCurrentLevel + 1;

  int get newTotalLevel => character.totalLevel + 1;

  String get currentHitDie =>
      CharacterProgressionEngine.getDefaultHitDie(selectedClassSlug);

  int get hitDieSides =>
      CharacterProgressionEngine.getHitDieSides(currentHitDie);

  int get fixedAverageHp =>
      CharacterProgressionEngine.getAverageHpForHitDie(currentHitDie);

  bool get isAsiEligible => CharacterProgressionEngine.isAsiMilestone(
      selectedClassSlug, targetClassNewLevel);

  bool get isSubclassMilestone {
    final existingSubclass = character.progression.classes
        .where((c) =>
            c.classRef.slug.toLowerCase() == selectedClassSlug.toLowerCase())
        .map((c) => c.subclassRef)
        .firstOrNull;
    final cls = SrdClassesLibrary.findBySlug(selectedClassSlug,
        ruleset: character.id.ruleset);
    return existingSubclass == null &&
        CharacterProgressionEngine.isSubclassMilestone(
          selectedClassSlug,
          targetClassNewLevel,
          ruleset: character.rulesEdition,
          characterClass: cls,
        );
  }

  int get conModifier => effectiveScoresWithPendingAsi.constitution.dndModifier;

  int get effectiveHpGain => computeLevelUpHpGain(
        hitDie: currentHitDie,
        constitutionModifier: conModifier,
        useFixedAverage: useFixedAverage,
        rolledValue: useFixedAverage ? null : rolledHp.clamp(1, hitDieSides),
      );

  Set<String> getAllKnownSpellSlugs() {
    final slugs = <String>{};
    for (final c in character.cantrips) {
      slugs.add(c.slug.toLowerCase().trim());
      slugs.add(c.displayName.toLowerCase().trim());
    }
    for (final s in character.spellsKnown) {
      slugs.add(s.slug.toLowerCase().trim());
      slugs.add(s.displayName.toLowerCase().trim());
    }
    for (final s in character.spellsPrepared) {
      slugs.add(s.slug.toLowerCase().trim());
      slugs.add(s.displayName.toLowerCase().trim());
    }
    for (final c in newCantrips) {
      slugs.add(c.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(c);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    for (final s in newSpells) {
      slugs.add(s.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(s);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    if (selectedMysticArcanumSpellId != null) {
      final s = selectedMysticArcanumSpellId!;
      slugs.add(s.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(s);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    return slugs;
  }

  Set<String> getAllSelectedPacts() {
    final pacts = <String>{};
    final pactRegex = RegExp(r'pact[-_ ](?:of[-_ ]the[-_ ])?([a-z0-9]+)',
        caseSensitive: false);
    void extract(Iterable<String> ids) {
      for (final id in ids) {
        final lower = id.toLowerCase();
        final match = pactRegex.firstMatch(lower);
        if (match != null) {
          pacts.add(match.group(1)!);
        } else {
          if (lower.contains('blade')) pacts.add('blade');
          if (lower.contains('tome')) pacts.add('tome');
          if (lower.contains('chain')) pacts.add('chain');
        }
      }
    }

    final existing =
        character.progression.getAllSelectedFeatureOptions();
    for (final list in existing.values) {
      extract(list);
    }
    for (final list in selectedFeatureOptions.values) {
      extract(list);
    }
    return pacts;
  }

  // --------------------------------------------------------------------------
  // STEP 3: SUBCLASS & FEATURES

  void applyFeatSelection(Feat match) {
    mutate(() {
      selectedFeatSlug = match.id.slug;
      selectedFeatName = match.name;
      if (match.hasAbilityScoreIncrease) {
        if (selectedFeatAbility == null ||
            !match.selectableAbilities.contains(selectedFeatAbility)) {
          selectedFeatAbility = match.selectableAbilities.first;
        }
      } else {
        selectedFeatAbility = null;
      }
      if (match.hasSkillProficiencyChoice) {
        final selectable = match.selectableSkills.isNotEmpty
            ? match.selectableSkills
            : SkillType.values.toList();
        if (selectedFeatSkill == null ||
            !selectable.contains(selectedFeatSkill)) {
          selectedFeatSkill = selectable.first;
        }
      } else {
        selectedFeatSkill = null;
      }
      if (match.hasExpertiseChoice) {
        final eligible = <SkillType>{
          ...character.skillProficiencies.entries
              .where((e) => e.value != SkillProficiencyLevel.none)
              .map((e) => e.key),
          ?selectedFeatSkill,
        };
        if (eligible.isEmpty) eligible.addAll(SkillType.values);
        if (selectedFeatExpertise == null ||
            !eligible.contains(selectedFeatExpertise)) {
          selectedFeatExpertise = selectedFeatSkill ?? eligible.first;
        }
      } else {
        selectedFeatExpertise = null;
      }
      if (match.hasInvocationChoice) {
        final eligible = getEligibleInvocations(match);
        selectedFeatOption = eligible.isNotEmpty ? eligible.first.id : null;
      } else if (match.hasFightingStyleChoice) {
        selectedFeatOption = SrdFeatureOptions.fightingStyles.isNotEmpty
            ? SrdFeatureOptions.fightingStyles.first.id
            : null;
      } else {
        selectedFeatOption = null;
      }
    });
  }

  // --------------------------------------------------------------------------
  // STEP 4: ASI / FEAT

  String? get effectiveSubclassSlug {
    if (selectedSubclass != null) return selectedSubclass;
    final match = character.progression.classes.where(
      (c) => c.classRef.slug.toLowerCase() == selectedClassSlug.toLowerCase(),
    );
    return match.isNotEmpty ? match.first.subclassRef?.slug : null;
  }

  int getCastingModifier(String classSlug) {
    final edition = character.id.ruleset == RulesetVersion.v2024
        ? RulesetEdition.v2024
        : RulesetEdition.v2014;
    final cls = SrdClassesLibrary.findBySlug(
      classSlug,
      ruleset: character.id.ruleset,
    );
    final profile = resolveClassSpellcasterProfile(
      classSlug: classSlug,
      classLevel: targetClassNewLevel,
      subclassSlug: effectiveSubclassSlug,
      edition: edition,
      fallbackCastingAbility: cls?.parsedSpellcastingAbility,
      casterProgression: cls?.casterProgression,
    );
    final ability = profile.castingAbility;
    if (ability == null) return 0;
    return effectiveScoresWithPendingAsi.getScore(ability).dndModifier;
  }

  int get maxAccessibleSpellLevel => casterProfile.highestSpellLevel;

  bool get isSpellcaster => casterProfile.isSpellcaster;

  SpellClass? get targetSpellClass => casterProfile.spellList;

  // --------------------------------------------------------------------------
  // STEP 5: SPELLS

  LevelUpRequest buildRequest() {
    AsiOrFeatChoice? asiChoice;
    if (isAsiEligible) {
      if (isAsiSelected) {
        if (isAsiPlusTwo) {
          asiChoice = AsiOrFeatChoice.asi({asiSingleAbility: 2});
        } else {
          final increases = <AbilityType, int>{};
          increases[asiDualAbility1] = (increases[asiDualAbility1] ?? 0) + 1;
          increases[asiDualAbility2] = (increases[asiDualAbility2] ?? 0) + 1;
          asiChoice = AsiOrFeatChoice.asi(increases);
        }
      } else {
        final feat = availableFeats
                .where((f) => f.id.slug == selectedFeatSlug)
                .firstOrNull ??
            SrdFeatsLibrary.findBySlug(selectedFeatSlug);
        final increases = <AbilityType, int>{};
        final saves = <AbilityType>{};
        final chosenAbility = selectedFeatAbility ??
            (feat?.selectableAbilities.isNotEmpty == true
                ? feat!.selectableAbilities.first
                : null);

        if (feat != null &&
            feat.hasAbilityScoreIncrease &&
            chosenAbility != null) {
          increases[chosenAbility] = feat.statIncreaseAmount;
          if (feat.grantsSavingThrowProficiency) {
            saves.add(chosenAbility);
          }
        }

        final skills = <SkillType>{};
        if (feat != null &&
            feat.hasSkillProficiencyChoice &&
            selectedFeatSkill != null) {
          skills.add(selectedFeatSkill!);
        }
        final expertises = <SkillType>{};
        if (feat != null && feat.hasExpertiseChoice) {
          final eligible = <SkillType>{
            ...character.skillProficiencies.entries
                .where((e) => e.value != SkillProficiencyLevel.none)
                .map((e) => e.key),
            ?selectedFeatSkill,
          };
          final finalExp = eligible.contains(selectedFeatExpertise)
              ? selectedFeatExpertise
              : (selectedFeatSkill ??
                  (eligible.isNotEmpty ? eligible.first : null));
          if (finalExp != null) {
            expertises.add(finalExp);
          }
        }

        final featureGrants = <String, List<String>>{};
        if (selectedFeatOption != null) {
          featureGrants['feat-$selectedFeatSlug'] = [selectedFeatOption!];
        }

        asiChoice = AsiOrFeatChoice.feat(
          EntityReference<DomainEntity>(
            refType: EntityType.feat,
            slug: selectedFeatSlug,
            displayName: selectedFeatName,
          ),
          abilityIncreases: increases,
          savingThrowGrants: saves,
          chosenFeatAbility: chosenAbility,
          skillGrants: skills,
          expertiseGrants: expertises,
          featureOptionGrants: featureGrants,
        );
      }
    }

    EntityReference<DomainEntity>? subclassRef;
    if (selectedSubclass != null) {
      final customCls = SrdClassesLibrary.findBySlug(selectedClassSlug,
          ruleset: character.id.ruleset);
      final List<Map<String, String>> subs = [];
      if (customCls != null && customCls.subclasses.isNotEmpty) {
        for (final s in customCls.subclasses) {
          subs.add({'slug': s.id.slug, 'name': s.name});
        }
      }
      final sub = subs.firstWhere((s) => s['slug'] == selectedSubclass,
          orElse: () =>
              {'slug': selectedSubclass!, 'name': selectedSubclass!});
      final resolvedSub = SrdClassesLibrary.findSubclass(sub['slug']!,
          classSlug: selectedClassSlug);
      subclassRef = EntityReference<DomainEntity>(
        refType: EntityType.subclass,
        slug: sub['slug']!,
        displayName: sub['name']!,
        customProperties: resolvedSub != null
            ? {
                'featuresMarkdown': resolvedSub.featuresMarkdown,
                'classSlug': resolvedSub.classSlug,
                'shortName': resolvedSub.shortName,
                'grants': resolvedSub.grants.map((g) => g.toMap()).toList(),
                ...resolvedSub.customProperties,
              }
            : const {},
      );
    }

    final edition = character.id.ruleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;

    final limits = SpellAllocationValidator.getLimitsForClass(
      classSlug: selectedClassSlug,
      classLevel: targetClassNewLevel,
      abilityModifier: getCastingModifier(selectedClassSlug),
      subclassSlug: subclassRef?.slug ?? effectiveSubclassSlug,
      edition: edition,
    );
    final curCantripsCount = character.cantrips.length;
    final maxAllowedNewCantrips =
        math.max(0, limits.maxCantrips - curCantripsCount);

    final allowedCantrips = maxAllowedNewCantrips > 0
        ? newCantrips.take(maxAllowedNewCantrips).toList()
        : <String>[];

    final cantripRefs = allowedCantrips.map((c) {
      final spell = SpellbookLibrary.getSpellById(c);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id.slug ?? c.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? c,
      );
    }).toList();

    final allSpellsList = List<String>.from(newSpells);
    final alwaysPrepared =
        SubclassSpellsLibrary.getAlwaysPreparedSpellsForLevel(
      classSlug: selectedClassSlug,
      subclassSlug: subclassRef?.slug ?? effectiveSubclassSlug,
      classLevel: targetClassNewLevel,
      edition: edition,
    );
    for (final s in alwaysPrepared) {
      if (!allSpellsList.contains(s.id.slug)) {
        allSpellsList.add(s.id.slug);
      }
    }

    final spellRefs = allSpellsList.map((s) {
      final spell = SpellbookLibrary.getSpellById(s);
      return EntityReference<Spell>(
        refType: EntityType.spell,
        slug: spell?.id.slug ?? s.toLowerCase().replaceAll(' ', '_'),
        displayName: spell?.getName(edition) ?? s,
      );
    }).toList();

    final arcanumRef = selectedMysticArcanumSpellId != null
        ? () {
            final s =
                SpellbookLibrary.getSpellById(selectedMysticArcanumSpellId!);
            return EntityReference<Spell>(
              refType: EntityType.spell,
              slug: s?.id.slug ??
                  selectedMysticArcanumSpellId!
                      .toLowerCase()
                      .replaceAll(' ', '_'),
              displayName:
                  s?.getName(edition) ?? selectedMysticArcanumSpellId!,
            );
          }()
        : null;

    return LevelUpRequest(
      targetClassSlug: selectedClassSlug,
      targetClassDisplayName: selectedClassSlug.toUpperCase(),
      targetClassHitDie: currentHitDie,
      isMulticlass: isMulticlass,
      subclassRef: subclassRef,
      hpChoice: useFixedAverage
          ? const HpProgressionChoice.average()
          : HpProgressionChoice.rolled(rolledHp),
      asiOrFeat: asiChoice,
      newCantrips: cantripRefs,
      newSpells: spellRefs,
      replacedSpellIds:
          replacedSpellId != null ? [replacedSpellId!] : const [],
      selectedFeatureOptions:
          Map<String, List<String>>.from(selectedFeatureOptions),
      newToolProficiencies: newToolProficiencies.toList(),
      newLanguages: newLanguages.toList(),
      mysticArcanumSpell: arcanumRef,
    );
  }
}
