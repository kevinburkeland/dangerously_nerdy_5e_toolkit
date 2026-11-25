import '../../../models/app_settings.dart';
import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/spellbook_data.dart';
import '../../../providers/character_builder_controller.dart';

const List<String> kBuilderSuggestedNames = [
    'Valeros Ironclad',
    'Eldrin Shadowbane',
    'Kaelen Swift',
    'Lyra Sunseeker',
    'Thorek Stoneguard',
    'Aria Whisperwind',
    'Morgrim Battlehammer',
    'Zephyr Stormcaller',
    'Vespera Nightshade',
    'Rowan Oakheart',
    'Gideon Dawnbringer',
    'Cassian Brightwood',
  ];


DndClassType? findBuilderClassType(String? slug) {
    if (slug == null) return null;
    final s = slug.toLowerCase();
    for (final c in DndClassType.values) {
      if (c.name.toLowerCase() == s || c.displayName.toLowerCase() == s)
        return c;
    }
    return null;
  }



SpeciesType findBuilderSpeciesType(String? slug) {
    if (slug == null) return SpeciesType.human;
    final s = slug.toLowerCase();
    if (s.contains('human')) return SpeciesType.human;
    for (final sp in SpeciesType.values) {
      if (sp.name.toLowerCase() == s ||
          sp.displayName.toLowerCase() == s ||
          s.contains(sp.name.toLowerCase())) return sp;
    }
    return SpeciesType.human;
  }


