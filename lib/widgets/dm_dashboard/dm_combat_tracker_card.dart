import 'package:material_ui/material_ui.dart';

import '../../models/arena/arena_condition.dart';
import '../../models/campaign_profile.dart';
import '../../models/domain/session_graph_models.dart';
import '../../theme/domain_ui_extensions.dart';

/// Combat and initiative tracker card for the DM Dashboard.
class DmCombatTrackerCard extends StatelessWidget {
  final CampaignProfile? activeProfile;
  final int currentRound;
  final VoidCallback onPrevTurn;
  final VoidCallback onNextTurn;
  final VoidCallback onRollAllInitiative;
  final VoidCallback onAddCombatant;
  final void Function(List<EncounterParticipant> encounter) onUpdateEncounter;
  final void Function(String participantId, int delta) onApplyDamageOrHeal;
  final void Function(String participantId, String conditionName) onToggleCondition;

  const DmCombatTrackerCard({
    super.key,
    required this.activeProfile,
    required this.currentRound,
    required this.onPrevTurn,
    required this.onNextTurn,
    required this.onRollAllInitiative,
    required this.onAddCombatant,
    required this.onUpdateEncounter,
    required this.onApplyDamageOrHeal,
    required this.onToggleCondition,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final participants = activeProfile!.roomState.activeEncounterList;

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
                const Icon(Icons.sports_kabaddi,
                    color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Combat & Turn Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Round $currentRound',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.skip_previous, size: 16),
                  label: const Text('Prev'),
                  onPressed: participants.isNotEmpty ? onPrevTurn : null,
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('Next Turn'),
                  onPressed: participants.isNotEmpty ? onNextTurn : null,
                ),
                IconButton(
                  icon: const Icon(Icons.casino, size: 20),
                  tooltip: 'Reroll All Initiative',
                  onPressed:
                      participants.isNotEmpty ? onRollAllInitiative : null,
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  tooltip: 'Broken Add',
                  onPressed: onAddCombatant,
                ),
              ],
            ),
            const Divider(height: 20),
            if (participants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 36, color: theme.colorScheme.outlineVariant),
                      const SizedBox(height: 8),
                      Text(
                        'No active encounter participants.',
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Combatant'),
                        onPressed: onAddCombatant,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: participants.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = participants[i];
                  return _buildParticipantTile(context, p);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(BuildContext context, EncounterParticipant p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = p.isActiveTurn;
    final curHp = p.currentHp ?? 10;
    final maxHp = p.maxHp ?? 10;
    final tempHp = p.tempHp ?? 0;
    final isDefeated = p.isDefeated == true;
    final hpPercent =
        (curHp / (maxHp > 0 ? maxHp : 1)).clamp(0.0, 1.0);
    final hpColor = hpPercent > 0.5
        ? Colors.greenAccent
        : (hpPercent > 0.2 ? Colors.amberAccent : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer
                .withValues(alpha: isDark ? 0.3 : 0.4)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isActive ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Init ${p.initiativeScore}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.entityLink.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDefeated
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                    decoration:
                        isDefeated ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'AC ${p.armorClass}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: () {
                  final list = List<EncounterParticipant>.from(
                      activeProfile!.roomState.activeEncounterList)
                    ..removeWhere(
                        (item) => item.participantId == p.participantId);
                  onUpdateEncounter(list);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          // HP Bar & Quick Modifier Chips
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'HP: $curHp/$maxHp${tempHp > 0 ? " (+$tempHp Temp)" : ""}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: hpColor),
                        ),
                        Text('${(hpPercent * 100).toInt()}%',
                            style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: hpPercent,
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Damage / Heal Chips
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildHpModifierChip(
                  '-10', -10, p.participantId, Colors.redAccent),
              _buildHpModifierChip('-5', -5, p.participantId, Colors.redAccent),
              _buildHpModifierChip('-1', -1, p.participantId, Colors.redAccent),
              _buildHpModifierChip(
                  '+1', 1, p.participantId, Colors.greenAccent),
              _buildHpModifierChip(
                  '+5', 5, p.participantId, Colors.greenAccent),
              _buildHpModifierChip(
                  '+10', 10, p.participantId, Colors.greenAccent),
              PopupMenuButton<ArenaCondition>(
                icon: const Icon(Icons.add_alert, size: 16),
                tooltip: 'Add Condition',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onSelected: (cond) =>
                    onToggleCondition(p.participantId, cond.name),
                itemBuilder: (context) => ArenaCondition.values.map((c) {
                  return PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 16, color: c.colorTheme),
                        const SizedBox(width: 8),
                        Text(c.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (p.activeConditions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: p.activeConditions.map((condName) {
                final cond = ArenaCondition.fromName(condName);
                return Chip(
                  avatar: cond != null
                      ? Icon(cond.icon, size: 12, color: cond.colorTheme)
                      : null,
                  label: Text(cond?.label ?? condName,
                      style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  onDeleted: () => onToggleCondition(p.participantId, condName),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHpModifierChip(
      String label, int delta, String participantId, Color color) {
    return InkWell(
      onTap: () => onApplyDamageOrHeal(participantId, delta),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  // --- Widget 2: Party Vitality HUD ---


}
