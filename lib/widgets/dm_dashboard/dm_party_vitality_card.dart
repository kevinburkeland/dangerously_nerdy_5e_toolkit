import 'package:material_ui/material_ui.dart';

import '../../models/dm_screen_data.dart';
import '../../providers/dm_dashboard_controller.dart';
import '../party/party_vitality_hud.dart';

/// Party vitality HUD card for the DM Dashboard.
class DmPartyVitalityCard extends StatelessWidget {
  final DmDashboardController controller;
  final VoidCallback onAddPartyMember;
  final void Function(Character character) onOpenCharacterSheet;
  final void Function(String characterId, int delta) onModifyCharacterHp;
  final void Function(String characterId, int level) onToggleSpellSlot;
  final void Function(String characterId, String coinKey, int delta)
      onModifyCharacterPurseCoin;

  const DmPartyVitalityCard({
    super.key,
    required this.controller,
    required this.onAddPartyMember,
    required this.onOpenCharacterSheet,
    required this.onModifyCharacterHp,
    required this.onToggleSpellSlot,
    required this.onModifyCharacterPurseCoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roster = controller.partyCharacters;

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
                const Icon(Icons.shield_moon,
                    color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Party Vitality HUD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add_alt, size: 20),
                  tooltip: 'Add Party Member',
                  onPressed: onAddPartyMember,
                ),
              ],
            ),
            const Divider(height: 20),
            Builder(
              builder: (context) {
                final remoteOnlyDisplays = controller
                    .resolvedTelemetryMap.values
                    .where((disp) => !roster.any(
                        (c) => c.id.slug == disp.id || c.name == disp.name))
                    .toList();

                if (roster.isEmpty && remoteOnlyDisplays.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Hero to Party Roster'),
                        onPressed: onAddPartyMember,
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (roster.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: roster.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final char = roster[i];
                          return _buildCharacterVitalityTile(context, char);
                        },
                      ),
                    if (remoteOnlyDisplays.isNotEmpty) ...[
                      if (roster.isNotEmpty) const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'REMOTE TELEMETRY MEMBERS (${remoteOnlyDisplays.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      ...remoteOnlyDisplays.map((disp) => PartyVitalityHud(
                            character: disp,
                            isCompact: true,
                          )),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterVitalityTile(BuildContext context, Character char) {
    final theme = Theme.of(context);
    final curHp = char.resources.currentHp;
    final wisMod = char.baseScores.getModifier(AbilityType.wisdom);
    final isProficient =
        char.skillProficiencies.containsKey(SkillType.perception);
    final passivePerception =
        10 + wisMod + (isProficient ? char.proficiencyBonus : 0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onOpenCharacterSheet(char),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                char.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new,
                                size: 12, color: theme.colorScheme.primary),
                          ],
                        ),
                        Text(
                          'Lvl ${char.totalLevel} • AC 16 • Pass. Percept: $passivePerception',
                          style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.badge_outlined,
                    size: 18, color: Colors.cyanAccent),
                tooltip: 'Open Full Sheet (DM Mode)',
                onPressed: () => onOpenCharacterSheet(char),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    size: 18, color: Colors.redAccent),
                onPressed: () => onModifyCharacterHp(char.id.slug, -5),
              ),
              Text(
                '$curHp HP',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.greenAccent),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    size: 18, color: Colors.greenAccent),
                onPressed: () => onModifyCharacterHp(char.id.slug, 5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet,
                        size: 12, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${char.purse.gp} GP • ~${char.purse.totalGpEquivalent.toStringAsFixed(1)} GP eq',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => onModifyCharacterPurseCoin(char.id.slug, 'gp', 10),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('+10 GP',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent)),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => onModifyCharacterPurseCoin(char.id.slug, 'gp', -10),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('-10 GP',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent)),
                ),
              ),
            ],
          ),
          // Spell Slots Matrix if caster
          if (char.resources.spellSlots.maxSlots.values.any((s) => s > 0)) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: List.generate(9, (slotIndex) {
                final level = slotIndex + 1;
                final max = char.resources.spellSlots.maxSlots[level] ?? 0;
                if (max <= 0) return const SizedBox.shrink();
                final current =
                    char.resources.spellSlots.currentSlots[level] ?? max;

                return InkWell(
                  onTap: () => onToggleSpellSlot(char.id.slug, level),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.purpleAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'L$level: $current/$max',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purpleAccent),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // --- Widget 3: Minion & Summon HUD ---


}
