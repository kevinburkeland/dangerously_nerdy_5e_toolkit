import 'package:flutter/material.dart';
import '../../models/spell_session.dart';
import '../../theme/app_theme.dart';
import '../meters/animated_resource_meter.dart';

class ActiveSessionHeader extends StatelessWidget {
  final SpellSession session;
  final VoidCallback onBatchAttack;
  final VoidCallback onOpenSquadBuilder;
  final VoidCallback onHealAll;
  final VoidCallback onShowMassDamageDialog;
  final VoidCallback onClearSquad;
  final VoidCallback? onRollInitiative;
  final VoidCallback? onGrantGroupTempHp;

  const ActiveSessionHeader({
    super.key,
    required this.session,
    required this.onBatchAttack,
    required this.onOpenSquadBuilder,
    required this.onHealAll,
    required this.onShowMassDamageDialog,
    required this.onClearSquad,
    this.onRollInitiative,
    this.onGrantGroupTempHp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>();
    final used = session.usedPoints;
    final maxPts = session.maxPoints;
    final isOverBudget = used > maxPts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          AnimatedResourceMeter(
            currentValue: used,
            maxValue: maxPts,
            label: 'Point Budget: $used / $maxPts points used',
            fillColor: isOverBudget
                ? (tabletop?.fumbleRed ?? Colors.redAccent)
                : theme.colorScheme.primary,
            height: 8,
            trailing: Text(
              '${session.activeObjects.length} Objects',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: onBatchAttack,
                  icon: const Icon(Icons.flash_on, size: 20),
                  label: const Text(
                    'BATCH ATTACK',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (onRollInitiative != null)
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    foregroundColor: Colors.amber,
                  ),
                  icon: const Icon(Icons.casino_outlined, size: 20),
                  tooltip: 'Roll Squad Initiative',
                  onPressed: onRollInitiative,
                ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F2B96),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: onOpenSquadBuilder,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF242038),
                onSelected: (val) {
                  if (val == 'initiative') {
                    onRollInitiative?.call();
                  } else if (val == 'tempHp') {
                    onGrantGroupTempHp?.call();
                  } else if (val == 'heal') {
                    onHealAll();
                  } else if (val == 'damage') {
                    onShowMassDamageDialog();
                  } else if (val == 'clear') {
                    onClearSquad();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'initiative',
                    child: Row(
                      children: [
                        Icon(Icons.casino, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Text('Roll Squad Initiative', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'tempHp',
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety_outlined, color: Colors.cyanAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Grant Group Temp HP', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'heal',
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Heal All Objects', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'damage',
                    child: Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Apply Group AoE Damage', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                        SizedBox(width: 8),
                        Text('Clear Squad', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
