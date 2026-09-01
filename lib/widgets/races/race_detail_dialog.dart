import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../providers/settings_provider.dart';
import '../../services/fluff/entity_fluff_service.dart';
import '../../services/haptic_service.dart';
import '../common/edition_diff_badge.dart';
import '../common/formatted_markdown_text.dart';

/// Modal dialog providing comprehensive details, subrace options, imported lore/fluff,
/// and editable user-notes for a 5e Species or Lineage.
class RaceDetailDialog extends StatefulWidget {
  final Race race;

  const RaceDetailDialog({
    super.key,
    required this.race,
  });

  static Future<void> show(BuildContext context, Race race) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => RaceDetailDialog(race: race),
    );
  }

  @override
  State<RaceDetailDialog> createState() => _RaceDetailDialogState();
}

class _RaceDetailDialogState extends State<RaceDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _notesController;
  final EntityFluffService _fluffService = EntityFluffService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final existingNotes = _fluffService.getUserNotes('race', widget.race.id.slug) ?? '';
    _notesController = TextEditingController(text: existingNotes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveNotes(String text) {
    _fluffService.setUserNotes('race', widget.race.id.slug, text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsProvider = SettingsScope.of(context);
    final isPinned = settingsProvider.isRacePinned(widget.race.id.slug);
    final is2024 = widget.race.id.ruleset == RulesetVersion.v2024;
    final isHomebrew = widget.race.id.ruleset == RulesetVersion.homebrew;

    final importedFluff = _fluffService.getFluff('race', widget.race.id.slug);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Column(
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.people_alt, color: Color(0xFF10B981), size: 20),
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
                                widget.race.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (is2024 && !isHomebrew) ...[
                              const SizedBox(width: 8),
                              const EditionDiffBadge(),
                            ],
                          ],
                        ),
                        Text(
                          '${widget.race.size} • ${widget.race.speed} • ${is2024 ? "2024 Species" : (isHomebrew ? "Homebrew" : "2014 Race")}',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.bookmark : Icons.bookmark_border,
                      color: isPinned ? const Color(0xFF10B981) : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isPinned ? 'Remove bookmark' : 'Bookmark species',
                    onPressed: () {
                      HapticService.selectionTick(context);
                      settingsProvider.togglePinRace(widget.race.id.slug);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF10B981),
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.psychology, size: 18), text: 'Traits & Lineages'),
                Tab(icon: Icon(Icons.auto_stories, size: 18), text: 'Lore & Notes'),
              ],
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Traits & Lineages
                  _buildTraitsTab(context, theme, isDark),

                  // Tab 2: Lore & Notes
                  _buildLoreNotesTab(context, theme, isDark, importedFluff),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitsTab(BuildContext context, ThemeData theme, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Stats Strip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Species Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text('• Size: ${widget.race.size}', style: const TextStyle(fontSize: 12.5)),
              Text('• Speed: ${widget.race.speed}', style: const TextStyle(fontSize: 12.5)),
              if (widget.race.abilityScoreSummary != null && widget.race.abilityScoreSummary!.isNotEmpty)
                Text('• Ability Scores: ${widget.race.abilityScoreSummary}', style: const TextStyle(fontSize: 12.5)),
              if (widget.race.bonusFeatCount > 0)
                Text('• Bonus Feats: +${widget.race.bonusFeatCount} Feat choice', style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Full Markdown Traits
        Text(
          'Species Traits',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        FormattedMarkdownText(
          widget.race.traitsMarkdown,
        ),

        // Subraces / Lineages Breakdown
        if (widget.race.subraces.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Lineages & Subraces (${widget.race.subraces.length})',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...widget.race.subraces.map((subrace) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_moon, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          subrace.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FormattedMarkdownText(subrace.traitsMarkdown),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildLoreNotesTab(BuildContext context, ThemeData theme, bool isDark, EntityFluff? importedFluff) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Imported Fluff Section
        if (importedFluff != null && importedFluff.loreMarkdown.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book, size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Text(
                      'Compendium Lore${importedFluff.source != null ? " (${importedFluff.source})" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
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

        // User Custom Notes Section
        Row(
          children: [
            Icon(Icons.edit_note, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Custom Notes & Campaign Lore',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Personal notes, roleplay hooks, or homebrew tweaks for this species. Saved locally automatically.',
          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Add roleplay notes, campaign lore, lineage heritage...',
            hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: _saveNotes,
        ),
      ],
    );
  }
}
