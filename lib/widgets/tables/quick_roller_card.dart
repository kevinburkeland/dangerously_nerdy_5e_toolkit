import 'package:flutter/material.dart';
import '../../models/tables/rollable_table.dart';
import '../../models/tables/srd_dm_tables.dart';
import '../../models/tables/srd_loot_tables.dart';
import '../../models/tables/srd_magic_tables.dart';
import '../../services/haptic_service.dart';

/// Quick-roller visual widgets for instant high-frequency DM table rolls.
class QuickRollerCard extends StatefulWidget {
  const QuickRollerCard({super.key});

  @override
  State<QuickRollerCard> createState() => _QuickRollerCardState();
}

class _QuickRollerCardState extends State<QuickRollerCard> {
  TableRollResult? _wildMagicResult;
  TableRollResult? _trinketResult;
  TableRollResult? _madnessResult;
  TableRollResult? _reincarnateResult;
  TableRollResult? _confusionResult;

  void _rollWildMagic() {
    HapticService.heavyImpact(context);
    setState(() {
      _wildMagicResult = SrdMagicTables.wildMagicSurge.roll();
    });
  }

  void _rollTrinket() {
    HapticService.lightImpact(context);
    setState(() {
      _trinketResult = SrdLootTables.trinketsTable.roll();
    });
  }

  void _rollMadness(RollableTable table) {
    HapticService.mediumImpact(context);
    setState(() {
      _madnessResult = table.roll();
    });
  }

  void _rollReincarnate() {
    HapticService.selectionTick(context);
    setState(() {
      _reincarnateResult = SrdMagicTables.reincarnateRace.roll();
    });
  }

  void _rollConfusion() {
    HapticService.selectionTick(context);
    setState(() {
      _confusionResult = SrdMagicTables.confusionBehavior.roll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Wild Magic Surge Card
          _buildQuickBox(
            context,
            title: 'Wild Magic Surge (d100)',
            icon: Icons.auto_awesome,
            accentColor: const Color(0xFFC084FC),
            buttonLabel: 'Surge Chaos (d100)',
            onRoll: _rollWildMagic,
            result: _wildMagicResult,
            isDark: isDark,
          ),

          const SizedBox(height: 14),

          // 2. Trinket Dispenser Card
          _buildQuickBox(
            context,
            title: '100 SRD Trinkets Dispenser',
            icon: Icons.stars_outlined,
            accentColor: const Color(0xFF10B981),
            buttonLabel: 'Dispense Trinket',
            onRoll: _rollTrinket,
            result: _trinketResult,
            isDark: isDark,
          ),

          const SizedBox(height: 14),

          // 3. Madness Checker
          _buildMadnessBox(context, isDark),

          const SizedBox(height: 14),

          // 4. Reincarnate & Confusion Row
          Row(
            children: [
              Expanded(
                child: _buildSmallQuickBox(
                  context,
                  title: 'Reincarnate',
                  subtitle: 'New Ancestry (d100)',
                  icon: Icons.nature_people_outlined,
                  accentColor: Colors.amberAccent,
                  onRoll: _rollReincarnate,
                  result: _reincarnateResult,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSmallQuickBox(
                  context,
                  title: 'Confusion',
                  subtitle: 'Spell Action (d10)',
                  icon: Icons.psychology_outlined,
                  accentColor: Colors.cyanAccent,
                  onRoll: _rollConfusion,
                  result: _confusionResult,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBox(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color accentColor,
    required String buttonLabel,
    required VoidCallback onRoll,
    required TableRollResult? result,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 90 : 70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(isDark ? 25 : 15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.casino, size: 16),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRoll,
              ),
            ],
          ),

          if (result != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 25 : 15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'd100: ${result.rollValue}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.entry.label,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (result.entry.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.entry.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMadnessBox(BuildContext context, bool isDark) {
    const accentColor = Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 90 : 70),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Icon(Icons.psychology, color: accentColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Madness Generator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _rollMadness(SrdDmTables.shortTermMadness),
                child: const Text('Short-Term (1d10 min)'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _rollMadness(SrdDmTables.longTermMadness),
                child: const Text('Long-Term (1d100 hr)'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => _rollMadness(SrdDmTables.indefiniteMadness),
                child: const Text('Indefinite (Flaw)'),
              ),
            ],
          ),

          if (_madnessResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 25 : 15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_madnessResult!.tableName} • ${_madnessResult!.rollValue}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _madnessResult!.entry.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (_madnessResult!.entry.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _madnessResult!.entry.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallQuickBox(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onRoll,
    required TableRollResult? result,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withAlpha(isDark ? 80 : 60),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor.withAlpha(40),
              foregroundColor: accentColor,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: accentColor.withAlpha(100)),
              ),
            ),
            onPressed: onRoll,
            child: const Text('Roll', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(isDark ? 20 : 15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${result.entry.label}\n${result.entry.description ?? ''}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
