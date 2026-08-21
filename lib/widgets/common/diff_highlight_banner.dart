import 'package:flutter/material.dart';

/// Reusable, theme-reactive banner highlighting 2024 Revised rule changes and key bullet points.
class DiffHighlightBanner extends StatelessWidget {
  final String? diffSummary;
  final List<String> diffHighlights;
  final String title;

  const DiffHighlightBanner({
    super.key,
    this.diffSummary,
    this.diffHighlights = const [],
    this.title = '2024 REVISED RULES DIFF HIGHLIGHTS',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    if (diffSummary == null && diffHighlights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: diffColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: diffColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: diffColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: diffColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (diffSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              diffSummary!,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          if (diffHighlights.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: diffHighlights.map((hl) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: diffColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: diffColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '• $hl',
                    style: TextStyle(
                      color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
