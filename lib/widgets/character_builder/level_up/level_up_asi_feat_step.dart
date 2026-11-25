import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import '../../common/formatted_markdown_text.dart';
import '../../glyphs/dnd_glyph.dart';
import 'level_up_wizard_controller.dart';

class LevelUpAsiFeatStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;

  const LevelUpAsiFeatStep({
    super.key,
    required this.controller,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStep4AsiOrFeat(context, Theme.of(context), customColors);
  }

  Widget _buildStep4AsiOrFeat(
      BuildContext context, ThemeData theme, TabletopColors? customColors) {
    if (!controller.isAsiEligible) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              'No ASI / Feat Milestone at Level ${controller.targetClassNewLevel}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.selectedClassSlug} grants ASI/Feats at levels 4, 8, 12, 16, 19.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ability Score Improvement (ASI) or Feat',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
            'Milestone reached! Choose between increasing ability scores or gaining a new Feat.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true, label: Text('Ability Score Improvement')),
            ButtonSegment(value: false, label: Text('Choose Feat')),
          ],
          selected: {controller.isAsiSelected},
          onSelectionChanged: (set) =>
              controller.mutate(() => controller.isAsiSelected = set.first),
        ),
        const SizedBox(height: 16),
        if (controller.isAsiSelected) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('+2 to One Score')),
              ButtonSegment(value: false, label: Text('+1 to Two Scores')),
            ],
            selected: {controller.isAsiPlusTwo},
            onSelectionChanged: (set) =>
                controller.mutate(() => controller.isAsiPlusTwo = set.first),
          ),
          const SizedBox(height: 16),
          if (controller.isAsiPlusTwo) ...[
            DropdownButtonFormField<AbilityType>(
              isExpanded: true,
              initialValue: controller.asiSingleAbility,
              decoration: const InputDecoration(
                  labelText: '+2 Ability Score', border: OutlineInputBorder()),
              items: AbilityType.values.map((a) {
                final cur = controller.character.rawAbilityScores.getScore(a);
                final max = controller.character.getAbilityScoreMaximum(a);
                return DropdownMenuItem(
                  value: a,
                  child: Text(
                      '${a.name.toUpperCase()} (Current: $cur, Max: $max)'),
                );
              }).toList(),
              onChanged: (v) => controller.mutate(() => controller.asiSingleAbility = v!),
            ),
            if (controller.character.rawAbilityScores.getScore(controller.asiSingleAbility) +
                    2 >
                controller.character.getAbilityScoreMaximum(controller.asiSingleAbility)) ...[
              const SizedBox(height: 6),
              Text(
                'Note: ${controller.asiSingleAbility.name.toUpperCase()} will cap at ${controller.character.getAbilityScoreMaximum(controller.asiSingleAbility)} (Score is currently ${controller.character.rawAbilityScores.getScore(controller.asiSingleAbility)}).',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    isExpanded: true,
                    initialValue: controller.asiDualAbility1,
                    decoration: const InputDecoration(
                        labelText: '+1 Score 1', border: OutlineInputBorder()),
                    items: AbilityType.values.map((a) {
                      final cur = controller.character.rawAbilityScores.getScore(a);
                      final max = controller.character.getAbilityScoreMaximum(a);
                      return DropdownMenuItem(
                        value: a,
                        child: Text('${a.name.toUpperCase()} ($cur/$max)'),
                      );
                    }).toList(),
                    onChanged: (v) => controller.mutate(() => controller.asiDualAbility1 = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AbilityType>(
                    isExpanded: true,
                    initialValue: controller.asiDualAbility2,
                    decoration: const InputDecoration(
                        labelText: '+1 Score 2', border: OutlineInputBorder()),
                    items: AbilityType.values.map((a) {
                      final cur = controller.character.rawAbilityScores.getScore(a);
                      final max = controller.character.getAbilityScoreMaximum(a);
                      return DropdownMenuItem(
                        value: a,
                        child: Text('${a.name.toUpperCase()} ($cur/$max)'),
                      );
                    }).toList(),
                    onChanged: (v) => controller.mutate(() => controller.asiDualAbility2 = v!),
                  ),
                ),
              ],
            ),
            if (controller.asiDualAbility1 == controller.asiDualAbility2) ...[
              const SizedBox(height: 6),
              const Text(
                'Rules require selecting two different ability scores for +1 / +1 improvement.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ] else ...[
          // Search Bar
          TextField(
            decoration: InputDecoration(
              labelText: 'Search Feats',
              hintText: 'Filter by feat name, category, prerequisite...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.featSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => controller.mutate(() => controller.featSearchQuery = ''),
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => controller.mutate(() {
              controller.featSearchQuery = v.trim();
              final matches = controller.availableFeats.where((f) {
                if (controller.featSearchQuery.isEmpty) return true;
                final q = controller.featSearchQuery.toLowerCase();
                return f.name.toLowerCase().contains(q) ||
                    f.category.toLowerCase().contains(q) ||
                    (f.prerequisite?.toLowerCase().contains(q) ?? false) ||
                    f.descriptionMarkdown.toLowerCase().contains(q);
              }).toList();
              if (matches.isNotEmpty &&
                  !matches.any((f) => f.id.slug == controller.selectedFeatSlug)) {
                controller.applyFeatSelection(matches.first);
              }
            }),
          ),
          const SizedBox(height: 12),
          () {
            final filteredFeats = controller.availableFeats.where((f) {
              if (controller.featSearchQuery.isEmpty) return true;
              final q = controller.featSearchQuery.toLowerCase();
              final nameMatches = f.name.toLowerCase().contains(q);
              final catMatches = f.category.toLowerCase().contains(q);
              final prereqMatches =
                  f.prerequisite?.toLowerCase().contains(q) ?? false;
              final descMatches =
                  f.descriptionMarkdown.toLowerCase().contains(q);
              return nameMatches || catMatches || prereqMatches || descMatches;
            }).toList();

            if (filteredFeats.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No feats found matching "${controller.featSearchQuery}"',
                    style: const TextStyle(
                        color: Colors.white54, fontStyle: FontStyle.italic),
                  ),
                ),
              );
            }

            final currentSelectionInList =
                filteredFeats.any((f) => f.id.slug == controller.selectedFeatSlug);
            final activeFeatSlug = currentSelectionInList
                ? controller.selectedFeatSlug
                : filteredFeats.first.id.slug;

            return DropdownButtonFormField<String>(
              key: ValueKey(
                  'feat_dropdown_${filteredFeats.length}_$activeFeatSlug'),
              isExpanded: true,
              initialValue: activeFeatSlug,
              decoration: InputDecoration(
                labelText: controller.featSearchQuery.isNotEmpty
                    ? 'Select Feat (${filteredFeats.length} matching)'
                    : 'Select Feat',
                border: const OutlineInputBorder(),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: DndGlyph.feat(
                    category: FeatCategory.parse(
                      filteredFeats
                          .firstWhere((f) => f.id.slug == activeFeatSlug,
                              orElse: () => filteredFeats.first)
                          .category,
                    ),
                    featId: activeFeatSlug,
                    displayName: controller.selectedFeatName,
                    size: 24,
                    isDarkMode: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              items: filteredFeats.map((f) {
                final prereq =
                    f.prerequisite != null ? ' (${f.prerequisite})' : '';
                return DropdownMenuItem(
                  value: f.id.slug,
                  child: Row(
                    children: [
                      DndGlyph.feat(
                        category: FeatCategory.parse(f.category),
                        featId: f.id.slug,
                        displayName: f.name,
                        size: 20,
                        isDarkMode: theme.brightness == Brightness.dark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${f.name}$prereq',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  final match = filteredFeats.firstWhere(
                    (f) => f.id.slug == v,
                    orElse: () => filteredFeats.first,
                  );
                  controller.applyFeatSelection(match);
                }
              },
            );
          }(),
          () {
            final feat = controller.availableFeats.firstWhere(
              (f) => f.id.slug == controller.selectedFeatSlug,
              orElse: () => controller.availableFeats.first,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feat.hasAbilityScoreIncrease) ...[
                  const SizedBox(height: 16),
                  if (feat.requiresAbilityChoice) ...[
                    Text(
                      'Choose Ability Score to Increase (+${feat.statIncreaseAmount}):',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: feat.selectableAbilities.map((ability) {
                        final isSelected = (controller.selectedFeatAbility ??
                                feat.selectableAbilities.first) ==
                            ability;
                        return ChoiceChip(
                          key: Key('feat_ability_chip_${ability.name}'),
                          label: Text(
                              '${ability.shortName} (+${feat.statIncreaseAmount})'),
                          selected: isSelected,
                          selectedColor:
                              Colors.purpleAccent.withValues(alpha: 0.3),
                          onSelected: (sel) {
                            if (sel) {
                              HapticService.selectionTick(context);
                              controller.mutate(() => controller.selectedFeatAbility = ability);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    Chip(
                      avatar: const Icon(Icons.arrow_upward,
                          size: 16, color: Colors.greenAccent),
                      label: Text(
                          '+${feat.statIncreaseAmount} ${feat.selectableAbilities.first.shortName} (Included)'),
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                    ),
                  ],
                  if (feat.grantsSavingThrowProficiency) ...[
                    const SizedBox(height: 10),
                    () {
                      final chosenSave = controller.selectedFeatAbility ??
                          feat.selectableAbilities.first;
                      final alreadyProficient = controller
                          .character.savingThrowProficiencies
                          .contains(chosenSave);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: alreadyProficient
                              ? Colors.amber.shade900.withValues(alpha: 0.2)
                              : Colors.blue.shade900.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: alreadyProficient
                                ? Colors.amberAccent
                                : Colors.blueAccent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              alreadyProficient
                                  ? Icons.warning_amber_rounded
                                  : Icons.shield,
                              color: alreadyProficient
                                  ? Colors.amberAccent
                                  : Colors.cyanAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                alreadyProficient
                                    ? 'Already proficient in ${chosenSave.shortName} saving throws.'
                                    : 'Grants Proficiency: ${chosenSave.shortName} Saving Throws',
                                style: TextStyle(
                                  color: alreadyProficient
                                      ? Colors.amberAccent
                                      : Colors.cyanAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ],
                ],
                if (feat.hasSkillProficiencyChoice) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Skill Proficiency:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<SkillType>(
                    key: ValueKey(
                        'levelup_feat_skill_${controller.selectedFeatSkill}_${controller.selectedFeatSlug}'),
                    initialValue: controller.selectedFeatSkill ??
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
                        final oldSkill = controller.selectedFeatSkill;
                        controller.mutate(() {
                          controller.selectedFeatSkill = s;
                          if (feat.hasExpertiseChoice) {
                            final eligible = <SkillType>{
                              ...controller.character.skillProficiencies.entries
                                  .where((e) =>
                                      e.value != SkillProficiencyLevel.none)
                                  .map((e) => e.key),
                              s,
                            };
                            if (controller.selectedFeatExpertise == null ||
                                controller.selectedFeatExpertise == oldSkill ||
                                !eligible.contains(controller.selectedFeatExpertise)) {
                              controller.selectedFeatExpertise = s;
                            }
                          }
                        });
                      }
                    },
                  ),
                ],
                if (feat.hasExpertiseChoice) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Choose Skill for Expertise (Double Proficiency):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  () {
                    final eligible = <SkillType>{
                      ...controller.character.skillProficiencies.entries
                          .where((e) => e.value != SkillProficiencyLevel.none)
                          .map((e) => e.key),
                      ?controller.selectedFeatSkill,
                    };
                    if (eligible.isEmpty) eligible.addAll(SkillType.values);
                    final effectiveVal =
                        eligible.contains(controller.selectedFeatExpertise)
                            ? controller.selectedFeatExpertise
                            : (controller.selectedFeatSkill != null &&
                                    eligible.contains(controller.selectedFeatSkill)
                                ? controller.selectedFeatSkill
                                : eligible.first);

                    return DropdownButtonFormField<SkillType>(
                      key: ValueKey(
                          'levelup_feat_expertise_${effectiveVal}_${controller.selectedFeatSkill}'),
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
                                  s == controller.selectedFeatSkill
                                      ? '${s.displayName} (From this Feat)'
                                      : s.displayName,
                                ),
                              ))
                          .toList(),
                      onChanged: (s) {
                        if (s != null) {
                          controller.mutate(() => controller.selectedFeatExpertise = s);
                        }
                      },
                    );
                  }(),
                ],
                if (feat.hasInvocationChoice) ...[
                  const SizedBox(height: 12),
                  () {
                    final isWarlock = controller.character.progression.classes.any(
                            (c) =>
                                c.classRef.slug.toLowerCase() == 'warlock') ||
                        controller.selectedClassSlug.toLowerCase() == 'warlock';
                    final eligible = controller.getEligibleInvocations(feat);
                    final effectiveVal =
                        eligible.any((o) => o.id == controller.selectedFeatOption)
                            ? controller.selectedFeatOption
                            : (eligible.isNotEmpty ? eligible.first.id : null);
                    final selectedOpt =
                        eligible.where((o) => o.id == effectiveVal).firstOrNull;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Eldritch Invocation:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.purpleAccent),
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
                          key: const Key('levelup_feat_invocation_dropdown'),
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
                              controller.mutate(() => controller.selectedFeatOption = optId);
                            }
                          },
                        ),
                        if (selectedOpt != null &&
                            selectedOpt.descriptionMarkdown.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  Colors.purple.shade900.withValues(alpha: 0.2),
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
                ],
                if (feat.hasFightingStyleChoice) ...[
                  const SizedBox(height: 12),
                  () {
                    final alreadySelected =
                        controller.getAllAlreadySelectedFeatureOptionIds();
                    final eligibleStyles =
                        SrdFeatureOptions.fightingStyles.where((s) {
                      final sId = s.id.toLowerCase().trim();
                      final sName = s.name.toLowerCase().trim();
                      return !alreadySelected.contains(sId) &&
                          !alreadySelected.contains(sName);
                    }).toList();
                    final styles = eligibleStyles.isNotEmpty
                        ? eligibleStyles
                        : SrdFeatureOptions.fightingStyles;
                    final effectiveVal =
                        styles.any((o) => o.id == controller.selectedFeatOption)
                            ? controller.selectedFeatOption
                            : (styles.isNotEmpty ? styles.first.id : null);
                    final selectedOpt =
                        styles.where((o) => o.id == effectiveVal).firstOrNull;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Fighting Style:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.orangeAccent),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          key:
                              const Key('levelup_feat_fighting_style_dropdown'),
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
                              controller.mutate(() => controller.selectedFeatOption = optId);
                            }
                          },
                        ),
                        if (selectedOpt != null &&
                            selectedOpt.descriptionMarkdown.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  Colors.orange.shade900.withValues(alpha: 0.2),
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
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: FormattedMarkdownText(
                    feat.descriptionMarkdown,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            );
          }(),
        ],
      ],
    );
  }
}
