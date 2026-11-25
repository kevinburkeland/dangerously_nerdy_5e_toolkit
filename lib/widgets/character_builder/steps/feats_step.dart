import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../models/characters/srd_species_library.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../services/haptic_service.dart';
import '../../common/formatted_markdown_text.dart';
import '../../glyphs/dnd_glyph.dart';

class BuilderFeatsStep extends StatelessWidget {
  final String? selectedSpecies;
  final String? selectedClass;
  final RulesetVersion selectedRuleset;
  final String featSearchQuery;
  final String? selectedFeat;
  final AbilityType? selectedFeatAbility;
  final SkillType? selectedFeatSkill;
  final SkillType? selectedFeatExpertise;
  final String? selectedFeatOption;
  final Set<SkillType> wizardSelectedSkills;
  final Set<SkillType> speciesBonusSkillPicks;
  final Set<SkillType> compensatorySkillPicks;
  final Map<String, List<String>> wizardSelectedFeatureOptions;
  final Set<String> selectedWizardCantrips;
  final Set<String> selectedWizardSpells;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Feat> onSelectFeat;
  final ValueChanged<AbilityType> onFeatAbilityChanged;
  final void Function(Feat feat, SkillType skill) onFeatSkillChanged;
  final ValueChanged<SkillType> onFeatExpertiseChanged;
  final ValueChanged<String> onFeatOptionChanged;

  const BuilderFeatsStep({
    super.key,
    required this.selectedSpecies,
    required this.selectedClass,
    required this.selectedRuleset,
    required this.featSearchQuery,
    required this.selectedFeat,
    required this.selectedFeatAbility,
    required this.selectedFeatSkill,
    required this.selectedFeatExpertise,
    required this.selectedFeatOption,
    required this.wizardSelectedSkills,
    required this.speciesBonusSkillPicks,
    required this.compensatorySkillPicks,
    required this.wizardSelectedFeatureOptions,
    required this.selectedWizardCantrips,
    required this.selectedWizardSpells,
    required this.onSearchChanged,
    required this.onSelectFeat,
    required this.onFeatAbilityChanged,
    required this.onFeatSkillChanged,
    required this.onFeatExpertiseChanged,
    required this.onFeatOptionChanged,
  });

