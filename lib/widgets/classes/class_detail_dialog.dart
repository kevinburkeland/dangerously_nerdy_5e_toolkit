import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../services/fluff/entity_fluff_service.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';

/// Comprehensive modal presenting complete class mechanics, proficiencies,
/// feature progression text, and subclass archetypes breakdown.
class ClassDetailDialog extends StatefulWidget {
  final CharacterClass characterClass;
  final bool isPinned;
  final VoidCallback onTogglePin;

  const ClassDetailDialog({
    super.key,
    required this.characterClass,
    required this.isPinned,
    required this.onTogglePin,
  });

  static Future<void> show(
    BuildContext context, {
    required CharacterClass characterClass,
    required bool isPinned,
    required VoidCallback onTogglePin,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => ClassDetailDialog(
        characterClass: characterClass,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
      ),
    );
  }

  @override
  State<ClassDetailDialog> createState() => _ClassDetailDialogState();
}

class _ClassDetailDialogState extends State<ClassDetailDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _pinned;
  late TextEditingController _notesController;
  final EntityFluffService _fluffService = EntityFluffService();

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
    final tabCount = widget.characterClass.subclasses.isNotEmpty ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);
    final existing = _fluffService.getUserNotes('class', widget.characterClass.id.slug) ?? '';
    _notesController = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handlePinToggle() {
    setState(() {
      _pinned = !_pinned;
    });
    widget.onTogglePin();
  }

  Color _getClassColor(String slug, bool isDark) {
    switch (slug.toLowerCase()) {
      case 'barbarian':
        return isDark ? const Color(0xFFFF5252) : const Color(0xFFC62828);
      case 'bard':
        return isDark ? const Color(0xFFFF4081) : const Color(0xFFC2185B);
      case 'cleric':
        return isDark ? const Color(0xFFFFD700) : const Color(0xFFF57F17);
      case 'druid':
        return isDark ? const Color(0xFF69F0AE) : const Color(0xFF2E7D32);
      case 'fighter':
        return isDark ? const Color(0xFFFF7043) : const Color(0xFFD84315);
      case 'monk':
        return isDark ? const Color(0xFF40C4FF) : const Color(0xFF0277BD);
      case 'paladin':
        return isDark ? const Color(0xFFFFAB40) : const Color(0xFFE65100);
      case 'ranger':
        return isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C);
      case 'rogue':
        return isDark ? const Color(0xFFB0BEC5) : const Color(0xFF455A64);
      case 'sorcerer':
        return isDark ? const Color(0xFFFF1744) : const Color(0xFFD50000);
      case 'warlock':
        return isDark ? const Color(0xFFBA68C8) : const Color(0xFF6A1B9A);
      case 'wizard':
        return isDark ? const Color(0xFF448AFF) : const Color(0xFF1565C0);
      case 'artificer':
        return isDark ? const Color(0xFF26A69A) : const Color(0xFF00695C);
      default:
        return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2);
    }
  }

  IconData _getClassIcon(String slug) {
    switch (slug.toLowerCase()) {
      case 'barbarian':
        return Icons.sports_kabaddi;
      case 'bard':
        return Icons.music_note;
      case 'cleric':
        return Icons.auto_awesome;
      case 'druid':
        return Icons.eco;
      case 'fighter':
        return Icons.shield;
      case 'monk':
        return Icons.sports_martial_arts;
      case 'paladin':
        return Icons.health_and_safety;
      case 'ranger':
        return Icons.nature_people;
      case 'rogue':
        return Icons.visibility_off;
      case 'sorcerer':
        return Icons.local_fire_department;
      case 'warlock':
        return Icons.dark_mode;
      case 'wizard':
        return Icons.auto_stories;
      case 'artificer':
        return Icons.build;
      default:
        return Icons.person;
    }
  }

  Widget _buildProficiencySection(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final cls = widget.characterClass;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLASS PROFICIENCIES & ATTRIBUTES',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildMetaRow('Hit Die', cls.hitDie),
          if (cls.primaryAbility != null) _buildMetaRow('Primary Ability', cls.primaryAbility!),
          if (cls.savingThrows.isNotEmpty) _buildMetaRow('Saving Throws', cls.savingThrows.join(', ')),
          if (cls.armorProficiencies.isNotEmpty) _buildMetaRow('Armor Training', cls.armorProficiencies.join(', ')),
          if (cls.weaponProficiencies.isNotEmpty) _buildMetaRow('Weapon Training', cls.weaponProficiencies.join(', ')),
          if (cls.spellcastingAbility != null) _buildMetaRow('Spellcasting', '${cls.spellcastingAbility} modifier'),
          _buildMetaRow(
            'Subclass Level',
            _getSubclassLevelString(cls.id.slug, cls.subclassSelectionLevel),
          ),
        ],
      ),
    );
  }

  String _getSubclassLevelString(String slug, int level) {
    switch (slug.toLowerCase()) {
      case 'cleric':
      case 'sorcerer':
      case 'warlock':
        return 'Level 3 (2024) • Level 1 (2014 RAW)';
      case 'druid':
      case 'wizard':
        return 'Level 3 (2024) • Level 2 (2014 RAW)';
      default:
        return 'Level $level Archetype';
    }
  }

  Widget _buildMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cls = widget.characterClass;
    final slug = cls.id.slug;
    final accentColor = _getClassColor(slug, isDark);
    final classIcon = _getClassIcon(slug);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    final isHomebrew = cls.id.ruleset == RulesetVersion.homebrew;
    final is2024 = cls.id.ruleset == RulesetVersion.v2024;

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 800),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Class Icon + Name + Pin + Close
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withValues(alpha: 0.6)),
                  ),
                  child: Icon(classIcon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls.name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${cls.primaryAbility ?? "Custom"} • ${is2024 ? "2024 Revised Rules" : (isHomebrew ? "Custom Homebrew" : "2014 Classic Rules")}',
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
            const SizedBox(height: 10),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: 'Class Features'),
                if (cls.subclasses.isNotEmpty) Tab(text: 'Subclasses (${cls.subclasses.length})'),
                const Tab(text: 'Lore & Notes'),
              ],
            ),
            const SizedBox(height: 12),

            // Tab view content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFeaturesTab(context, accentColor),
                  if (cls.subclasses.isNotEmpty) _buildSubclassesTab(context, accentColor),
                  _buildLoreNotesTab(context, accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesTab(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final cls = widget.characterClass;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProficiencySection(context, accentColor),
          const SizedBox(height: 14),

          Text(
            'CORE CLASS FEATURES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),

          FormattedMarkdownText(
            cls.featuresMarkdown,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubclassesTab(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subclasses = widget.characterClass.subclasses;

    return ListView.separated(
      itemCount: subclasses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final sub = subclasses[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (sub.id.ruleset == RulesetVersion.v2024)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '2024',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                sub.featuresMarkdown,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoreNotesTab(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final slug = widget.characterClass.id.slug;
    final importedFluff = _fluffService.getFluff('class', slug);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
              'Custom Class Notes & Build Ideas',
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
          'Multiclassing plans, spell selection tips, or subclass preferences. Saved locally automatically.',
          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesController,
          maxLines: 7,
          decoration: InputDecoration(
            hintText: 'Add class build notes, multiclass synergy, favored spells...',
            hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: accentColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          onChanged: (val) => _fluffService.setUserNotes('class', slug, val),
        ),
      ],
    );
  }
}
