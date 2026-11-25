import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/characters/srd_equipment_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../models/spellbook_data.dart';
import '../../../services/haptic_service.dart';
import '../../../services/rules/skill_trait_resolver.dart';

class BuilderReviewStep extends StatelessWidget {
  final Race? curSpecies;
  final CharacterClass? curClass;
  final Background? curBackground;
  final int totalSteps;
  final TextEditingController nameController;
  final RulesetVersion selectedRuleset;
  final String? selectedSpecies;
  final String? selectedSubrace;
  final String? selectedBackground;
  final String? selectedFeat;
  final AbilityType? selectedFeatAbility;
  final SkillType? selectedFeatSkill;
  final SkillType? selectedFeatExpertise;
  final String? selectedStartingEquipmentPreset;
  final AbilityScores wizardBaseScores;
  final Set<SkillType> wizardSelectedSkills;
  final Set<SkillType> compensatorySkillPicks;
  final Set<SkillType> speciesBonusSkillPicks;
  final Set<String> selectedWizardCantrips;
  final Set<String> selectedWizardSpells;
  final Set<String> allBuilderLanguages;
  final Set<String> allBuilderTools;
  final Set<String> builderLanguages;
  final Set<String> builderToolProficiencies;
  final VoidCallback onAddLanguage;
  final VoidCallback onAddTool;
  final ValueChanged<VoidCallback> onMutateState;

