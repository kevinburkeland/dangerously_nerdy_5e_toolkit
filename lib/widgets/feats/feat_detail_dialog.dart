import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/settings_provider.dart';
import '../../services/fluff/entity_fluff_service.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

/// Modal dialog presenting comprehensive feat details, formatted rules text,
/// mechanic grants breakdown, and bookmarking.
class FeatDetailDialog extends StatefulWidget {
  final Feat feat;
  final bool isPinned;
  final DmRulesEdition? edition;
  final VoidCallback onTogglePin;

  const FeatDetailDialog({
    super.key,
    required this.feat,
    required this.isPinned,
    this.edition,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required Feat feat,
    required bool isPinned,
    DmRulesEdition? edition,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => FeatDetailDialog(
        feat: feat,
        isPinned: isPinned,
        edition: edition,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<FeatDetailDialog> createState() => _FeatDetailDialogState();
}

class _FeatDetailDialogState extends State<FeatDetailDialog> {
  late bool _pinned;
  late TextEditingController _notesController;
  final EntityFluffService _fluffService = EntityFluffService();

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
    final existingNotes = _fluffService.getUserNotes('feat', widget.feat.id.slug) ?? '';
    _notesController = TextEditingController(text: existingNotes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _handlePinToggle() {
    HapticService.selectionTick(context);
    widget.onTogglePin();
    setState(() {
      _pinned = !_pinned;
    });
  }

  Color _getCategoryColor(String category, bool isDark) {
    final cat = category.toLowerCase();
    if (cat.contains('origin')) {
      return isDark ? const Color(0xFFFFD54F) : const Color(0xFFB45309);
    }
    if (cat.contains('fighting')) {
      return isDark ? const Color(0xFF69F0AE) : const Color(0xFF047857);
    }
    if (cat.contains('boon') || cat.contains('epic')) {
      return isDark ? const Color(0xFFE040FB) : const Color(0xFF7E22CE);
    }
    return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('origin')) return Icons.auto_awesome;
    if (cat.contains('fighting')) return Icons.sports_martial_arts;
    if (cat.contains('boon') || cat.contains('epic')) return Icons.stars;
    return Icons.military_tech;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final feat = widget.feat;
    final resolvedEdition = widget.edition ?? SettingsScope.maybeOf(context)?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024Mode = resolvedEdition == DmRulesEdition.v2024;
    final categoryLabel = (!is2024Mode && feat.category.toLowerCase() == 'origin') ? 'General' : feat.category;
    final featCat = FeatCategory.parse(categoryLabel);
    final accentColor = _getCategoryColor(categoryLabel, isDark);
    final categoryIcon = _getCategoryIcon(categoryLabel);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    final isHomebrew = feat.id.ruleset == RulesetVersion.homebrew;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 750),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DndGlyph.feat(
                  category: featCat,
                  featId: feat.id.slug,
                  displayName: feat.name,
                  size: 44,
                  isDarkMode: isDark,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feat.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$categoryLabel Feat • ${is2024Mode ? "2024 Rules (SRD 5.2)" : (isHomebrew ? "Custom Homebrew" : "2014 Rules (SRD 5.1)")}',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.bookmark : Icons.bookmark_border,
                    color: _pinned ? pinColor : theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _pinned ? 'Remove from Bookmarks' : 'Pin to Bookmarks',
                  onPressed: _handlePinToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(categoryIcon, size: 14, color: accentColor),
                  label: Text('$categoryLabel Feat'),
                  labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
                  visualDensity: VisualDensity.compact,
                ),
                if (feat.prerequisite != null && feat.prerequisite!.isNotEmpty)
                  Chip(
                    avatar: Icon(Icons.lock_outline, size: 14, color: isDark ? Colors.amberAccent : const Color(0xFFB45309)),
                    label: Text('Prerequisite: ${feat.prerequisite}'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    ),
                    backgroundColor: (isDark ? Colors.amberAccent : const Color(0xFFB45309)).withValues(alpha: 0.12),
                    side: BorderSide(color: (isDark ? Colors.amberAccent : const Color(0xFFB45309)).withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (feat.customProperties['repeatable'] == true)
                  Chip(
                    avatar: Icon(Icons.repeat, size: 14, color: isDark ? Colors.tealAccent : const Color(0xFF0F766E)),
                    label: const Text('Repeatable'),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                    ),
                    backgroundColor: (isDark ? Colors.tealAccent : const Color(0xFF0F766E)).withValues(alpha: 0.12),
                    side: BorderSide(color: (isDark ? Colors.tealAccent : const Color(0xFF0F766E)).withValues(alpha: 0.4)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
            const SizedBox(height: 12),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formatted Markdown description
                    FormattedMarkdownText(
                      feat.descriptionMarkdown,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mechanic Grants Breakdown (if any)
                    if (feat.grants.isNotEmpty) ...[
                      Text(
                        'AUTOMATED MECHANIC GRANTS',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...feat.grants.map((grant) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: accentColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  grant.label ?? grant.grantId,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                grant.type.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final slug = feat.id.slug;
                        final importedFluff = _fluffService.getFluff('feat', slug);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (importedFluff != null && importedFluff.loreMarkdown.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.menu_book, size: 16, color: accentColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Compendium Lore${importedFluff.source != null ? " (${importedFluff.source})" : ""}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: accentColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    FormattedMarkdownText(importedFluff.loreMarkdown),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            Row(
                              children: [
                                Icon(Icons.edit_note, size: 18, color: accentColor),
                                const SizedBox(width: 6),
                                Text(
                                  'Custom Feat & Build Notes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Character build synergy, campaign house rules, or roleplay notes.',
                              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _notesController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Add feat synergy or build notes...',
                                hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: accentColor, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              onChanged: (val) => _fluffService.setUserNotes('feat', slug, val),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
