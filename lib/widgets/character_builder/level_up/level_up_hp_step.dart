import 'package:material_ui/material_ui.dart';
import '../../../presentation/visual/visual_ui.dart';
import '../../../theme/app_theme.dart';
import '../../glyphs/dnd_glyph.dart';
import 'level_up_wizard_controller.dart';

class LevelUpHpStep extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;
  final VoidCallback onRollHitPoints;

  const LevelUpHpStep({
    super.key,
    required this.controller,
    required this.customColors,
    required this.onRollHitPoints,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStep2HpIncrease(Theme.of(context), customColors);
  }

  Widget _buildStep2HpIncrease(ThemeData theme, TabletopColors? customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hit Points & Hit Die Scaling',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Gain a new ${controller.currentHitDie} Hit Die and increase your character\'s maximum Hit Points.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // Fixed Average vs Die Roll Toggle
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.balance),
              label: Text('Fixed Average (${controller.fixedAverageHp})'),
            ),
            ButtonSegment(
              value: false,
              icon: DndGlyph.genericUi(
                uiType: GenericUiGlyphType.fromDie(controller.currentHitDie) ??
                    GenericUiGlyphType.d20,
                size: 16,
                isDarkMode: theme.brightness == Brightness.dark,
              ),
              label: const Text('Interactive Roll'),
            ),
          ],
          selected: {controller.useFixedAverage},
          onSelectionChanged: (val) {
            controller.mutate(() => controller.useFixedAverage = val.first);
          },
        ),
        const SizedBox(height: 20),

        if (!controller.useFixedAverage) ...[
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DndGlyph.genericUi(
                      uiType: GenericUiGlyphType.fromDie(controller.currentHitDie) ??
                          GenericUiGlyphType.d20,
                      size: 24,
                      isDarkMode: theme.brightness == Brightness.dark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Roll ${controller.currentHitDie}:',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: controller.isRolling
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                '${controller.rolledHp}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: controller.isRolling ? null : onRollHitPoints,
                  icon: const Icon(Icons.replay),
                  label: const Text('Roll Hit Die'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Breakdown card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HP Gain Breakdown:',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text(
                          'Hit Die Base (${controller.useFixedAverage ? "Average" : "Rolled"}):')),
                  Text('+${controller.useFixedAverage ? controller.fixedAverageHp : controller.rolledHp}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(child: Text('Constitution Modifier:')),
                  Text(controller.conModifier >= 0 ? "+${controller.conModifier}" : "${controller.conModifier}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  const Expanded(
                      child: Text('Total HP Gain this Level:',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  Text(
                    '+${controller.effectiveHpGain} HP',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: customColors?.hitGreen ?? Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