  const BuilderReviewStep({
    super.key,
    required this.curSpecies,
    required this.curClass,
    required this.curBackground,
    required this.totalSteps,
    required this.nameController,
    required this.selectedRuleset,
    required this.selectedSpecies,
    required this.selectedSubrace,
    required this.selectedBackground,
    required this.selectedFeat,
    required this.selectedFeatAbility,
    required this.selectedFeatSkill,
    required this.selectedFeatExpertise,
    required this.selectedStartingEquipmentPreset,
    required this.wizardBaseScores,
    required this.wizardSelectedSkills,
    required this.compensatorySkillPicks,
    required this.speciesBonusSkillPicks,
    required this.selectedWizardCantrips,
    required this.selectedWizardSpells,
    required this.allBuilderLanguages,
    required this.allBuilderTools,
    required this.builderLanguages,
    required this.builderToolProficiencies,
    required this.onAddLanguage,
    required this.onAddTool,
    required this.onMutateState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sp = curSpecies;
    final cls = curClass;
    final bg = curBackground;
    if (sp == null || cls == null || bg == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Step $totalSteps: Review & Finalize',
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please complete all prior steps (Species, Class, Background, Ability Scores) before reviewing.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final name = nameController.text.trim().isEmpty
        ? 'Adventurer'
        : nameController.text.trim();
    final is2024 = selectedRuleset == RulesetVersion.v2024;
    final hasFeat = is2024 || sp.grantsBonusFeat;
    final selectedPkg = (selectedStartingEquipmentPreset != null
            ? SrdEquipmentLibrary.findPackageById(
                selectedStartingEquipmentPreset!)
            : null) ??
        SrdEquipmentLibrary.getPackagesForClass(cls.id.slug).first;
    final stepNumber = totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $stepNumber: Review & Finalize',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        const SizedBox(height: 6),
        const Text(
            'Review your generated character summary before launching the live sheet.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const Divider(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white)),
          subtitle: Text(
              'Level 1 ${cls.name} • ${sp.name} • ${bg.name}\nRuleset: ${selectedRuleset.name.toUpperCase()}',
              style: const TextStyle(color: Colors.cyanAccent)),
        ),
        const SizedBox(height: 8),
        Text('Class Saving Throws: ${cls.savingThrows.join(", ")}',
            style: const TextStyle(fontSize: 12)),
        Builder(builder: (ctx) {
          final reviewSkillReport = SkillTraitResolver.resolveSkills(
            speciesSlug: selectedSpecies,
            subraceSlug: selectedSubrace,
            backgroundSlug: selectedBackground,
            classSlug: cls.id.slug,
            requestedClassSkills: wizardSelectedSkills,
            compensatoryPicks: compensatorySkillPicks,
            speciesBonusSkills: speciesBonusSkillPicks,
            edition: selectedRuleset == RulesetVersion.v2024
                ? DmRulesEdition.v2024
                : DmRulesEdition.v2014,
          );
          final allReviewSkills = {
            ...reviewSkillReport.resolvedProficiencies.keys,
            ...speciesBonusSkillPicks
          };
          return Text(
              'Skill Proficiencies: ${allReviewSkills.map((s) => s.displayName).join(", ")}',
              style: const TextStyle(fontSize: 12));
        }),
        if (hasFeat && selectedFeat != null) ...[
          () {
            final feat = SrdFeatsLibrary.findBySlug(selectedFeat!);
            final chosenAbility = selectedFeatAbility ??
                (feat?.selectableAbilities.isNotEmpty == true
                    ? feat!.selectableAbilities.first
                    : null);
            final skillPart = (feat != null &&
                    feat.hasSkillProficiencyChoice &&
                    selectedFeatSkill != null)
                ? ', ${selectedFeatSkill!.displayName} Prof'
                : '';
            final expPart = (feat != null &&
                    feat.hasExpertiseChoice &&
                    selectedFeatExpertise != null)
                ? ', ${selectedFeatExpertise!.displayName} Expertise'
                : '';
            final extra = (feat != null &&
                    feat.hasAbilityScoreIncrease &&
                    chosenAbility != null)
                ? ' (+${feat.statIncreaseAmount} ${chosenAbility.shortName}${feat.grantsSavingThrowProficiency ? ', ${chosenAbility.shortName} Save Prof' : ''}$skillPart$expPart)'
                : (skillPart.isNotEmpty || expPart.isNotEmpty
                    ? ' (${[
                        skillPart,
                        expPart
                      ].where((s) => s.isNotEmpty).join(", ").replaceFirst(", ", "")})'
                    : '');
            return Text(
              '${is2024 ? 'Origin Feat' : 'Feat'}: ${feat?.name ?? selectedFeat!.toUpperCase()}$extra',
              style: const TextStyle(fontSize: 12, color: Colors.purpleAccent),
            );
          }(),
        ],
        if (selectedWizardCantrips.isNotEmpty ||
            selectedWizardSpells.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Spells: ${selectedWizardCantrips.length} Cantrips, ${selectedWizardSpells.length} 1st-Level Spells',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.purpleAccent,
                fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 4),
        Text(
            'Starting Inventory: ${selectedPkg.name} (${selectedPkg.startingGold} GP)',
            style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
        const SizedBox(height: 8),
        Text(
            'Scores: STR ${wizardBaseScores.strength}, DEX ${wizardBaseScores.dexterity}, CON ${wizardBaseScores.constitution}, INT ${wizardBaseScores.intelligence}, WIS ${wizardBaseScores.wisdom}, CHA ${wizardBaseScores.charisma}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.amberAccent)),
        const Divider(height: 18),
        // Languages Known
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, size: 16, color: Colors.cyanAccent),
                const SizedBox(width: 6),
                const Text('Languages Known:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${allBuilderLanguages.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent)),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => onAddLanguage(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Language', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: allBuilderLanguages.map((l) {
            final isCommon = l.toLowerCase() == 'common';
            return Chip(
              label: Text(l, style: const TextStyle(fontSize: 11)),
              deleteIcon: isCommon ? null : const Icon(Icons.close, size: 12),
              onDeleted: isCommon
                  ? null
                  : () {
                      HapticService.selectionTick(context);
                      onMutateState(() => builderLanguages.remove(l));
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Tool Proficiencies
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.construction,
                    size: 16, color: Colors.amberAccent),
                const SizedBox(width: 6),
                const Text('Tool Proficiencies:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${allBuilderTools.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent)),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => onAddTool(),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add Tool', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (allBuilderTools.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('None (tap "+ Add Tool" to add tool proficiency)',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: allBuilderTools
                .map((t) => Chip(
                      label: Text(t, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 12),
                      onDeleted: () {
                        HapticService.selectionTick(context);
                        onMutateState(() => builderToolProficiencies.remove(t));
                      },
                    ))
                .toList(),
          ),
      ],
    );
  }
}
