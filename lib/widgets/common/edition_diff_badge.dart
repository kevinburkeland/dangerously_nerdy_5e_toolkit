import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

/// Reusable amber '2024 Diff' chip badge used across cards to indicate revised 5.2 mechanics.
class EditionDiffBadge extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool isDense;

  const EditionDiffBadge({
    super.key,
    this.onTap,
    this.label = '2024 Diff',
    this.isDense = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDense ? 6 : 8,
        vertical: isDense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: diffColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: diffColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: isDense ? 11 : 13, color: diffColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: diffColor,
              fontSize: isDense ? 10.5 : 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          HapticService.selectionTick(context);
          onTap!();
        },
        borderRadius: BorderRadius.circular(6),
        child: badge,
      );
    }

    return badge;
  }
}
