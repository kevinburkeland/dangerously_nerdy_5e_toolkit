import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../services/haptic_service.dart';
import '../../../theme/app_theme.dart';
import 'level_up_wizard_controller.dart';

class LevelUpDialogHeader extends StatelessWidget {
  final LevelUpWizardController controller;
  final TabletopColors? customColors;

  const LevelUpDialogHeader({
    super.key,
    required this.controller,
    required this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    return _buildDialogHeader(context, Theme.of(context), customColors);
  }

  Widget _buildDialogHeader(BuildContext context, ThemeData theme, TabletopColors? customColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (customColors?.critGold ?? Colors.amber)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: customColors?.critGold ?? Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level Up Hero: ${controller.character.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Advancing to Character Level ${controller.newTotalLevel}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Step progress indicator bar
          Row(
            children: List.generate(6, (index) {
              final isPassed = index < controller.currentStep;
              final isCurrent = index == controller.currentStep;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? (customColors?.hitGreen ?? Colors.green)
                        : (isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            _getStepTitle(controller.currentStep),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1 of 6: Choose Class';
      case 1:
        return 'Step 2 of 6: Hit Points & Hit Die Scaling';
      case 2:
        return 'Step 3 of 6: Class Features & Subclass Archetype';
      case 3:
        return 'Step 4 of 6: Ability Score Improvement or Feat';
      case 4:
        return 'Step 5 of 6: Spells & Invocations Management';
      case 5:
        return 'Step 6 of 6: Review & Final Confirmation';
      default:
        return '';
    }
  }
}

class LevelUpDialogBottomBar extends StatelessWidget {
  final LevelUpWizardController controller;
  final LevelUpValidationResult validation;
  final VoidCallback onConfirmLevelUp;

  const LevelUpDialogBottomBar({
    super.key,
    required this.controller,
    required this.validation,
    required this.onConfirmLevelUp,
  });

  @override
  Widget build(BuildContext context) {
    return _buildBottomBar(context, Theme.of(context), validation);
  }

  Widget _buildBottomBar(
      BuildContext context, ThemeData theme, LevelUpValidationResult validation) {
    final isLastStep = controller.currentStep == 5;
    final isAsiInvalid = controller.currentStep == 3 &&
        controller.isAsiEligible &&
        controller.isAsiSelected &&
        !controller.isAsiPlusTwo &&
        controller.asiDualAbility1 == controller.asiDualAbility2;
    final canAdvance = validation.isValid && !isAsiInvalid;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (controller.currentStep > 0)
            OutlinedButton.icon(
              onPressed: () {
                HapticService.selectionTick(context);
                controller.mutate(() => controller.currentStep--);
              },
              icon: const Icon(Icons.chevron_left),
              label: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          if (!isLastStep)
            FilledButton.icon(
              onPressed: canAdvance
                  ? () {
                      HapticService.selectionTick(context);
                      controller.mutate(() => controller.currentStep++);
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: const Text('Next Step'),
            )
          else
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: canAdvance ? onConfirmLevelUp : null,
              icon: const Icon(Icons.check),
              label: const Text('CONFIRM LEVEL UP',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
