import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';

/// HUD widget rendering party vital statistics (HP, AC, PP, Spell Slots, Levels).
class DmDashboardPartyHud extends StatelessWidget {
  final List<Character> partyCharacters;
  final ValueChanged<Character>? onSelectCharacter;
  final VoidCallback? onAddCharacter;

  const DmDashboardPartyHud({
    super.key,
    List<Character>? partyCharacters,
    List<Character>? partyRoster,
    this.onSelectCharacter,
    this.onAddCharacter,
  }) : partyCharacters = partyCharacters ?? partyRoster ?? const [];

  List<Character> get partyRoster => partyCharacters;

  Color _getHpColor(int current, int max) {
    if (current <= 0) return Colors.red.shade900;
    final pct = max > 0 ? (current / max) : 1.0;
    if (pct <= 0.25) return Colors.red;
    if (pct <= 0.5) return Colors.amber.shade700;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (partyRoster.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.group_off_outlined, size: 40, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                'No Party Members Enrolled',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Add characters from your Character Builder to monitor party vitals.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (onAddCharacter != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onAddCharacter,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Character'),
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
      itemCount: partyRoster.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final character = partyRoster[index];
        final currentHp = character.resources.currentHp;
        final maxHp = (character.customProperties['maxHp'] as num?)?.toInt() ?? currentHp;
        final finalScores = character.baseScores.withBonus(character.bonusScores);
        final dexMod = (finalScores.dexterity - 10) ~/ 2;
        final wisMod = (finalScores.wisdom - 10) ~/ 2;
        final ac = (character.customProperties['armorClass'] as num?)?.toInt() ?? (10 + dexMod);
        final pp = (character.customProperties['passivePerception'] as num?)?.toInt() ?? (10 + wisMod);
        final level = character.progression.totalLevel;
        final startingClass = character.progression.startingClass?.classRef.displayName ?? 'Adventurer';

        final hpPct = maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 1.0;
        final hpColor = _getHpColor(currentHp, maxHp);

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: onSelectCharacter != null ? () => onSelectCharacter!(character) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              character.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Lvl $level $startingClass',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // AC Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined, size: 14),
                            const SizedBox(width: 4),
                            Text('AC $ac', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // PP Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14),
                            const SizedBox(width: 4),
                            Text('PP $pp', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // HP Bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: hpPct,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currentHp / $maxHp HP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hpColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
