import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animated_object.dart';
import '../services/a11y_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/edit_object_name_dialog.dart';
import 'dialogs/set_object_hp_dialog.dart';
import 'dialogs/creature_stat_block_dialog.dart';

class ObjectCard extends StatelessWidget {
  final AnimatedObjectInstance object;
  final VoidCallback onDelete;
  final Function(int delta) onHpChanged;
  final Function(String name) onNameChanged;
  final Function(int currentHp, int tempHp)? onHpDataSet;

  const ObjectCard({
    super.key,
    required this.object,
    required this.onDelete,
    required this.onHpChanged,
    required this.onNameChanged,
    this.onHpDataSet,
  });

  Future<void> _showEditNameDialog(BuildContext context) async {
    HapticFeedback.selectionClick();
    final newName = await EditObjectNameDialog.show(context, initialName: object.name);
    if (newName != null && newName.isNotEmpty) {
      onNameChanged(newName);
    }
  }

  Future<void> _showCustomHpDialog(BuildContext context) async {
    HapticFeedback.selectionClick();
    final result = await SetObjectHpDialog.show(
      context,
      objectName: object.name,
      currentHp: object.currentHp,
      maxHp: object.maxHp,
      tempHp: object.tempHp,
    );
    if (result != null) {
      if (onHpDataSet != null) {
        onHpDataSet!(result.currentHp, result.tempHp);
      } else {
        object.tempHp = result.tempHp;
        onHpChanged(result.currentHp - object.currentHp);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<TabletopColors>() ?? TabletopColors.dark;
    final size = object.size;
    final isDead = object.isDead;
    final accentColor = size.accentColor;

    return Card(
      elevation: isDead ? 0 : 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDead ? customColors.fumbleRed.withValues(alpha: 0.5) : accentColor.withValues(alpha: 0.6),
          width: isDead ? 1 : 1.5,
        ),
      ),
      color: isDead
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : (theme.cardTheme.color ?? theme.colorScheme.surface),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Size Pill, Name, and Quick Delete
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1.2),
                  ),
                  child: Text(
                    '${size.displayName.toUpperCase()} (${size.pointCost}pt)',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _showEditNameDialog(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
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
                          Icon(Icons.edit_outlined, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, size: 20, color: accentColor.withValues(alpha: 0.85)),
                  tooltip: 'Full Creature Stat Block',
                  onPressed: () => CreatureStatBlockDialog.show(context, statBlock: object.statBlock),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white38),
                  tooltip: 'Remove Minion',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: 1-Second Combat Stat HUD
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBlock('AC', '${object.ac}', Colors.lightBlueAccent, semanticName: 'Armor Class', isHero: true),
                  _buildDivider(),
                  _buildStatBlock('TO HIT', '+${object.attackBonus}', Colors.amberAccent, semanticName: 'Attack Bonus', isHero: true),
                  _buildDivider(),
                  _buildStatBlock('DMG', object.damageFormula, Colors.orangeAccent, semanticName: 'Damage Formula', isHero: true),
                  _buildDivider(),
                  _buildStatBlock('STR', '${size.strScore}', Colors.white70, semanticName: 'Strength Score'),
                  _buildDivider(),
                  _buildStatBlock('DEX', '${size.dexScore}', Colors.white70, semanticName: 'Dexterity Score'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Row 3: Ergonomic HP Controls
            Row(
              children: [
                _buildHpButton(
                  icon: Icons.remove,
                  color: Colors.redAccent,
                  enabled: !isDead,
                  tooltip: '-1 HP',
                  semanticLabel: 'Decrease 1 HP for ${object.name}',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final newHp = (object.currentHp - 1).clamp(0, object.maxHp);
                    A11yService.announceHpChange(
                      object.name,
                      currentHp: newHp,
                      maxHp: object.maxHp,
                      delta: -1,
                      tempHp: object.tempHp,
                      isDead: newHp <= 0,
                    );
                    onHpChanged(-1);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: '${object.name} Hit Points: ${isDead ? "Destroyed" : "${object.currentHp} of ${object.maxHp}"}${object.tempHp > 0 ? ", plus ${object.tempHp} temporary HP" : ""}. ${(object.hpPercent * 100).toInt()} percent remaining. Tap to edit custom HP.',
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showCustomHpDialog(context),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isDead ? '💀 DESTROYED' : 'HP: ${object.currentHp} / ${object.maxHp}',
                                    style: TextStyle(
                                      color: isDead ? customColors.fumbleRed : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (object.tempHp > 0 && !isDead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: customColors.tempHpCyan.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: customColors.tempHpCyan, width: 1),
                                      ),
                                      child: Text(
                                        '+${object.tempHp} TEMP',
                                        style: TextStyle(
                                          color: customColors.tempHpCyan,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${(object.hpPercent * 100).toInt()}%',
                                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: object.hpPercent,
                              minHeight: 10,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                object.hpPercent > 0.5
                                    ? customColors.hitGreen
                                    : (object.hpPercent > 0.2 ? Colors.amber : customColors.fumbleRed),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildHpButton(
                  icon: Icons.add,
                  color: customColors.hitGreen,
                  enabled: object.currentHp < object.maxHp,
                  tooltip: '+1 HP',
                  semanticLabel: 'Increase 1 HP for ${object.name}',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final newHp = (object.currentHp + 1).clamp(0, object.maxHp);
                    A11yService.announceHpChange(
                      object.name,
                      currentHp: newHp,
                      maxHp: object.maxHp,
                      delta: 1,
                      tempHp: object.tempHp,
                    );
                    onHpChanged(1);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBlock(String label, String value, Color color, {required String semanticName, bool isHero = false}) {
    return Semantics(
      label: '$semanticName: $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isHero ? 10 : 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isHero ? 15 : 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildHpButton({
    required IconData icon,
    required Color color,
    required bool enabled,
    required String tooltip,
    String? semanticLabel,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 48,
        minHeight: 48,
      ),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: semanticLabel ?? tooltip,
          enabled: enabled,
          child: Material(
            color: enabled ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: enabled ? color.withValues(alpha: 0.6) : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? onTap : null,
              child: Center(
                child: Icon(icon, color: enabled ? color : Colors.white24, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
