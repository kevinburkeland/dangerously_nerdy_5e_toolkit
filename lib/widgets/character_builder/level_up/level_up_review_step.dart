import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_feats_library.dart';
import '../../../models/dm_screen_data.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/spellbook_data.dart';
import '../../../theme/app_theme.dart';
import 'level_up_proficiency_dialogs.dart';
import 'level_up_wizard_controller.dart';

class LevelUpReviewStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;

  const LevelUpReviewStep({
    super.key,
    required this.controller,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStep6Summary(context, Theme.of(context), customColors);
  }

  Widget _buildStep6Summary(BuildContext context, ThemeData theme, TabletopColors? customColors) {
    final candidateRequest = controller.buildRequest();
    final updatedChar = CharacterProgressionEngine.applyLevelUp(
        controller.character, candidateRequest);
    final oldStats = CharacterEvaluationEngine.evaluate(controller.character);
    final newStats = CharacterEvaluationEngine.evaluate(updatedChar);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Level-Up Summary & Diff Preview',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Review changes before applying to your character sheet.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              _buildDiffRow('Total Level', '${controller.character.totalLevel}',
                  '${controller.newTotalLevel}', theme),
              _buildDiffRow(
                  'Class Progression',
                  '${controller.selectedClassSlug} ${controller.targetClassCurrentLevel}',
                  '${controller.selectedClassSlug} ${controller.targetClassNewLevel}',
                  theme),
              _buildDiffRow(
                  'Hit Dice Pool',
                  '${controller.character.resources.currentHitDice[controller.currentHitDie] ?? 0} ${controller.currentHitDie}',
                  '${updatedChar.resources.currentHitDice[controller.currentHitDie] ?? 0} ${controller.currentHitDie}',
                  theme),
              _buildDiffRow(
                  'Maximum HP',
                  '${oldStats.maxHp}',
                  '${newStats.maxHp} (+${newStats.maxHp - oldStats.maxHp})',
                  theme,
                  highlightNew: true),
              _buildDiffRow(
                  'Proficiency Bonus',
                  '+${oldStats.proficiencyBonus}',
                  '+${newStats.proficiencyBonus}',
                  theme),
              if (controller.isAsiEligible && controller.isAsiSelected)
                _buildDiffRow(
                    'ASI Bonus',
                    'None',
                    controller.isAsiPlusTwo
                        ? '+2 ${controller.asiSingleAbility.name}'
                        : '+1 ${controller.asiDualAbility1.name}, +1 ${controller.asiDualAbility2.name}',
                    theme,
                    highlightNew: true),
              if (controller.isAsiEligible && !controller.isAsiSelected) ...[
                _buildDiffRow('Feat Gained', 'None', controller.selectedFeatName, theme,
                    highlightNew: true),
                () {
                  final feat = controller.availableFeats
                          .where((f) => f.id.slug == controller.selectedFeatSlug)
                          .firstOrNull ??
                      SrdFeatsLibrary.findBySlug(controller.selectedFeatSlug);
                  final chosenAbility = controller.selectedFeatAbility ??
                      (feat?.selectableAbilities.isNotEmpty == true
                          ? feat!.selectableAbilities.first
                          : null);
                  if (feat != null &&
                      feat.hasAbilityScoreIncrease &&
                      chosenAbility != null) {
                    return Column(
                      children: [
                        _buildDiffRow(
                            'Feat Ability',
                            'None',
                            '+${feat.statIncreaseAmount} ${chosenAbility.shortName}',
                            theme,
                            highlightNew: true),
                        if (feat.grantsSavingThrowProficiency)
                          _buildDiffRow(
                              'Feat Saving Throw',
                              'None',
                              '${chosenAbility.shortName} Save Proficiency',
                              theme,
                              highlightNew: true),
                        if (feat.hasSkillProficiencyChoice &&
                            controller.selectedFeatSkill != null)
                          _buildDiffRow(
                              'Feat Skill',
                              'None',
                              '${controller.selectedFeatSkill!.displayName} Proficiency',
                              theme,
                              highlightNew: true),
                        if (feat.hasExpertiseChoice &&
                            controller.selectedFeatExpertise != null)
                          _buildDiffRow(
                              'Feat Expertise',
                              'None',
                              '${controller.selectedFeatExpertise!.displayName} Expertise',
                              theme,
                              highlightNew: true),
                      ],
                    );
                  }
                  if (feat != null &&
                      (feat.hasSkillProficiencyChoice ||
                          feat.hasExpertiseChoice)) {
                    return Column(
                      children: [
                        if (feat.hasSkillProficiencyChoice &&
                            controller.selectedFeatSkill != null)
                          _buildDiffRow(
                              'Feat Skill',
                              'None',
                              '${controller.selectedFeatSkill!.displayName} Proficiency',
                              theme,
                              highlightNew: true),
                        if (feat.hasExpertiseChoice &&
                            controller.selectedFeatExpertise != null)
                          _buildDiffRow(
                              'Feat Expertise',
                              'None',
                              '${controller.selectedFeatExpertise!.displayName} Expertise',
                              theme,
                              highlightNew: true),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ],
              if (controller.selectedSubclass != null)
                _buildDiffRow('Subclass', 'None', controller.selectedSubclass!, theme,
                    highlightNew: true),
              if (controller.selectedMysticArcanumSpellId != null)
                () {
                  final spell = SpellbookLibrary.getSpellById(
                      controller.selectedMysticArcanumSpellId!);
                  final name = spell?.getName(
                          controller.character.id.ruleset == RulesetVersion.v2024
                              ? DmRulesEdition.v2024
                              : DmRulesEdition.v2014) ??
                      controller.selectedMysticArcanumSpellId!;
                  return _buildDiffRow('Mystic Arcanum', 'None', name, theme,
                      highlightNew: true);
                }(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Languages & Tools Gained Panel
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: customColors?.cardBorder ??
                    theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Languages & Tool Proficiencies Gained',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => showLevelUpAddLanguageDialog(context, controller),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Language',
                            style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                      TextButton.icon(
                        onPressed: () => showLevelUpAddToolDialog(context, controller),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Tool',
                            style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (controller.newLanguages.isEmpty && controller.newToolProficiencies.isEmpty)
                const Text(
                  'No additional languages or tools gained this level. Tap above to add training or DM awards.',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white54,
                      fontStyle: FontStyle.italic),
                )
              else ...[
                if (controller.newLanguages.isNotEmpty) ...[
                  const Text('New Languages:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyanAccent)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: controller.newLanguages
                        .map((l) => Chip(
                              label:
                                  Text(l, style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 12),
                              onDeleted: () =>
                                  controller.mutate(() => controller.newLanguages.remove(l)),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                ],
                if (controller.newToolProficiencies.isNotEmpty) ...[
                  const Text('New Tools:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: controller.newToolProficiencies
                        .map((t) => Chip(
                              label:
                                  Text(t, style: const TextStyle(fontSize: 11)),
                              deleteIcon: const Icon(Icons.close, size: 12),
                              onDeleted: () => controller.mutate(
                                  () => controller.newToolProficiencies.remove(t)),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiffRow(
      String label, String oldVal, String newVal, ThemeData theme,
      {bool highlightNew = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            oldVal,
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: Colors.white54,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            newVal,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlightNew ? Colors.greenAccent : null,
            ),
          ),
        ],
      ),
    );
  }
}
