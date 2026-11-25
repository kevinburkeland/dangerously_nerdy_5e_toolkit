import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../models/domain/character_models.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import 'level_up/level_up_asi_feat_step.dart';
import 'level_up/level_up_class_step.dart';
import 'level_up/level_up_dialog_header.dart';
import 'level_up/level_up_hp_step.dart';
import 'level_up/level_up_review_step.dart';
import 'level_up/level_up_spells_step.dart';
import 'level_up/level_up_subclass_step.dart';
import 'level_up/level_up_wizard_controller.dart';

/// Interactive, 6-step multi-step modal wizard for 5e Character Level Advancement.
class LevelUpWizardDialog extends StatefulWidget {
  final Character character;
  final ValueChanged<Character>? onLevelUpApplied;

  const LevelUpWizardDialog({
    super.key,
    required this.character,
    this.onLevelUpApplied,
  });

  static Future<Character?> show(
    BuildContext context, {
    required Character character,
    ValueChanged<Character>? onLevelUpApplied,
  }) {
    return showDialog<Character>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelUpWizardDialog(
        character: character,
        onLevelUpApplied: onLevelUpApplied,
      ),
    );
  }

  @override
  State<LevelUpWizardDialog> createState() => _LevelUpWizardDialogState();
}

class _LevelUpWizardDialogState extends State<LevelUpWizardDialog>
    with SingleTickerProviderStateMixin {
  late final LevelUpWizardController _controller;
  late final AnimationController _diceAnimController;

  @override
  void initState() {
    super.initState();
    _controller = LevelUpWizardController(character: widget.character);
    _diceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _rollHitPoints() {
    _controller.mutate(() => _controller.isRolling = true);
    _diceAnimController.forward(from: 0.0).then((_) {
      final random = math.Random();
      final roll = random.nextInt(_controller.hitDieSides) + 1;
      if (mounted) {
        _controller.mutate(() {
          _controller.rolledHp = roll;
          _controller.isRolling = false;
        });
        HapticService.selectionTick(context);
      }
    });
  }

  void _onConfirmLevelUp() {
    final request = _controller.buildRequest();
    final updated =
        CharacterProgressionEngine.applyLevelUp(widget.character, request);
    HapticService.selectionTick(context);
    widget.onLevelUpApplied?.call(updated);
    if (mounted) {
      Navigator.of(context).pop(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>();

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final validation = CharacterProgressionEngine.validateMulticlass(
            widget.character, _controller.selectedClassSlug);

        return Dialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color:
                  customColors?.cardBorder ?? theme.colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Container(
            width: 680,
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: math.min(740, MediaQuery.sizeOf(context).height * 0.9),
            ),
            child: Column(
              children: [
                LevelUpDialogHeader(
                  controller: _controller,
                  customColors: customColors,
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildCurrentStepContent(customColors, validation),
                  ),
                ),
                const Divider(height: 1),
                LevelUpDialogBottomBar(
                  controller: _controller,
                  validation: validation,
                  onConfirmLevelUp: _onConfirmLevelUp,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStepContent(
      TabletopColors? customColors, LevelUpValidationResult validation) {
    switch (_controller.currentStep) {
      case 0:
        return LevelUpClassStep(
          controller: _controller,
          customColors: customColors,
          validation: validation,
        );
      case 1:
        return LevelUpHpStep(
          controller: _controller,
          customColors: customColors,
          onRollHitPoints: _rollHitPoints,
        );
      case 2:
        return LevelUpSubclassStep(
          controller: _controller,
          customColors: customColors,
        );
      case 3:
        return LevelUpAsiFeatStep(
          controller: _controller,
          customColors: customColors,
        );
      case 4:
        return LevelUpSpellsStep(
          controller: _controller,
          customColors: customColors,
        );
      case 5:
        return LevelUpReviewStep(
          controller: _controller,
          customColors: customColors,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