  List<FeatureOption> _getEligibleInvocationsForBuilder(Feat feat) {
    final isWarlock = selectedClass?.toLowerCase() == 'warlock';
    final warlockLevel = isWarlock ? 1 : 0;
    final selectedPacts =
        wizardSelectedFeatureOptions.values.expand((opts) => opts);
    final knownSpells = {...selectedWizardCantrips, ...selectedWizardSpells};

    return SrdFeatureOptions.warlockInvocations.where((opt) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curSpecies = selectedSpecies != null
        ? SrdSpeciesLibrary.findBySlug(selectedSpecies!)
        : null;
    final is2024 = selectedRuleset == RulesetVersion.v2024;
    final availableFeats = is2024
        ? SrdFeatsLibrary.getOriginFeats()
        : SrdFeatsLibrary.getFeatsForRuleset(RulesetVersion.v2014);

    final filteredFeats = availableFeats.where((feat) {
      if (featSearchQuery.isEmpty) return true;
      final q = featSearchQuery.toLowerCase();
      final nameMatches = feat.name.toLowerCase().contains(q);
      final slugMatches = feat.id.slug.toLowerCase().contains(q);
      final descMatches = feat.descriptionMarkdown.toLowerCase().contains(q);
      final catMatches = feat.category.toLowerCase().contains(q);
      final prereqMatches =
          feat.prerequisite?.toLowerCase().contains(q) ?? false;
      return nameMatches ||
          slugMatches ||
          descMatches ||
          catMatches ||
          prereqMatches;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          is2024
              ? 'Step 6: Origin Feat'
              : 'Step 6: ${curSpecies?.name ?? "Species"} Bonus Feat',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.cyanAccent),
        ),
        const SizedBox(height: 4),
        Text(
          is2024
              ? 'Choose your starting 1st-level Origin Feat.'
              : 'As a ${curSpecies?.name ?? "adventurer"}, choose your 1st-level bonus feat from the 2014 SRD Feat Library.',
          style:
              theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade400),
        ),
        const SizedBox(height: 12),

        // Search Bar
        TextField(
          decoration: InputDecoration(
            labelText: 'Search Feats',
            hintText: 'Filter by feat name, category, prerequisite...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: featSearchQuery.isNotEmpty
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
        if (filteredFeats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No feats found matching "$featSearchQuery"',
                style: const TextStyle(
                    color: Colors.white54, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          ...filteredFeats.map((feat) {
            final isSelected = selectedFeat == feat.id.slug;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? Colors.cyanAccent.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.cyanAccent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticService.selectionTick(context);
                  onSelectFeat(feat);
                },
                child: Column(
                  children: [
                    ListTile(
                      leading: DndGlyph.feat(
                        category: FeatCategory.parse(feat.category),
                        featId: feat.id.slug,
                        displayName: feat.name,
                        size: 32,
                        isDarkMode: true,
                      ),
                      title: Text(feat.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: FormattedMarkdownText(
                        feat.descriptionMarkdown,
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.white70),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: Colors.purpleAccent)
                          : null,
                    ),
                    if (isSelected && feat.hasAbilityScoreIncrease) ...[
                      const Divider(color: Colors.white12, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (feat.requiresAbilityChoice) ...[
                              Text(
                                'Choose Ability to Increase (+${feat.statIncreaseAmount}):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: feat.selectableAbilities.map((ab) {
                                  final isChipSelected =
                                      (selectedFeatAbility ??
                                              feat.selectableAbilities.first) ==
                                          ab;
                                  return ChoiceChip(
                                    key: Key('builder_feat_ability_${ab.name}'),
                                    label: Text(
                                        '${ab.shortName} (+${feat.statIncreaseAmount})'),
                                    selected: isChipSelected,
                                    selectedColor: Colors.purpleAccent
                                        .withValues(alpha: 0.3),
                                    onSelected: (val) {
                                      if (val) {
                                        HapticService.selectionTick(context);
                                        onFeatAbilityChanged(ab);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ] else ...[
                              Chip(
                                avatar: const Icon(Icons.arrow_upward,
                                    size: 14, color: Colors.greenAccent),
                                label: Text(
                                    '+${feat.statIncreaseAmount} ${feat.selectableAbilities.first.shortName} (Included)'),
                                backgroundColor:
                                    Colors.green.withValues(alpha: 0.15),
                              ),
                            ],
                            if (feat.grantsSavingThrowProficiency) ...[
                              const SizedBox(height: 8),
                              () {
                                final chosenSave = selectedFeatAbility ??
                                    feat.selectableAbilities.first;
                                return Row(
                                  children: [
                                    const Icon(Icons.shield,
                                        color: Colors.cyanAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Grants Proficiency: ${chosenSave.shortName} Saving Throws',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              }(),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (isSelected &&
                        (feat.hasSkillProficiencyChoice ||
                            feat.hasExpertiseChoice)) ...[
                      const Divider(color: Colors.white12, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (feat.hasSkillProficiencyChoice) ...[
                              const Text(
                                'Choose Skill Proficiency:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<SkillType>(
                                key: ValueKey(
                                    'builder_feat_skill_${selectedFeatSkill}_${feat.id.slug}'),
                                initialValue: selectedFeatSkill ??
                                    (feat.selectableSkills.isNotEmpty
                                        ? feat.selectableSkills.first
                                        : SkillType.athletics),
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: (feat.selectableSkills.isNotEmpty
                                        ? feat.selectableSkills
                                        : SkillType.values)
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s.displayName),
                                        ))
                                    .toList(),
                                onChanged: (s) {
                                  if (s != null) {
                                    onFeatSkillChanged(feat, s);
                                  }
                                },
                              ),
                            ],
                            if (feat.hasExpertiseChoice) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Choose Skill for Expertise (Double Proficiency):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              () {
                                final eligible = <SkillType>{
                                  ...wizardSelectedSkills,
                                  ...speciesBonusSkillPicks,
                                  ...compensatorySkillPicks,
                                  ?selectedFeatSkill,
                                };
                                if (eligible.isEmpty) {
                                  eligible.addAll(SkillType.values);
                                }
                                final effectiveVal = eligible
                                        .contains(selectedFeatExpertise)
                                    ? selectedFeatExpertise
                                    : (selectedFeatSkill != null &&
                                            eligible
                                                .contains(selectedFeatSkill)
                                        ? selectedFeatSkill
                                        : eligible.first);

                                return DropdownButtonFormField<SkillType>(
                                  key: ValueKey(
                                      'builder_feat_expertise_${effectiveVal}_$selectedFeatSkill'),
                                  initialValue: effectiveVal,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.black26,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: eligible
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                              s == selectedFeatSkill
                                                  ? '${s.displayName} (From this Feat)'
                                                  : s.displayName,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (s) {
                                    if (s != null) {
                                      onFeatExpertiseChanged(s);
                                    }
                                  },
                                );
                              }(),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (isSelected && feat.hasInvocationChoice) ...[
                      const Divider(color: Colors.white12, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: () {
                          final isWarlock =
                              selectedClass?.toLowerCase() == 'warlock';
                          final eligible =
                              _getEligibleInvocationsForBuilder(feat);
                          final effectiveVal =
                              eligible.any((o) => o.id == selectedFeatOption)
                                  ? selectedFeatOption
                                  : (eligible.isNotEmpty
                                      ? eligible.first.id
                                      : null);
                          final selectedOpt = eligible
                              .where((o) => o.id == effectiveVal)
                              .firstOrNull;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose Eldritch Invocation:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isWarlock
                                    ? 'As a Warlock, you may select any invocation whose prerequisites you meet.'
                                    : 'Without the Warlock class, you may only select invocations with no prerequisites.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                key: const Key(
                                    'builder_feat_invocation_dropdown'),
                                initialValue: effectiveVal,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: eligible
                                    .map((opt) => DropdownMenuItem(
                                          value: opt.id,
                                          child: Text(opt.name),
                                        ))
                                    .toList(),
                                onChanged: (optId) {
                                  if (optId != null) {
                                    onFeatOptionChanged(optId);
                                  }
                                },
                              ),
                              if (selectedOpt != null &&
                                  selectedOpt
                                      .descriptionMarkdown.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade900
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.purpleAccent
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: FormattedMarkdownText(
                                    selectedOpt.descriptionMarkdown,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade300,
                                        fontStyle: FontStyle.italic),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }(),
                      ),
                    ],
                    if (isSelected && feat.hasFightingStyleChoice) ...[
                      const Divider(color: Colors.white12, height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: () {
                          const styles = SrdFeatureOptions.fightingStyles;
                          final effectiveVal =
                              styles.any((o) => o.id == selectedFeatOption)
                                  ? selectedFeatOption
                                  : (styles.isNotEmpty ? styles.first.id : null);
                          final selectedOpt = styles
                              .where((o) => o.id == effectiveVal)
                              .firstOrNull;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Choose Fighting Style:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                key: const Key(
                                    'builder_feat_fighting_style_dropdown'),
                                initialValue: effectiveVal,
                                decoration: InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.black26,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                items: styles
                                    .map((opt) => DropdownMenuItem(
                                          value: opt.id,
                                          child: Text(opt.name),
                                        ))
                                    .toList(),
                                onChanged: (optId) {
                                  if (optId != null) {
                                    onFeatOptionChanged(optId);
                                  }
                                },
                              ),
                              if (selectedOpt != null &&
                                  selectedOpt
                                      .descriptionMarkdown.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade900
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.orangeAccent
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: FormattedMarkdownText(
                                    selectedOpt.descriptionMarkdown,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade300,
                                        fontStyle: FontStyle.italic),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
