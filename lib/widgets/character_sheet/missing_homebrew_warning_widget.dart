import 'package:flutter/material.dart';
import '../../models/domain/character_models.dart';
import '../../services/rules/character_homebrew_validator.dart';

/// Interactive warning banner rendered at the top of the character sheet
/// when homebrew content required by the character is missing from the compendium.
class MissingHomebrewBanner extends StatelessWidget {
  final Character character;
  final MissingHomebrewReport report;

  const MissingHomebrewBanner({
    super.key,
    required this.character,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (!report.hasMissing) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amberBg = isDark
        ? const Color(0xFF332005)
        : const Color(0xFFFFF8E1);
    final amberBorder = isDark
        ? const Color(0xFFB45309)
        : const Color(0xFFFFB300);
    final amberText = isDark
        ? const Color(0xFFFDE68A)
        : const Color(0xFF78350F);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: amberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: amberBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showMissingHomebrewDialog(context, character: character, report: report),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: amberBorder.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: amberBorder,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Missing Homebrew Content',
                            style: TextStyle(
                              color: amberText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: amberBorder.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${report.count} missing',
                              style: TextStyle(
                                color: amberText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.summary}. Tap for details and restoration options.',
                        style: TextStyle(
                          color: amberText.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('missing_homebrew_banner_details_btn'),
                  onPressed: () => showMissingHomebrewDialog(
                    context,
                    character: character,
                    report: report,
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    backgroundColor: amberBorder.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: amberBorder.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Text(
                    'Details',
                    style: TextStyle(
                      color: amberText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact warning chip suitable for display on character roster cards.
class MissingHomebrewBadge extends StatelessWidget {
  final Character character;
  final MissingHomebrewReport report;

  const MissingHomebrewBadge({
    super.key,
    required this.character,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (!report.hasMissing) return const SizedBox.shrink();

    return InkWell(
      key: ValueKey('missing_homebrew_badge_${character.id.slug}'),
      onTap: () => showMissingHomebrewDialog(context, character: character, report: report),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade900.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amberAccent.shade400, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amberAccent.shade400),
            const SizedBox(width: 4),
            Text(
              'Missing Homebrew (${report.count})',
              style: TextStyle(
                color: Colors.amberAccent.shade400,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Displays an informative modal dialog detailing all missing homebrew dependencies
/// and practical steps to resolve the issue.
Future<void> showMissingHomebrewDialog(
  BuildContext context, {
  required Character character,
  required MissingHomebrewReport report,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final grouped = report.groupedByType;

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.colorScheme.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Missing Homebrew Content',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            character.name.isNotEmpty
                                ? 'Character: ${character.name}'
                                : 'Active Character',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),

                // Explanation
                Text(
                  'This character was created using homebrew content that is not currently loaded in your compendium. '
                  'The character is still fully playable, but features, spells, or equipment from these homebrew sources cannot be displayed or edited until restored.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Grouped Missing Items List
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            children: [
                              Text(
                                entry.key.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final item in entry.value)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _iconForType(item.type),
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (item.details != null && item.details!.isNotEmpty)
                                        Text(
                                          item.details!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      Text(
                                        'Identifier: ${item.slug}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),

                      // Remediation Advice Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'How to resolve:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '• Re-import the Homebrew Bundle (.json or .zip) from the Homebrew Studio.\n'
                              '• If this character was imported from another player, request their homebrew export file.\n'
                              '• You can also edit the character to select standard 2014 or 2024 SRD options.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom actions
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

IconData _iconForType(HomebrewEntityType type) {
  switch (type) {
    case HomebrewEntityType.classType:
      return Icons.shield_outlined;
    case HomebrewEntityType.subclassType:
      return Icons.military_tech_outlined;
    case HomebrewEntityType.speciesType:
    case HomebrewEntityType.subspeciesType:
      return Icons.person_outline;
    case HomebrewEntityType.backgroundType:
      return Icons.history_edu_outlined;
    case HomebrewEntityType.featType:
      return Icons.stars_outlined;
    case HomebrewEntityType.spellType:
      return Icons.auto_awesome_outlined;
    case HomebrewEntityType.itemType:
      return Icons.inventory_2_outlined;
    case HomebrewEntityType.otherType:
      return Icons.extension_outlined;
  }
}
