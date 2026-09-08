import 'package:flutter/material.dart';
import '../../data/acl/character_telemetry_dto.dart';
import '../../data/acl/character_telemetry_resolver.dart';

/// Interactive vitality and combat meter HUD widget for a party member.
/// Renders live HP, temporary HP, AC, speed, passive perception, death saves,
/// spell slots, active conditions, and an "External Homebrew" indicator if
/// any pointers could not be hydrated from local libraries.
class PartyVitalityHud extends StatelessWidget {
  final ResolvedCharacterDisplay character;
  final VoidCallback? onTap;
  final ValueChanged<int>? onHpDelta;
  final bool isCompact;

  const PartyVitalityHud({
    super.key,
    required this.character,
    this.onTap,
    this.onHpDelta,
    this.isCompact = false,
  });

  /// Convenience constructor resolving a raw [CharacterTelemetryDto] on the fly.
  static Widget fromDto({
    Key? key,
    required CharacterTelemetryDto dto,
    VoidCallback? onTap,
    ValueChanged<int>? onHpDelta,
    bool isCompact = false,
  }) {
    return FutureBuilder<ResolvedCharacterDisplay>(
      key: key,
      future: CharacterTelemetryResolver.resolve(dto),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return PartyVitalityHud(
          character: snapshot.data!,
          onTap: onTap,
          onHpDelta: onHpDelta,
          isCompact: isCompact,
        );
      },
    );
  }

  Color _getHpColor(BuildContext context) {
    if (character.currentHp <= 0) return Colors.red.shade900;
    final pct = character.hpPercent;
    if (pct > 0.5) return Colors.green.shade600;
    if (pct > 0.25) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: isCompact ? 1 : 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: character.hasUnresolvedPointers
              ? Colors.amber.shade700.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 10 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Name, Identity, Homebrew Chip
              _buildHeader(context, isDark),

              const SizedBox(height: 10),

              // Vitality Bar (HP & Temp HP)
              _buildHpBar(context),

              if (character.currentHp == 0 && !character.isDead) ...[
                const SizedBox(height: 8),
                _buildDeathSaves(context),
              ],

              const SizedBox(height: 10),

              // Combat Stat Badges (AC, Speed, PP, Exhaustion)
              _buildStatPills(context, isDark),

              // Conditions (if any)
              if (character.conditions.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildConditionsWrap(context),
              ],

              // Spell Slots (if any)
              if (character.spellSlots.isNotEmpty && !isCompact) ...[
                const SizedBox(height: 8),
                _buildSpellSlotsRow(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: isCompact ? 16 : 20,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
          child: Text(
            character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: isCompact ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      character.name,
                      style: TextStyle(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Lvl ${character.totalLevel}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${character.speciesName} • ${character.classSummary}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (character.hasUnresolvedPointers)
          Tooltip(
            message:
                'Mechanical numbers are synced live, but full text requires the creator\'s homebrew module.',
            preferBelow: false,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade600),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade600, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.extension_outlined, size: 12, color: Colors.amber.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'External Homebrew',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHpBar(BuildContext context) {
    final theme = Theme.of(context);
    final hpColor = _getHpColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  character.currentHp > 0 ? Icons.favorite : Icons.heart_broken,
                  size: 14,
                  color: hpColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'HP: ${character.currentHp} / ${character.maxHp}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: hpColor,
                  ),
                ),
                if (character.tempHp > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.cyan.shade900.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.cyan.shade400, width: 0.8),
                    ),
                    child: Text(
                      '+${character.tempHp} THP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan.shade300,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (onHpDelta != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => onHpDelta!(-1),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('-1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => onHpDelta!(1),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('+1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: character.hpPercent,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(hpColor),
          ),
        ),
      ],
    );
  }

  Widget _buildDeathSaves(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade800.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'DEATH SAVES',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          Row(
            children: [
              const Text('S: ', style: TextStyle(fontSize: 10, color: Colors.green)),
              for (int i = 0; i < 3; i++)
                Icon(
                  i < character.deathSaveSuccesses ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: Colors.green,
                ),
              const SizedBox(width: 8),
              const Text('F: ', style: TextStyle(fontSize: 10, color: Colors.red)),
              for (int i = 0; i < 3; i++)
                Icon(
                  i < character.deathSaveFailures ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPills(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _pill(
          icon: Icons.shield,
          label: 'AC ${character.armorClass}',
          color: Colors.blueAccent,
          bg: bg,
        ),
        _pill(
          icon: Icons.directions_run,
          label: '${character.speed} ft',
          color: Colors.tealAccent,
          bg: bg,
        ),
        _pill(
          icon: Icons.visibility,
          label: 'PP ${character.passivePerception}',
          color: Colors.purpleAccent,
          bg: bg,
        ),
        if (character.exhaustionLevel > 0)
          _pill(
            icon: Icons.warning_amber,
            label: 'Exhaustion ${character.exhaustionLevel}',
            color: Colors.orangeAccent,
            bg: bg,
          ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsWrap(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: character.conditions.map((cond) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red.shade900.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.red.shade400, width: 0.8),
          ),
          child: Text(
            cond,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade300,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpellSlotsRow(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, size: 12, color: Colors.indigoAccent),
        const SizedBox(width: 4),
        const Text(
          'Spell Slots: ',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: character.spellSlots.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    'L${e.key}: ${e.value}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
