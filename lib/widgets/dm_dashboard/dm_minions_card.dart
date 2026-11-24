import 'package:material_ui/material_ui.dart';

import '../../models/animated_object.dart';
import '../../providers/dm_dashboard_controller.dart';
import '../../theme/domain_ui_extensions.dart';

/// Animated objects and active minions card for the DM Dashboard.
class DmMinionsCard extends StatelessWidget {
  final DmDashboardController controller;
  final VoidCallback onAddMinion;
  final void Function(String minionId, int delta) onModifyMinionHp;

  const DmMinionsCard({
    super.key,
    required this.controller,
    required this.onAddMinion,
    required this.onModifyMinionHp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minions = controller.activeMinions;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pets,
                    color: Colors.deepOrangeAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Minion & Summon Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, size: 20),
                  tooltip: 'Summon Minion / Object',
                  onPressed: onAddMinion,
                ),
              ],
            ),
            const Divider(height: 20),
            if (minions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Animate Object / Minion'),
                    onPressed: onAddMinion,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: minions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final m = minions[i];
                  return _buildMinionTile(context, m);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinionTile(BuildContext context, AnimatedObjectInstance m) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: m.accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: m.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              m.size.displayName,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: m.accentColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  'AC ${m.ac} • Dmg: ${m.damageFormula}',
                  style: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: Colors.redAccent),
            onPressed: () => onModifyMinionHp(m.id, -5),
          ),
          Text(
            '${m.currentHp}/${m.maxHp}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: Colors.greenAccent),
            onPressed: () => onModifyMinionHp(m.id, 5),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => controller.removeMinion(m.id),
          ),
        ],
      ),
    );
  }


}