Set<String> collectBuilderKnownSpellSlugs({
  required Set<String> selectedWizardCantrips,
  required Set<String> selectedWizardSpells,
}) {
    final slugs = <String>{};
    for (final id in selectedWizardCantrips) {
      slugs.add(id.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(id);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    for (final id in selectedWizardSpells) {
      slugs.add(id.toLowerCase().trim());
      final item = SpellbookLibrary.getSpellById(id);
      if (item != null) {
        slugs.add(item.name.toLowerCase().trim());
      }
    }
    return slugs;
  }



Set<String> collectBuilderSelectedPacts(
  Map<String, List<String>> wizardSelectedFeatureOptions,
) {
    final pacts = <String>{};
    final pactRegex = RegExp(r'pact[-_ ](?:of[-_ ]the[-_ ])?([a-z0-9]+)',
        caseSensitive: false);
    for (final list in wizardSelectedFeatureOptions.values) {
      for (final id in list) {
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
    return pacts;
  }


ClassSpellcasterProfile resolveBuilderCasterProfile(
  String? classSlug,
  RulesetVersion ruleset,
) {
  if (classSlug == null) {
    return const ClassSpellcasterProfile.nonCaster();
  }
  final edition = ruleset == RulesetVersion.v2024
      ? RulesetEdition.v2024
      : RulesetEdition.v2014;
  return resolveClassSpellcasterProfile(
    classSlug: classSlug,
    classLevel: 1,
    edition: edition,
  );
}

List<String> computeWizardStepTypes({
  required String? selectedSpecies,
  required String? selectedClass,
  required RulesetVersion selectedRuleset,
  required WizardOrderingPreset preset,
}) {
  final curSpecies = selectedSpecies != null
      ? SrdSpeciesLibrary.findBySlug(selectedSpecies)
      : null;
  final is2024 = selectedRuleset == RulesetVersion.v2024;
  final hasFeatStep =
      (is2024 && SrdFeatsLibrary.getOriginFeats().isNotEmpty) ||
          (curSpecies?.grantsBonusFeat ?? false);
  final curClass = selectedClass != null
      ? SrdClassesLibrary.findBySlug(selectedClass, ruleset: selectedRuleset)
      : null;
  final isCaster =
      resolveBuilderCasterProfile(selectedClass, selectedRuleset).isSpellcaster;
  final hasSubclass = curClass != null &&
      curClass.getSubclassLevel(selectedRuleset) == 1 &&
      curClass.subclasses.isNotEmpty;
  final lvl1Decisions =
      curClass?.getDecisionsForLevel(1, ruleset: selectedRuleset) ?? [];
  final hasDecisions = lvl1Decisions.isNotEmpty;

  final steps = <String>['basics'];

  void addClassBlocks() {
    steps.add('class');
    if (hasSubclass) steps.add('subclass');
    if (hasDecisions) steps.add('class_decisions');
  }

  switch (preset) {
    case WizardOrderingPreset.modern2024:
      addClassBlocks();
      steps.add('background');
      steps.add('species');
      steps.add('scores');
    case WizardOrderingPreset.attributesFirst:
      steps.add('scores');
      addClassBlocks();
      steps.add('species');
      steps.add('background');
    case WizardOrderingPreset.classic2014:
      steps.add('species');
      addClassBlocks();
      steps.add('background');
      steps.add('scores');
  }

  if (hasFeatStep) steps.add('feats');
  if (isCaster) steps.add('spells');
  steps.add('equipment');
  steps.add('review');
  return steps;
}

bool canAdvanceWizardStep({
  required String currentStepKey,
  required CharacterBuilderController abilityScoreController,
  required RulesetVersion selectedRuleset,
  required String? selectedSpecies,
  required String? selectedSubrace,
  required Set<AbilityType> variantHumanBonuses,
  required String? wizardSelectedSubclass,
  required String? selectedFeat,
  required String? selectedStartingEquipmentPreset,
}) {
  switch (currentStepKey) {
    case 'basics':
      return true;
    case 'species':
      final curSp = selectedSpecies != null
          ? SrdSpeciesLibrary.findBySlug(selectedSpecies)
          : null;
      final chosenSub = selectedSubrace != null
          ? curSp?.subraces
              .where((s) => s.id.slug == selectedSubrace)
              .firstOrNull
          : null;
      final hasSubBonuses = chosenSub != null &&
          (chosenSub.fixedAbilityBonuses2014.isNotEmpty ||
              chosenSub.flexibleAbilityChoiceCount > 0);
      final flexCount = hasSubBonuses
          ? chosenSub.flexibleAbilityChoiceCount
          : (curSp?.flexibleAbilityChoiceCount ?? 0);
      final isNon2024 = selectedRuleset != RulesetVersion.v2024;
      final subraceValid = curSp == null ||
          curSp.subraces.isEmpty ||
          selectedSubrace != null;
      final statsChosenBeforeSpecies =
          abilityScoreController.isAbilityAllocationComplete;
      final flexibleValid = !isNon2024 ||
          flexCount == 0 ||
          !statsChosenBeforeSpecies ||
          variantHumanBonuses.length == flexCount;
      return abilityScoreController.hasValidSpecies &&
          abilityScoreController.refundedSkillChoices == 0 &&
          subraceValid &&
          flexibleValid;
    case 'class':
      return abilityScoreController.hasValidClass;
    case 'subclass':
      return wizardSelectedSubclass != null;
    case 'class_decisions':
      return true;
    case 'background':
      return abilityScoreController.hasValidBackground &&
          abilityScoreController.refundedSkillChoices == 0;
    case 'scores':
      return abilityScoreController.isAbilityAllocationComplete;
    case 'feats':
      return selectedFeat != null;
    case 'spells':
      return true;
    case 'equipment':
      return selectedStartingEquipmentPreset != null;
    default:
      return true;
  }
}

Set<String> computeBuilderLanguages({
  required Set<String> builderLanguages,
  required String? selectedSpecies,
  required Set<String> speciesBonusLanguages,
  required String? selectedClass,
  required String? selectedBackground,
}) {
  final result = Set<String>.from(builderLanguages);
  if (result.isEmpty) result.add('Common');
  final spSlug = selectedSpecies?.toLowerCase();
  if (spSlug != null) {
    if (spSlug.contains('dwarf')) result.add('Dwarvish');
    if (spSlug.contains('elf') && !spSlug.contains('half-elf')) {
      result.add('Elvish');
    }
    if (spSlug.contains('half-elf')) result.add('Elvish');
    if (spSlug.contains('halfling')) result.add('Halfling');
    if (spSlug.contains('dragonborn')) result.add('Draconic');
    if (spSlug.contains('gnome')) result.add('Gnomish');
    if (spSlug.contains('half-orc')) result.add('Orc');
    if (spSlug.contains('tiefling')) result.add('Infernal');
    result.addAll(speciesBonusLanguages);
  }
  if (selectedClass?.toLowerCase() == 'rogue') result.add('Thieves\' Cant');
  if (selectedClass?.toLowerCase() == 'druid') result.add('Druidic');
  if (selectedBackground != null) {
    final bg = SrdBackgroundsLibrary.findBySlug(selectedBackground);
    if (bg != null) result.addAll(bg.languages);
  }
  return result;
}

Set<String> computeBuilderTools({
  required Set<String> builderToolProficiencies,
  required String? selectedSpecies,
  required String? dwarfToolChoice,
  required String? selectedClass,
  required Set<String> classBonusTools,
  required String? selectedBackground,
}) {
  final result = Set<String>.from(builderToolProficiencies);
  final spSlug = selectedSpecies?.toLowerCase();
  if (spSlug != null) {
    if (spSlug.contains('dwarf')) {
      result.add(dwarfToolChoice ?? 'Smith\'s Tools');
    }
    if (spSlug.contains('rock') && spSlug.contains('gnome')) {
      result.add('Tinker\'s Tools');
    }
  }
  final clSlug = selectedClass?.toLowerCase();
  if (clSlug != null) {
    if (clSlug == 'rogue') result.add('Thieves\' Tools');
    if (clSlug == 'druid') result.add('Herbalism Kit');
    result.addAll(classBonusTools);
  }
  if (selectedBackground != null) {
    final bg = SrdBackgroundsLibrary.findBySlug(selectedBackground);
    if (bg != null) result.addAll(bg.toolProficiencies);
  }
  return result;
}

AbilityScores computeBuilderOriginBonuses({
  required Race? curSpecies,
  required Background? curBackground,
  required RulesetVersion ruleset,
  required Set<AbilityType> variantHumanBonuses,
  required AbilityType backgroundPrimaryBonus,
  required AbilityType backgroundSecondaryBonus,
  Subrace? curSubrace,
}) {
  if (ruleset == RulesetVersion.v2014) {
    if (curSpecies == null && curSubrace == null) {
      return const AbilityScores.zero();
    }
    final hasSubraceAbilities = curSubrace != null &&
        (curSubrace.fixedAbilityBonuses2014.isNotEmpty ||
            curSubrace.flexibleAbilityChoiceCount > 0);
    return computeOriginAbilityBonuses(
      edition: RulesetEdition.v2014,
      fixedBonuses2014: hasSubraceAbilities
          ? curSubrace.fixedAbilityBonuses2014
          : (curSpecies?.fixedAbilityBonuses2014 ?? const {}),
      flexibleChoiceCount2014: hasSubraceAbilities
          ? curSubrace.flexibleAbilityChoiceCount
          : (curSpecies?.flexibleAbilityChoiceCount ?? 0),
      flexibleBonusValue2014: hasSubraceAbilities
          ? curSubrace.flexibleAbilityBonusValue
          : (curSpecies?.flexibleAbilityBonusValue ?? 0),
      flexibleChoices2014: variantHumanBonuses,
    );
  }
  if (curBackground == null) return const AbilityScores.zero();
  return computeOriginAbilityBonuses(
    edition: RulesetEdition.v2024,
    backgroundPrimary2024: backgroundPrimaryBonus,
    backgroundSecondary2024: backgroundSecondaryBonus,
  );
}

void pruneBuilderFlexibleChoices({
  required Race sp,
  required String? subSlug,
  required RulesetVersion selectedRuleset,
  required Set<AbilityType> variantHumanBonuses,
  required CharacterBuilderController abilityScoreController,
}) {
  final is2014 = selectedRuleset == RulesetVersion.v2014;
  final chosenSub = subSlug != null
      ? sp.subraces.where((s) => s.id.slug == subSlug).firstOrNull
      : null;
  final hasSubAbilities = chosenSub != null &&
      (chosenSub.fixedAbilityBonuses2014.isNotEmpty ||
          chosenSub.flexibleAbilityChoiceCount > 0);
  final flexCount = is2014
      ? (hasSubAbilities
          ? chosenSub.flexibleAbilityChoiceCount
          : sp.flexibleAbilityChoiceCount)
      : 0;
  if (flexCount == 0) {
    variantHumanBonuses.clear();
  } else {
    final fixed = hasSubAbilities
        ? chosenSub.fixedAbilityBonuses2014
        : sp.fixedAbilityBonuses2014;
    final pool = hasSubAbilities
        ? chosenSub.flexibleAbilityPool
        : sp.flexibleAbilityPool;
    final validAbilities = AbilityType.values
        .where((a) => !fixed.containsKey(a.name.toLowerCase()))
        .where((a) =>
            pool == null ||
            pool.isEmpty ||
            pool.any((p) {
              final pStr = p.toLowerCase().trim();
              final prefix = pStr.length > 3 ? pStr.substring(0, 3) : pStr;
              return a.name.toLowerCase().startsWith(prefix);
            }))
        .toList();
    variantHumanBonuses.retainAll(validAbilities);
    while (variantHumanBonuses.length > flexCount) {
      variantHumanBonuses.remove(variantHumanBonuses.last);
    }
  }
  abilityScoreController
      .setFlexibleAbilityChoices(variantHumanBonuses.toList());
}

EntityReference buildSpeciesEntityRef(Race sp) {
  return EntityReference(
    refType: EntityType.species,
    slug: sp.id.slug,
    displayName: sp.name,
    customProperties: {
      if (sp.flexibleAbilityPool != null)
        'flexibleAbilityPool': sp.flexibleAbilityPool,
      if (sp.flexibleAbilityChoiceCount > 0)
        'flexibleAbilityCount': sp.flexibleAbilityChoiceCount,
      if (sp.flexibleAbilityBonus > 0)
        'flexibleAbilityBonus': sp.flexibleAbilityBonus,
      if (sp.fixedAbilityBonuses2014.isNotEmpty)
        'fixedAbilityBonuses': sp.fixedAbilityBonuses2014,
    },
  );
}

EntityReference buildSubraceEntityRef(Subrace sub) {
  return EntityReference(
    refType: EntityType.species,
    slug: sub.id.slug,
    displayName: sub.name,
    customProperties: {
      if (sub.flexibleAbilityPool != null)
        'flexibleAbilityPool': sub.flexibleAbilityPool,
      if (sub.flexibleAbilityCount > 0)
        'flexibleAbilityCount': sub.flexibleAbilityCount,
      if (sub.flexibleAbilityBonus > 0)
        'flexibleAbilityBonus': sub.flexibleAbilityBonus,
      if (sub.fixedAbilityBonuses.isNotEmpty)
        'fixedAbilityBonuses': sub.fixedAbilityBonuses,
    },
  );
}

({
  AbilityType? ability,
  SkillType? skill,
  SkillType? expertise,
  String? option,
}) resolveFeatSelectionDefaults({
  required Feat feat,
  required AbilityType? currentAbility,
  required SkillType? currentSkill,
  required SkillType? currentExpertise,
  required String? selectedClass,
  required Set<SkillType> wizardSelectedSkills,
  required Set<SkillType> speciesBonusSkillPicks,
  required Set<SkillType> compensatorySkillPicks,
  required Map<String, List<String>> wizardSelectedFeatureOptions,
  required Set<String> selectedWizardCantrips,
  required Set<String> selectedWizardSpells,
}) {
  AbilityType? nextAbility;
  if (feat.hasAbilityScoreIncrease) {
    nextAbility =
        (currentAbility != null && feat.selectableAbilities.contains(currentAbility))
            ? currentAbility
            : feat.selectableAbilities.first;
  }

  SkillType? nextSkill;
  if (feat.hasSkillProficiencyChoice) {
    final selectable = feat.selectableSkills.isNotEmpty
        ? feat.selectableSkills
        : SkillType.values.toList();
    nextSkill = (currentSkill != null && selectable.contains(currentSkill))
        ? currentSkill
        : selectable.first;
  }

  SkillType? nextExpertise;
  if (feat.hasExpertiseChoice) {
    final eligible = <SkillType>{
      ...wizardSelectedSkills,
      ...speciesBonusSkillPicks,
      ...compensatorySkillPicks,
      ?nextSkill,
    };
    if (eligible.isEmpty) eligible.addAll(SkillType.values);
    nextExpertise =
        (currentExpertise != null && eligible.contains(currentExpertise))
            ? currentExpertise
            : (nextSkill ?? eligible.first);
  }

  String? nextOption;
  if (feat.hasInvocationChoice) {
    final isWarlock = selectedClass?.toLowerCase() == 'warlock';
    final selectedPacts =
        wizardSelectedFeatureOptions.values.expand((opts) => opts);
    final knownSpells = {...selectedWizardCantrips, ...selectedWizardSpells};
    final eligible = SrdFeatureOptions.warlockInvocations
        .where((opt) => feat
            .evaluateInvocationPrerequisite(
              opt,
              isWarlock: isWarlock,
              warlockLevel: isWarlock ? 1 : 0,
              selectedPacts: selectedPacts,
              knownSpellSlugs: knownSpells,
            )
            .isMet)
        .toList();
    nextOption = eligible.isNotEmpty ? eligible.first.id : null;
  } else if (feat.hasFightingStyleChoice) {
    nextOption = SrdFeatureOptions.fightingStyles.isNotEmpty
        ? SrdFeatureOptions.fightingStyles.first.id
        : null;
  }

  return (
    ability: nextAbility,
    skill: nextSkill,
    expertise: nextExpertise,
    option: nextOption,
  );
}
