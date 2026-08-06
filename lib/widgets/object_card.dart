import 'package:flutter/material.dart';
import '../models/animated_object.dart';

class ObjectCard extends StatelessWidget {
  final AnimatedObjectInstance object;
  final VoidCallback onDelete;
  final Function(int delta) onHpChanged;
  final Function(String name) onNameChanged;

  const ObjectCard({
    super.key,
    required this.object,
    required this.onDelete,
    required this.onHpChanged,
    required this.onNameChanged,
  });

  void _showEditNameDialog(BuildContext context) {
    TextEditingController controller = TextEditingController(text: object.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Text('Rename Object', style: TextStyle(color: Colors.amber)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter custom object name',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onNameChanged(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showCustomHpDialog(BuildContext context) {
    TextEditingController controller = TextEditingController(text: '${object.currentHp}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: Text('Set HP for ${object.name}', style: const TextStyle(color: Colors.amber)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Current HP (Max ${object.maxHp})',
            labelStyle: const TextStyle(color: Colors.white70),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () {
              int? newHp = int.tryParse(controller.text);
              if (newHp != null) {
                onHpChanged(newHp - object.currentHp);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set HP', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = object.size;
    final isDead = object.isDead;
    final color = size.accentColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: isDead ? const Color(0xFF1E1C24) : const Color(0xFF2C2840),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDead ? Colors.red.withValues(alpha: 0.4) : color.withValues(alpha: 0.6),
          width: isDead ? 1 : 1.5,
        ),
        boxShadow: isDead
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top Row: Size Badge, Name, Delete button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Text(
                    '${size.displayName} (${size.pointCost}pt)',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _showEditNameDialog(context),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            object.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDead ? Colors.white38 : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: isDead ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 14,
                          color: isDead ? Colors.white24 : Colors.white54,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Remove Object',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stat Line: AC, To Hit, Damage, Str, Dex
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatPill('AC', '${size.ac}', Colors.lightBlueAccent),
                _buildStatPill('Hit', '+${size.attackBonus}', Colors.amber),
                _buildStatPill('Dmg', size.damageFormula, Colors.orangeAccent),
                _buildStatPill('STR', '${size.strScore}', Colors.white70),
                _buildStatPill('DEX', '${size.dexScore}', Colors.white70),
              ],
            ),
            const SizedBox(height: 10),

            // Health Bar & HP Controls
            Row(
              children: [
                // Quick HP decrease
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                  onPressed: isDead ? null : () => onHpChanged(-1),
                  tooltip: '-1 HP',
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCustomHpDialog(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isDead ? 'DESTROYED' : 'HP: ${object.currentHp} / ${object.maxHp}',
                              style: TextStyle(
                                color: isDead ? Colors.redAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${(object.hpPercent * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: object.hpPercent,
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              object.hpPercent > 0.5
                                  ? Colors.green
                                  : (object.hpPercent > 0.2 ? Colors.orange : Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Quick HP increase
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                  onPressed: object.currentHp >= object.maxHp ? null : () => onHpChanged(1),
                  tooltip: '+1 HP',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

extension ColorHelpers on Colors {
  static Color get blueLighten => const Color(0xFF64B5F6);
}
