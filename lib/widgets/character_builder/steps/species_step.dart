import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/dm_screen_data.dart' show DmRulesEdition;
import '../../../models/characters/srd_backgrounds_library.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../providers/character_builder_controller.dart';
import '../../../services/haptic_service.dart';
import '../../../services/rules/skill_trait_resolver.dart';
import '../../common/formatted_markdown_text.dart';
import '../../glyphs/dnd_glyph.dart';
import '../background_step.dart';
import 'builder_step_order.dart';
import 'species_bonuses_and_traits_section.dart';

class BuilderSpeciesStep extends StatelessWidget {
  final RulesetVersion selectedRuleset;
  final DmRulesEdition rulesEdition;
  final String? selectedSpecies;
  final String? selectedSubrace;
  final String? selectedClass;
  final String? selectedBackground;
  final String speciesSearchQuery;
  final CharacterBuilderController abilityScoreController;
  final AbilityScores wizardBaseScores;
  final Set<SkillType> wizardSelectedSkills;
  final Set<SkillType> compensatorySkillPicks;
  final Set<SkillType> speciesBonusSkillPicks;
  final Set<AbilityType> variantHumanBonuses;
  final String? dwarfToolChoice;
  final Set<String> speciesBonusLanguages;
  final AbilityScores Function(Race? curSpecies, Background? curBackground)
      calculateBonusScores;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Race> onSelectSpecies;
  final void Function(Race sp, Subrace sub) onSelectSubrace;
  final void Function(AbilityType ab, bool selected, int flexibleCount)
      onToggleFlexibleAbility;
  final void Function(SkillType skill, bool selected, int maxCount)
      onToggleSpeciesBonusSkill;
  final ValueChanged<String> onDwarfToolChanged;
  final void Function(String lang, bool selected) onToggleSpeciesBonusLanguage;

