import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';

class SquadBuilderBottomSheet extends StatefulWidget {
  final SpellSession session;
  final VoidCallback onSquadUpdated;

  const SquadBuilderBottomSheet({
    super.key,
    required this.session,
    required this.onSquadUpdated,
  });

  @override
  State<SquadBuilderBottomSheet> createState() => _SquadBuilderBottomSheetState();
}

class _SquadBuilderBottomSheetState extends State<SquadBuilderBottomSheet> {
  void _addPreset(ObjectSize size, int count, {String? customName}) {
    for (int i = 0; i < count; i++) {
      if (widget.session.canAddObject(size)) {
        widget.session.addObject(size, customName: customName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough remaining point capacity for more ${size.displayName} objects!'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      }
    }
    setState(() {});
    widget.onSquadUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header & Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Animated Objects',
                  style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: session.remainingPoints > 0 ? Colors.amber.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: session.remainingPoints > 0 ? Colors.amber : Colors.red),
                  ),
                  child: Text(
                    'Budget: ${session.usedPoints} / ${session.maxPoints} pts',
                    style: TextStyle(
                      color: session.remainingPoints > 0 ? Colors.amber : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Presets Header
            const Text(
              '⚡ QUICK PRESETS',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton('10x Tiny (Coins/Needles)', () => _addPreset(ObjectSize.tiny, 10, customName: 'Animated Coin')),
                _buildPresetButton('5x Small (Daggers/Chairs)', () => _addPreset(ObjectSize.small, 5, customName: 'Animated Dagger')),
                _buildPresetButton('5x Medium (Swords/Tables)', () => _addPreset(ObjectSize.medium, 5, customName: 'Animated Greatsword')),
                _buildPresetButton('2x Large (Statues/Carts)', () => _addPreset(ObjectSize.large, 2, customName: 'Animated Statue')),
                _buildPresetButton('1x Huge (Boulders/Wagons)', () => _addPreset(ObjectSize.huge, 1, customName: 'Animated Boulder')),
              ],
            ),
            const SizedBox(height: 20),

            // Individual Object Size Buttons
            const Text(
              '➕ ADD INDIVIDUAL SIZES',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children: ObjectSize.values.map((size) {
                final canAdd = session.canAddObject(size);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: size.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: size.accentColor.withValues(alpha: 0.2),
                      child: Text(
                        '${size.pointCost}p',
                        style: TextStyle(color: size.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    title: Text(
                      size.displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'HP ${size.maxHp} | AC ${size.ac} | +${size.attackBonus} to hit | ${size.damageFormula}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAdd ? size.accentColor : Colors.grey.shade800,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: canAdd ? () => _addPreset(size, 1) : null,
                      child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF2C2840),
      side: const BorderSide(color: Colors.amber, width: 1),
      label: Text(label, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
      onPressed: onTap,
    );
  }
}
