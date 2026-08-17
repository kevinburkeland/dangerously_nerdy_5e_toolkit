import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Interactive modal comparing 2014 RAW rules vs 2024 Revised rules side-by-side.
class DmRuleComparisonDialog extends StatefulWidget {
  final DmReferenceItem item;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const DmRuleComparisonDialog({
    super.key,
    required this.item,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required DmReferenceItem item,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => DmRuleComparisonDialog(
        item: item,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<DmRuleComparisonDialog> createState() => _DmRuleComparisonDialogState();
}

class _DmRuleComparisonDialogState extends State<DmRuleComparisonDialog> {
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
  }

  void _handlePinToggle() {
    setState(() {
      _pinned = !_pinned;
    });
    widget.onTogglePin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;
    final itemColor = item.getLegibleColor(isDark);
    final diffColor = isDark ? Colors.amber : const Color(0xFFB45309);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: itemColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '2014 vs 2024 Rule Comparison',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: _pinned ? diffColor : theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  tooltip: _pinned ? 'Unpin rule' : 'Pin rule to top',
                  onPressed: _handlePinToggle,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                  tooltip: 'Close comparison dialog',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Diff Summary Banner if changed
            if (item.isChangedIn2024 && item.diffSummary != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: diffColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome, color: diffColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.diffSummary!,
                        style: TextStyle(
                          color: diffColor,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Side-by-side or stacked rule blocks
            Expanded(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 550;
                    final v2014Color = isDark ? Colors.blueGrey : const Color(0xFF475569);
                    final v2024Color = isDark ? Colors.cyanAccent : theme.colorScheme.primary;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildEditionBox(context, '2014 (5e RAW)', item.rules2014, v2014Color)),
                          const SizedBox(width: 14),
                          Expanded(child: _buildEditionBox(context, '2024 (Revised 5e)', item.rules2024, v2024Color)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildEditionBox(context, '2014 (5e RAW)', item.rules2014, v2014Color),
                          const SizedBox(height: 12),
                          _buildEditionBox(context, '2024 (Revised 5e)', item.rules2024, v2024Color),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditionBox(BuildContext context, String title, List<String> rules, Color accentColor) {
    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>() ?? TabletopColors.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tabletop.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_outline, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Divider(height: 16, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          ...rules.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        r,
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.85), fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
