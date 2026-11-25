import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../theme/app_theme.dart';
import '../../glyphs/dnd_glyph.dart';
import 'level_up_wizard_controller.dart';

const List<String> _mutatedClassSlugs = ['fighter', 'wizard', 'rogue'];

class LevelUpClassStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;
  final LevelUpValidationResult validation;

  const LevelUpClassStep({
    super.key,
    required this.controller,
    required this.customColors,
    required this.validation,
  });

  @override
  Widget build(BuildContext context) {
    assert(_mutatedClassSlugs.isNotEmpty);
    return _buildStep1ClassSelection(Theme.of(context), customColors, validation);
  }

  Widget _buildStep1ClassSelection(ThemeData theme,
      TabletopColors? customColors, LevelUpValidationResult validation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose Target Class to Advance',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Advance your primary class or multiclass into a new archetype according to 5e prerequisites.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Class Cards Grid / Dropdown
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: controller.selectedClassSlug,
          decoration: InputDecoration(
            labelText: 'Class to Level Up',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(10.0),
              child: DndGlyph.classFeature(
                classType: DndClassType.tryParse(controller.selectedClassSlug) ??
                    DndClassType.fighter,
                size: 24,
                isDarkMode: theme.brightness == Brightness.dark,
              ),
            ),
          ),
          items: controller.availableClasses.map((cls) {
            final slug = cls.id.slug;
            final isCurrent = controller.character.progression.classes
                .any((c) => c.classRef.slug.toLowerCase() == slug.toLowerCase());
            final prereq = LevelUpWizardController.formatMulticlassPrerequisite(slug);
            final label =
                '${cls.name} (${cls.hitDie}) ${isCurrent ? "— Current" : "— Multiclass (Req: $prereq)"}';
            final classType =
                DndClassType.tryParse(slug) ?? DndClassType.fighter;
            return DropdownMenuItem(
              value: slug,
              child: Row(
                children: [
                  DndGlyph.classFeature(
                    classType: classType,
                    size: 20,
                    isDarkMode: theme.brightness == Brightness.dark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontWeight: isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              controller.mutate(() {
                controller.selectedClassSlug = val;
                controller.isMulticlass = !controller.character.progression.classes
                    .any((c) => c.classRef.slug.toLowerCase() == val);
                controller.rolledHp = controller.fixedAverageHp;
                controller.selectedSubclass = null;
                controller.newCantrips.clear();
                controller.newSpells.clear();
                controller.selectedMysticArcanumSpellId = null;
              });
            }
          },
        ),
        const SizedBox(height: 16),

        // Validation alert if multiclass requirements are not met
        if (!validation.isValid)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    validation.errors.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (customColors?.hitGreen ?? Colors.green)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (customColors?.hitGreen ?? Colors.green)
                      .withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline,
                    color: customColors?.hitGreen ?? Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prerequisites Satisfied: Ready to advance ${controller.selectedClassSlug} to Level ${controller.targetClassNewLevel}!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: customColors?.hitGreen ?? Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
