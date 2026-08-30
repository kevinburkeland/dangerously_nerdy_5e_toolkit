import 'package:flutter/material.dart';
import '../../models/domain/session_graph_models.dart';
import '../../services/haptic_service.dart';

/// Card rendering an individual combatant participant in the live encounter tracker.
class DmDashboardEncounterCard extends StatelessWidget {
  final EncounterParticipant participant;
  final bool isSelected;
  final VoidCallback? onNextTurn;
  final ValueChanged<int>? onApplyHpDelta;
  final ValueChanged<String>? onToggleCondition;
  final VoidCallback? onRemove;

  const DmDashboardEncounterCard({
    super.key,
    required this.participant,
    this.isSelected = false,
    this.onNextTurn,
    this.onApplyHpDelta,
    this.onToggleCondition,
    this.onRemove,
  });

  Color _getHpColor(BuildContext context) {
    if (participant.isDefeated || participant.currentHp <= 0) {
      return Colors.red.shade900;
    }
    final pct = participant.maxHp > 0 ? (participant.currentHp / participant.maxHp) : 1.0;
    if (pct <= 0.25) return Colors.red;
    if (pct <= 0.5) return Colors.amber.shade700;
    return Colors.green;
  }

  void _showHpDeltaDialog(BuildContext context) {
    HapticService.selectionTick(context);
    final theme = Theme.of(context);
    final deltaController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust HP: ${participant.entityLink.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current: ${participant.currentHp} / ${participant.maxHp}'
              '${participant.tempHp > 0 ? " (+${participant.tempHp} Temp)" : ""}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deltaController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'HP Amount',
                hintText: 'Enter amount...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
                  onPressed: () {
                    final val = int.tryParse(deltaController.text.trim()) ?? 0;
                    if (val > 0 && onApplyHpDelta != null) {
                      onApplyHpDelta!(-val);
                    }
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.remove, color: Colors.white),
                  label: const Text('Damage', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () {
                    final val = int.tryParse(deltaController.text.trim()) ?? 0;
                    if (val > 0 && onApplyHpDelta != null) {
                      onApplyHpDelta!(val);
                    }
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Heal', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTurn = participant.isActiveTurn;
    final isDead = participant.isDefeated || participant.currentHp <= 0;

    final hpPct = participant.maxHp > 0
        ? (participant.currentHp / participant.maxHp).clamp(0.0, 1.0)
        : 1.0;

    return Card(
      elevation: isTurn ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTurn
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : (isDead
                ? BorderSide(color: Colors.red.withAlpha(100), width: 1)
                : BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80))),
      ),
      color: isTurn
          ? theme.colorScheme.primaryContainer.withAlpha(40)
          : (isDead ? Colors.red.withAlpha(20) : theme.colorScheme.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Initiative Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isTurn
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${participant.initiativeScore}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isTurn ? theme.colorScheme.onPrimary : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name & Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant.entityLink.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isDead ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'AC ${participant.armorClass} • ${participant.entityLink.refType.displayName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // HP Button
                InkWell(
                  onTap: () => _showHpDeltaDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getHpColor(context).withAlpha(30),
                      border: Border.all(color: _getHpColor(context)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${participant.currentHp} / ${participant.maxHp}'
                      '${participant.tempHp > 0 ? " (+${participant.tempHp})" : ""}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _getHpColor(context),
                      ),
                    ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove Combatant',
                    onPressed: onRemove,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // HP Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: hpPct,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_getHpColor(context)),
                minHeight: 6,
              ),
            ),
            if (participant.activeConditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: participant.activeConditions.map((cond) {
                  return Chip(
                    label: Text(cond, style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: onToggleCondition != null
                        ? () => onToggleCondition!(cond)
                        : null,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
