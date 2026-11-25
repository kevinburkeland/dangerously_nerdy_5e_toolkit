import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_classes_library.dart';
import '../../../models/domain/character_models.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import 'level_up_wizard_controller.dart';

class LevelUpSubclassStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;

  const LevelUpSubclassStep({
    super.key,
    required this.controller,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStep3SubclassAndFeatures(context, Theme.of(context), customColors);
  }

  Widget _buildStep3SubclassAndFeatures(
      BuildContext context, ThemeData theme, TabletopColors? customColors) {
    final customCls = SrdClassesLibrary.findBySlug(controller.selectedClassSlug,
        ruleset: controller.character.id.ruleset);
    final List<Map<String, String>> availableSubs = [];
    if (customCls != null && customCls.subclasses.isNotEmpty) {
      for (final s in customCls.subclasses) {
        availableSubs.add({
          'slug': s.id.slug,
          'name': s.name,
          'desc': s.featuresMarkdown
              .split('\n')
              .firstWhere((l) => l.trim().isNotEmpty, orElse: () => s.name),
        });
      }
    }
    final needsSubclass = controller.isSubclassMilestone && availableSubs.isNotEmpty;
    final decisions = customCls?.getDecisionsForLevel(controller.targetClassNewLevel,
            ruleset: controller.character.id.ruleset) ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Features & Specializations',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlocking features and choices for ${controller.selectedClassSlug} Level ${controller.targetClassNewLevel}.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        if (needsSubclass) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (customColors?.critGold ?? Colors.amber)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: (customColors?.critGold ?? Colors.amber)
                      .withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium,
                        color: customColors?.critGold ?? Colors.amber),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Subclass Archetype Milestone Unlocked!',
                            style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Choose your Subclass archetype specialization:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: controller.selectedSubclass,
                  decoration: const InputDecoration(
                    labelText: 'Select Subclass',
                    border: OutlineInputBorder(),
                  ),
                  items: availableSubs.map((sub) {
                    return DropdownMenuItem(
                      value: sub['slug'],
                      child: Text('${sub['name']} — ${sub['desc']}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    controller.mutate(() {
                      controller.selectedSubclass = v;
                      final sub = v?.toLowerCase() ?? '';
                      if (sub.contains('assassin')) {
                        controller.newToolProficiencies.add('Disguise Kit');
                        controller.newToolProficiencies.add('Poisoner\'s Kit');
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Feature Decisions (e.g. Eldritch Invocations, Fighting Style, Divine Order, etc.)
        if (decisions.isNotEmpty) ...[
          ...decisions.map((decision) {
            final selected = controller.selectedFeatureOptions[decision.id] ??= [];

            final alreadySelected = controller.getAllAlreadySelectedFeatureOptionIds(
                excludeDecisionId: decision.id);
            final eligibleOptions = decision.availableOptions.where((opt) {
              if (selected.contains(opt.id)) return true;
              if (controller.isOptionRepeatable(opt)) return true;
              final optId = opt.id.toLowerCase().trim();
              final optName = opt.name.toLowerCase().trim();
              if (alreadySelected.contains(optId) ||
                  alreadySelected.contains(optName)) {
                return false;
              }
              return true;
            }).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.cyan.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade800,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          decision.type.displayName,
                          style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          decision.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${decision.prompt} (Selected: ${selected.length} / ${decision.maxSelections})',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: eligibleOptions.map((opt) {
                      final isSelected = selected.contains(opt.id);
                      final eval = opt.prerequisite.evaluate(
                        classLevel: controller.targetClassNewLevel,
                        selectedPacts: controller.getAllSelectedPacts(),
                        knownSpellSlugs: controller.getAllKnownSpellSlugs(),
                      );
                      final isGated = !eval.isMet && !isSelected;

                      return Tooltip(
                        message: isGated
                            ? 'Locked: ${eval.summary}'
                            : (opt.descriptionMarkdown.isNotEmpty
                                ? opt.descriptionMarkdown
                                : opt.name),
                        child: FilterChip(
                          selected: isSelected,
                          selectedColor:
                              Colors.cyanAccent.withValues(alpha: 0.35),
                          disabledColor: Colors.white10,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isGated) ...[
                                const Icon(Icons.lock_outline,
                                    size: 12, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                opt.name,
                                style: TextStyle(
                                  color:
                                      isGated ? Colors.white38 : Colors.white,
                                ),
                              ),
                            ],
                          ),
                          avatar: Icon(
                            isSelected
                                ? Icons.check_circle
                                : (isGated
                                    ? Icons.lock
                                    : Icons.circle_outlined),
                            size: 14,
                            color: isSelected
                                ? Colors.cyanAccent
                                : (isGated
                                    ? Colors.orangeAccent.withValues(alpha: 0.6)
                                    : Colors.white54),
                          ),
                          onSelected: (bool chosen) {
                            if (isGated && chosen) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Cannot select ${opt.name}: ${eval.summary}'),
                                  backgroundColor: Colors.red.shade900,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                              return;
                            }
                            HapticService.selectionTick(context);
                            controller.mutate(() {
                              final list = List<String>.from(
                                  controller.selectedFeatureOptions[decision.id] ?? []);
                              if (chosen) {
                                if (decision.maxSelections == 1) {
                                  list.clear();
                                  list.add(opt.id);
                                } else {
                                  if (list.length >= decision.maxSelections) {
                                    list.removeAt(0);
                                  }
                                  list.add(opt.id);
                                }
                              } else {
                                list.remove(opt.id);
                              }
                              controller.selectedFeatureOptions[decision.id] = list;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],

        // General features overview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gains at Level ${controller.targetClassNewLevel}:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• Hit Die Pool: +1 ${controller.currentHitDie}'),
              Text(
                  '• Proficiency Bonus: +${controller.newTotalLevel.dndProficiencyBonus}'),
              if (controller.isAsiEligible)
                const Text('• Ability Score Improvement / Feat Eligible'),
              if (needsSubclass && controller.selectedSubclass != null)
                Text('• Specialization: ${controller.selectedSubclass}'),
              if (controller.selectedFeatureOptions.isNotEmpty)
                Text(
                    '• Chosen Specializations: ${controller.selectedFeatureOptions.values.expand((v) => v).join(', ')}'),
            ],
          ),
        ),
      ],
    );
  }
}
