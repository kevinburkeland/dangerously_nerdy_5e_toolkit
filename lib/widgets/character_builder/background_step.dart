import 'package:flutter/material.dart';
import '../../models/characters/srd_backgrounds_library.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/character_builder_controller.dart';
import '../../services/haptic_service.dart';

/// Step 4: Choose Background Origin widget with reactive 5e RAW Skill Overlap Refund Engine.
class BackgroundStep extends StatelessWidget {
  final CharacterBuilderController controller;
  final String selectedBackground;
  final ValueChanged<String> onBackgroundSelected;
  final RulesetVersion selectedRuleset;
  final List<Background>? customBackgrounds;

  const BackgroundStep({
    super.key,
    required this.controller,
    required this.selectedBackground,
    required this.onBackgroundSelected,
    required this.selectedRuleset,
    this.customBackgrounds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final is2024 = selectedRuleset == RulesetVersion.v2024;
    final backgrounds = customBackgrounds ?? SrdBackgroundsLibrary.allBackgrounds;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              is2024 ? 'Step 4: Choose Background Origin' : 'Step 4: Choose Background',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              is2024
                  ? 'Your background grants starting skills, tool proficiencies, and an Origin Feat.'
                  : 'Your background grants starting skills, tool proficiencies, and starting equipment.',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 12),

            // REACTIVE SKILL OVERLAP REFUND BLOCK
            SkillRefundAlertSection(controller: controller),

            // BACKGROUND LIST
            ...backgrounds.map((bg) {
              final isSelected = selectedBackground == bg.id.slug;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.cyan.shade900.withValues(alpha: 0.3) : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.cyanAccent : Colors.white12,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Colors.cyanAccent : Colors.white54,
                    ),
                    title: Text(bg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      is2024
                          ? 'Skills: ${bg.skillProficiencies.join(", ")}\nOrigin Feat: ${bg.originFeat ?? "General"}'
                          : 'Skills: ${bg.skillProficiencies.join(", ")}${bg.toolProficiencies.isNotEmpty ? "\nTools: ${bg.toolProficiencies.join(', ')}" : ""}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                    ),
                    onTap: () {
                      HapticService.selectionTick(context);
                      onBackgroundSelected(bg.id.slug);
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Standalone, reactive Skill Overlap & Refund Alert Widget that can be embedded
/// into any step (Background, Species, etc.) where skill collisions occur.
class SkillRefundAlertSection extends StatelessWidget {
  final CharacterBuilderController controller;

  const SkillRefundAlertSection({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final refundCount = controller.refundedSkillChoices;
        final bonusSkills = controller.bonusReplacementSkills;
        final availableSkills = controller.availableReplacementSkills;
        final collidingSkills = controller.collidingSkills;

        if (refundCount == 0 && bonusSkills.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: refundCount > 0
                ? Colors.amber.shade900.withValues(alpha: 0.25)
                : Colors.green.shade900.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: refundCount > 0 ? Colors.amberAccent : Colors.greenAccent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    refundCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                    color: refundCount > 0 ? Colors.amberAccent : Colors.greenAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          refundCount > 0
                              ? 'Skill Proficiency Overlap Detected! Please select $refundCount replacement skill(s).'
                              : 'All skill overlap replacements resolved!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: refundCount > 0 ? Colors.amberAccent : Colors.greenAccent,
                          ),
                        ),
                        if (collidingSkills.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Colliding skill(s): ${collidingSkills.map((s) => s.displayName).join(", ")}. '
                            'Under 5e RAW rules, gaining duplicate skill proficiencies grants replacement skill choices.',
                            style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // CHOSEN REPLACEMENTS
              if (bonusSkills.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  'Replacement Skill(s) Selected:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: bonusSkills.map((sk) {
                    return InputChip(
                      label: Text(sk.displayName),
                      selected: true,
                      selectedColor: Colors.greenAccent.withValues(alpha: 0.25),
                      labelStyle: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onDeleted: () {
                        HapticService.selectionTick(context);
                        controller.unresolveRefundedSkill(sk);
                      },
                    );
                  }).toList(),
                ),
              ],

              // REPLACEMENT SELECTION CHIPS
              if (refundCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'Select $refundCount replacement skill(s) from eligible proficiencies:',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: availableSkills.map((sk) {
                    return ActionChip(
                      label: Text(sk.displayName),
                      avatar: const Icon(Icons.add, size: 16, color: Colors.amberAccent),
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Colors.white24),
                      labelStyle: const TextStyle(color: Colors.white),
                      onPressed: () {
                        HapticService.selectionTick(context);
                        controller.resolveRefundedSkill(sk);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
