import 'package:flutter/material.dart';
import '../../models/dpr/dpr_models.dart';

/// Card component displaying combat stats HUD, giant DPR number, hit/crit chances, and tactical recommendation.
class DprMetricsCard extends StatelessWidget {
  final int selectedAc;
  final DprPoint point;
  final DprBreakEvenAnalysis breakEven;

  const DprMetricsCard({
    super.key,
    required this.selectedAc,
    required this.point,
    required this.breakEven,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hitPercent = (point.hitChance * 100).toStringAsFixed(1);
    final critPercent = (point.critChance * 100).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0C1B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.cyanAccent.withValues(alpha: 0.25) : Colors.cyan.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: -2,
            ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Giant DPR Number
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt, color: Colors.cyanAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COMBAT STATS (AC $selectedAc)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Text(
                        'Expected Damage Output',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF00E5FF).withValues(alpha: 0.2), const Color(0xFF7C3AED).withValues(alpha: 0.2)]
                        : [Colors.cyan.shade100, Colors.purple.shade100],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.cyanAccent.withValues(alpha: 0.4) : Colors.cyan.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      point.dpr.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'DPR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Grid Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildHudTile(
                  icon: Icons.track_changes,
                  title: 'Accuracy',
                  value: '$hitPercent%',
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.whatshot,
                  title: 'Crit Rate',
                  value: '$critPercent%',
                  color: isDark ? const Color(0xFFF43F5E) : const Color(0xFFE11D48),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.shield_outlined,
                  title: 'Avg on Hit',
                  value: point.expectedDamageOnHit.toStringAsFixed(1),
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHudTile(
                  icon: Icons.auto_awesome,
                  title: 'Avg on Crit',
                  value: point.expectedDamageOnCrit.toStringAsFixed(1),
                  color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tactical Recommendation Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF261E08), const Color(0xFF191307)]
                    : [Colors.amber.shade50, Colors.amber.shade100],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.amber.withValues(alpha: 0.5) : Colors.amber.shade400,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology, color: Colors.amberAccent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    breakEven.recommendation,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171427) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
