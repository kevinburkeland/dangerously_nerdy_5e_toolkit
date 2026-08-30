import 'package:flutter/material.dart';
import '../../models/animated_object.dart';

/// HUD widget rendering active animated objects and summoned minions in the campaign session.
class DmDashboardMinionHud extends StatelessWidget {
  final List<AnimatedObjectInstance> activeMinions;
  final ValueChanged<String>? onRemoveMinion;
  final VoidCallback? onAddMinion;

  const DmDashboardMinionHud({
    super.key,
    required this.activeMinions,
    this.onRemoveMinion,
    this.onAddMinion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (activeMinions.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.pets_outlined, size: 36, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'No Active Summons or Minions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Active Animate Objects or SRD summons will appear here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (onAddMinion != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onAddMinion,
                  icon: const Icon(Icons.add),
                  label: const Text('Manage Minions'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeMinions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final minion = activeMinions[index];
        final isDead = minion.currentHp <= 0;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  color: isDead ? Colors.red : theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        minion.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isDead ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        'AC ${minion.customAc ?? minion.size.ac} • ${minion.currentHp}/${minion.maxHp} HP',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDead ? Colors.red : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemoveMinion != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Dismiss Minion',
                    onPressed: () => onRemoveMinion!(minion.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
