import 'package:flutter/material.dart';
import '../../models/spell_session.dart';

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
    final used = session.usedPoints;
    final maxPts = session.maxPoints;
    final pct = (used / maxPts).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF191626),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Point Budget: $used / $maxPts points used',
                style: TextStyle(
                  color: used > maxPts ? Colors.redAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${session.activeObjects.length} Objects',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(
                used > maxPts ? Colors.redAccent : Colors.amber,
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
