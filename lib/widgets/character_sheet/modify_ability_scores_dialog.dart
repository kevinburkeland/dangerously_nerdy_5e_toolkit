import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../providers/character_sheet_controller.dart';
import '../../services/haptic_service.dart';

/// Modal dialog allowing players and DMs to adjust ability scores directly
/// on the character sheet, previewing live modifiers and recording reasons in campaign audit logs.
class ModifyAbilityScoresDialog extends StatefulWidget {
  final CharacterSheetController controller;
  final AbilityType? initialFocusedAbility;

  const ModifyAbilityScoresDialog({
    super.key,
    required this.controller,
    this.initialFocusedAbility,
  });

  static Future<void> show(
    BuildContext context, {
    required CharacterSheetController controller,
    AbilityType? initialFocusedAbility,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ModifyAbilityScoresDialog(
        controller: controller,
        initialFocusedAbility: initialFocusedAbility,
      ),
    );
  }

  @override
  State<ModifyAbilityScoresDialog> createState() => _ModifyAbilityScoresDialogState();
}

class _ModifyAbilityScoresDialogState extends State<ModifyAbilityScoresDialog> {
  late Map<AbilityType, int> _scores;
  final TextEditingController _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final base = widget.controller.character.baseScores;
    _scores = {
      AbilityType.strength: base.strength,
      AbilityType.dexterity: base.dexterity,
      AbilityType.constitution: base.constitution,
      AbilityType.intelligence: base.intelligence,
      AbilityType.wisdom: base.wisdom,
      AbilityType.charisma: base.charisma,
    };
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _updateScore(AbilityType ability, int val) {
    final clamped = val.clamp(1, 30);
    if (_scores[ability] != clamped) {
      HapticService.selectionTick(context);
      setState(() {
        _scores[ability] = clamped;
      });
    }
  }

  Future<void> _submit() async {
    HapticService.selectionTick(context);

    final newAbilityScores = AbilityScores(
      strength: _scores[AbilityType.strength]!,
      dexterity: _scores[AbilityType.dexterity]!,
      constitution: _scores[AbilityType.constitution]!,
      intelligence: _scores[AbilityType.intelligence]!,
      wisdom: _scores[AbilityType.wisdom]!,
      charisma: _scores[AbilityType.charisma]!,
    );

    Navigator.of(context).pop();

    await widget.controller.modifyBaseAbilityScores(
      newAbilityScores,
      reason: _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedCampaigns = widget.controller.getLinkedCampaigns();
    final baseScores = widget.controller.character.baseScores;

    final hasChanges = AbilityType.values.any((a) => _scores[a] != baseScores.getScore(a));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.tune, color: Colors.cyanAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modify Ability Scores',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Adjusting base stats for ${widget.controller.character.name}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
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
            ),
            const Divider(height: 1),

            // Campaign Audit Notice
            if (linkedCampaigns.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade900.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Linked to Campaign: ${linkedCampaigns.first.campaignName}. Stat adjustments will be tracked in the campaign audit log.',
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Ability Scores (1–30)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Ability Cards Grid / List
                    ...AbilityType.values.map((ability) {
                      final curBase = baseScores.getScore(ability);
                      final curVal = _scores[ability] ?? curBase;
                      final isFocused = widget.initialFocusedAbility == ability;
                      final mod = ((curVal - 10) / 2).floor();
                      final modStr = mod >= 0 ? '+$mod' : '$mod';
                      final isChanged = curVal != curBase;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? Colors.cyan.shade900.withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChanged
                                ? Colors.cyanAccent
                                : (isFocused
                                    ? Colors.cyanAccent.withValues(alpha: 0.5)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                            width: isChanged ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Ability badge
                            Container(
                              width: 50,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isChanged
                                    ? Colors.cyanAccent.withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  ability.shortName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isChanged ? Colors.cyanAccent : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Modifier preview pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: mod >= 0
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                modStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: mod >= 0 ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Stepper Controls
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 22),
                              color: curVal > 1 ? Colors.white70 : Colors.white24,
                              onPressed: curVal > 1 ? () => _updateScore(ability, curVal - 1) : null,
                            ),
                            SizedBox(
                              width: 44,
                              child: Center(
                                child: Text(
                                  '$curVal',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 22),
                              color: curVal < 30 ? Colors.white70 : Colors.white24,
                              onPressed: curVal < 30 ? () => _updateScore(ability, curVal + 1) : null,
                            ),

                            if (isChanged) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.undo, size: 18, color: Colors.orangeAccent),
                                tooltip: 'Reset to $curBase',
                                onPressed: () => _updateScore(ability, curBase),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),

                    // Reason / Campaign Log Note Field
                    Text(
                      'Reason / Campaign Log Note (Optional):',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reasonCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Drank Potion of Constitution (+1 Con), Manual DM adjustment, etc.',
                        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: hasChanges ? _submit : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