  const BuilderSpeciesStep({
    super.key,
    required this.selectedRuleset,
    required this.rulesEdition,
    required this.selectedSpecies,
    required this.selectedSubrace,
    required this.selectedClass,
    required this.selectedBackground,
    required this.speciesSearchQuery,
    required this.abilityScoreController,
    required this.wizardBaseScores,
    required this.wizardSelectedSkills,
    required this.compensatorySkillPicks,
    required this.speciesBonusSkillPicks,
    required this.variantHumanBonuses,
    required this.dwarfToolChoice,
    required this.speciesBonusLanguages,
    required this.calculateBonusScores,
    required this.onSearchChanged,
    required this.onSelectSpecies,
    required this.onSelectSubrace,
    required this.onToggleFlexibleAbility,
    required this.onToggleSpeciesBonusSkill,
    required this.onDwarfToolChanged,
    required this.onToggleSpeciesBonusLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speciesList = SrdSpeciesLibrary.getSpeciesForRuleset(selectedRuleset);
    final selectedSpeciesObj = selectedSpecies != null
        ? SrdSpeciesLibrary.findBySlug(selectedSpecies!)
        : null;
    final edition = selectedRuleset == RulesetVersion.v2024
        ? DmRulesEdition.v2024
        : DmRulesEdition.v2014;
    final speciesBonusSkillCount =
        SkillTraitResolver.getSpeciesBonusSkillCount(selectedSpecies, edition);
    final curClass = selectedClass != null
        ? SrdClassesLibrary.findBySlug(selectedClass!, ruleset: selectedRuleset)
        : null;
    final curBackground = selectedBackground != null
        ? SrdBackgroundsLibrary.findBySlug(selectedBackground!)
        : null;

    final selectedSubraceObj =
        (selectedSubrace != null && selectedSpeciesObj != null)
            ? selectedSpeciesObj.subraces
                .where((s) => s.id.slug == selectedSubrace)
                .firstOrNull
            : null;
    final subFlexCount = selectedSubraceObj?.flexibleAbilityChoiceCount ?? 0;
    final hasSubBonuses = selectedSubraceObj != null &&
        (selectedSubraceObj.fixedAbilityBonuses2014.isNotEmpty ||
            subFlexCount > 0);
    final flexibleCount = hasSubBonuses
        ? subFlexCount
        : (selectedSpeciesObj?.flexibleAbilityChoiceCount ?? 0);
    final flexibleBonusValue = (selectedSubraceObj != null &&
            selectedSubraceObj.flexibleAbilityBonus > 0)
        ? selectedSubraceObj.flexibleAbilityBonus
        : (selectedSpeciesObj?.flexibleAbilityBonusValue ?? 1);
    final fixedBonuses = hasSubBonuses
        ? selectedSubraceObj.fixedAbilityBonuses2014
        : (selectedSpeciesObj?.fixedAbilityBonuses2014 ?? const {});
    final flexiblePool = hasSubBonuses
        ? selectedSubraceObj.flexibleAbilityPool
        : selectedSpeciesObj?.flexibleAbilityPool;

    final spReport = curClass != null
        ? SkillTraitResolver.resolveSkills(
            speciesSlug: selectedSpecies,
            subraceSlug: selectedSubrace,
            backgroundSlug: selectedBackground,
            classSlug: curClass.id.slug,
            requestedClassSkills: wizardSelectedSkills,
            compensatoryPicks: compensatorySkillPicks,
            speciesBonusSkills: speciesBonusSkillPicks,
            edition: edition,
          )
        : null;
    final alreadyTaken = spReport?.resolvedProficiencies.keys.toSet() ??
        {
          ...wizardSelectedSkills,
          ...abilityScoreController.grantedSpeciesSkills,
        };
    final eligibleBonusSkills = SkillType.values.where((sk) {
      return !alreadyTaken.contains(sk) || speciesBonusSkillPicks.contains(sk);
    }).toList();

    final filteredSpecies = speciesList.where((sp) {
      if (speciesSearchQuery.isEmpty) return true;
      final q = speciesSearchQuery.toLowerCase();
      final nameMatches = sp.name.toLowerCase().contains(q);
      final slugMatches = sp.id.slug.toLowerCase().contains(q);
      final traitsMatch = sp.traitsMarkdown.toLowerCase().contains(q);
      final speedMatch = sp.speed.toLowerCase().contains(q);
      final summaryMatch =
          sp.abilityScoreSummary?.toLowerCase().contains(q) ?? false;
      final subraceMatches = sp.subraces.any((sub) =>
          sub.name.toLowerCase().contains(q) ||
          sub.traitsMarkdown.toLowerCase().contains(q));
      return nameMatches ||
          slugMatches ||
          traitsMatch ||
          speedMatch ||
          summaryMatch ||
          subraceMatches;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step 2: Choose Species / Race',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        const SizedBox(height: 6),
        const Text(
            'Select your character lineage from standard SRD and imported homebrew species.',
            style: TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 12),

        // Search Bar
        TextField(
          decoration: InputDecoration(
            labelText: 'Search Species / Races',
            hintText: 'Filter by species name, subrace, traits, speed...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: speciesSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onSearchChanged(''),
                  )
                : null,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (val) => onSearchChanged(val.trim()),
        ),
        const SizedBox(height: 12),
        SkillRefundAlertSection(controller: abilityScoreController),
        if (filteredSpecies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No species found matching "$speciesSearchQuery"',
                style: const TextStyle(
                    color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ...filteredSpecies.map((sp) {
            final isSelected = selectedSpecies == sp.id.slug;
            final spType = findBuilderSpeciesType(sp.id.slug);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.cyan.shade900.withValues(alpha: 0.3)
                    : Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.cyanAccent : Colors.white12,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? Colors.cyanAccent
                                : Colors.white54,
                          ),
                          const SizedBox(width: 8),
                          RepaintBoundary(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                child: DndGlyph.species(
                                  speciesType: spType,
                                  size: 32,
                                  isDarkMode: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(sp.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          'Speed: ${sp.getSpeedForEdition(rulesEdition)} • Size: ${sp.size}\n${sp.abilityScoreSummary ?? ""}',
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.white70)),
                      onTap: () {
                        HapticService.selectionTick(context);
                        onSelectSpecies(sp);
                      },
                    ),
                    if (isSelected && sp.subraces.isNotEmpty) ...[
                      const Divider(height: 1, color: Colors.cyanAccent),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_tree_outlined,
                                    size: 16, color: Colors.cyanAccent),
                                const SizedBox(width: 6),
                                Text(
                                  'Choose Subspecies / Lineage (${sp.subraces.length} available):',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Colors.cyanAccent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...sp.subraces.map((sub) {
                              final isSubSelected =
                                  selectedSubrace == sub.id.slug;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: Material(
                                  color: isSubSelected
                                      ? Colors.cyan.shade900
                                          .withValues(alpha: 0.5)
                                      : Colors.black12,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    side: BorderSide(
                                      color: isSubSelected
                                          ? Colors.cyanAccent
                                          : Colors.white10,
                                      width: isSubSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: Icon(
                                      isSubSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: isSubSelected
                                          ? Colors.cyanAccent
                                          : Colors.white38,
                                    ),
                                    title: Text(
                                      sub.name,
                                      style: TextStyle(
                                        fontWeight: isSubSelected
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        fontSize: 13,
                                        color: isSubSelected
                                            ? Colors.white
                                            : Colors.white70,
                                      ),
                                    ),
                                    subtitle: ((sub.abilityScoreSummary
                                                    ?.isNotEmpty ==
                                                true) ||
                                            (sub.speed?.isNotEmpty == true) ||
                                            (sub.darkvision != null &&
                                                sub.darkvision! > 0) ||
                                            sub.traitsMarkdown.isNotEmpty)
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if ((sub.abilityScoreSummary
                                                          ?.isNotEmpty ==
                                                      true) ||
                                                  (sub.speed?.isNotEmpty ==
                                                      true) ||
                                                  (sub.darkvision != null &&
                                                      sub.darkvision! > 0)) ...[
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (sub.abilityScoreSummary
                                                            ?.isNotEmpty ==
                                                        true)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .cyanAccent
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .cyanAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)),
                                                        ),
                                                        child: Text(
                                                          sub.abilityScoreSummary!,
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .cyanAccent),
                                                        ),
                                                      ),
                                                    if (sub.speed?.isNotEmpty ==
                                                        true)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .greenAccent
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .greenAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)),
                                                        ),
                                                        child: Text(
                                                          'Speed ${sub.speed!.contains("ft") ? sub.speed : "${sub.speed} ft."}',
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .greenAccent),
                                                        ),
                                                      ),
                                                    if (sub.darkvision !=
                                                            null &&
                                                        sub.darkvision! > 0)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .purpleAccent
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .purpleAccent
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)),
                                                        ),
                                                        child: Text(
                                                          'Darkvision ${sub.darkvision} ft.',
                                                          style: const TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors
                                                                  .purpleAccent),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                              if (sub.traitsMarkdown
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                FormattedMarkdownText(
                                                  sub.traitsMarkdown,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.white70),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          )
                                        : null,
                                    onTap: () {
                                      HapticService.selectionTick(context);
                                      onSelectSubrace(sp, sub);
                                    },
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    if (isSelected)
                      BuilderSpeciesBonusesAndTraitsSection(
                        species: sp,
                        selectedSubraceObj: selectedSubraceObj,
                        curBackground: curBackground,
                        selectedRuleset: selectedRuleset,
                        abilityScoreController: abilityScoreController,
                        wizardBaseScores: wizardBaseScores,
                        flexibleCount: flexibleCount,
                        flexibleBonusValue: flexibleBonusValue,
                        fixedBonuses: fixedBonuses,
                        flexiblePool: flexiblePool,
                        variantHumanBonuses: variantHumanBonuses,
                        speciesBonusSkillCount: speciesBonusSkillCount,
                        eligibleBonusSkills: eligibleBonusSkills,
                        speciesBonusSkillPicks: speciesBonusSkillPicks,
                        dwarfToolChoice: dwarfToolChoice,
                        speciesBonusLanguages: speciesBonusLanguages,
                        bonusScores: calculateBonusScores(sp, curBackground),
                        onToggleFlexibleAbility: onToggleFlexibleAbility,
                        onToggleSpeciesBonusSkill: onToggleSpeciesBonusSkill,
                        onDwarfToolChanged: onDwarfToolChanged,
                        onToggleSpeciesBonusLanguage:
                            onToggleSpeciesBonusLanguage,
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
