import 'package:flutter/material.dart';
import '../../models/characters/subclass_spells_library.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/feature_grant.dart';
import '../../models/domain/homebrew_extended_entities.dart';
import '../../models/spellbook_data.dart';
import '../../providers/settings_provider.dart';
import '../../services/fluff/entity_fluff_service.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';
import '../glyphs/dnd_glyph.dart';
import '../spellbook/spell_comparison_dialog.dart';

/// Comprehensive modal presenting complete class mechanics, proficiencies,
/// feature progression text, and subclass archetypes breakdown.
class ClassDetailDialog extends StatefulWidget {
  final CharacterClass characterClass;
  final bool isPinned;
  final VoidCallback onTogglePin;
  final DmRulesEdition? edition;

  const ClassDetailDialog({
    super.key,
    required this.characterClass,
    required this.isPinned,
    required this.onTogglePin,
    this.edition,
  });

  static Future<void> show(
    BuildContext context, {
    required CharacterClass characterClass,
    required bool isPinned,
    required VoidCallback onTogglePin,
    DmRulesEdition? edition,
  }) {
    HapticService.selectionTick(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => ClassDetailDialog(
        characterClass: characterClass,
        isPinned: isPinned,
        onTogglePin: onTogglePin,
        edition: edition,
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
  final TextEditingController _spellSearchController = TextEditingController();
  String _spellSearchQuery = '';
  int? _spellLevelFilter;
  List<SpellItem> _allClassSpells = [];
  final Map<String, String> _spellToSubclassMap = {};
  bool _hasSpells = false;

  @override
  void initState() {
    super.initState();
    _pinned = widget.isPinned;
    final existing = _fluffService.getUserNotes('class', widget.characterClass.id.slug) ?? '';
    _notesController = TextEditingController(text: existing);

    _initSpells(widget.edition);

    final tabCount = 1 +
        (widget.characterClass.subclasses.isNotEmpty ? 1 : 0) +
        (_hasSpells ? 1 : 0) +
        1;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentEdition = _resolveEdition(context);
    _initSpells(currentEdition);
  }

  DmRulesEdition _resolveEdition(BuildContext context) {
    return widget.edition ??
        SettingsScope.maybeOf(context)?.settings.rulesEdition ??
        DmRulesEdition.v2024;
  }

  void _initSpells([DmRulesEdition? resolvedEdition]) {
    final edition = resolvedEdition ?? widget.edition ?? DmRulesEdition.v2024;
    final cls = widget.characterClass;
    final slug = cls.id.slug.toLowerCase().trim();
    final spellClass = SpellClass.values.where(
      (sc) => sc.name.toLowerCase() == slug || sc.label.toLowerCase() == cls.name.toLowerCase().trim(),
    ).firstOrNull;

    final baseSpells = spellClass != null
        ? SpellbookLibrary.getSpellsByClass(spellClass, edition: edition)
        : <SpellItem>[];

    final allSpellsMap = <String, SpellItem>{};
    for (final s in baseSpells) {
      allSpellsMap[s.id.toLowerCase()] = s;
    }

    // Include subclass bonus spells
    for (final sub in cls.subclasses) {
      final bonusNames = <String>{};
      for (final g in sub.grants) {
        if (g.type == GrantType.bonusSpell) {
          final name = g.payload['displayName']?.toString() ?? g.label ?? g.payload['slug']?.toString();
          if (name != null && name.isNotEmpty) {
            bonusNames.add(name.toLowerCase());
          }
        }
      }
      final addSpells = sub.customProperties['additionalSpells'] ?? sub.customProperties['subclassSpells'];
      if (addSpells != null) {
        final names = FeatureGrant.extractSpellNames(addSpells);
        bonusNames.addAll(names.map((e) => e.toLowerCase()));
      }
      bonusNames.addAll(SubclassSpellsLibrary.getExpandedSpells(cls.id.slug, sub.id.slug));

      for (final bName in bonusNames) {
        final clean = bName.trim().toLowerCase();
        final found = SpellbookLibrary.findSpell(clean);
        if (found != null) {
          allSpellsMap[found.id.toLowerCase()] = found;
          _spellToSubclassMap[found.id.toLowerCase()] = sub.name;
        }
      }
    }

    _allClassSpells = allSpellsMap.values.toList()
      ..sort((a, b) {
        final lvlCmp = a.level.compareTo(b.level);
        if (lvlCmp != 0) return lvlCmp;
        return a.name.compareTo(b.name);
      });

    _hasSpells = _allClassSpells.isNotEmpty || cls.spellcastingAbility != null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _spellSearchController.dispose();
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
            _getSubclassLevelString(cls, _resolveEdition(context)),
          ),
        ],
      ),
    );
  }

  String _getSubclassLevelString(CharacterClass cls, DmRulesEdition edition) {
    final ruleset = edition == DmRulesEdition.v2024 ? RulesetVersion.v2024 : RulesetVersion.v2014;
    final level = cls.getSubclassLevel(ruleset);
    final slug = cls.id.slug.toLowerCase();
    if (edition == DmRulesEdition.v2014) {
      if (['cleric', 'sorcerer', 'warlock'].contains(slug)) {
        return 'Level 1 (2014 RAW)';
      }
      if (['druid', 'wizard'].contains(slug)) {
        return 'Level 2 (2014 RAW)';
      }
      return 'Level $level Archetype (2014 RAW)';
    }
    return 'Level $level (2024 Revision)';
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
    final resolvedClassType = DndClassType.tryParse(slug) ?? DndClassType.tryParse(cls.name);
    final pinColor = isDark ? Colors.purpleAccent : theme.colorScheme.secondary;

    final resolvedEdition = _resolveEdition(context);
    final is2024Mode = resolvedEdition == DmRulesEdition.v2024;
    final isHomebrew = cls.id.ruleset == RulesetVersion.homebrew;

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
            // Header: Class Glyph + Name + Pin + Close
            Row(
              children: [
                if (resolvedClassType != null)
                  DndGlyph.classFeature(
                    classType: resolvedClassType,
                    size: 44,
                    isDarkMode: isDark,
                  )
                else
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
                        '${cls.primaryAbility ?? "Custom"} • ${is2024Mode ? "2024 Revised Rules" : (isHomebrew ? "Custom Homebrew" : "2014 Classic Rules")}',
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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Class Features'),
                if (cls.subclasses.isNotEmpty) Tab(text: 'Subclasses (${cls.subclasses.length})'),
                if (_hasSpells) Tab(text: 'Spells (${_allClassSpells.length})'),
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
                  if (_hasSpells) _buildSpellsTab(context, accentColor),
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
    final is2024Mode = _resolveEdition(context) == DmRulesEdition.v2024;
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
                  if (is2024Mode && sub.id.ruleset == RulesetVersion.v2024)
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
              _buildSubclassSpellsChips(context, sub, accentColor),
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

  Widget _buildSubclassSpellsChips(BuildContext context, Subclass sub, Color accentColor) {
    final theme = Theme.of(context);
    final bonusSpellNames = <String>{};
    for (final g in sub.grants) {
      if (g.type == GrantType.bonusSpell) {
        final name = g.payload['displayName']?.toString() ?? g.label ?? g.payload['slug']?.toString();
        if (name != null && name.isNotEmpty) {
          bonusSpellNames.add(name);
        }
      }
    }
    final libExpanded = SubclassSpellsLibrary.getExpandedSpells(widget.characterClass.id.slug, sub.id.slug);
    for (final exp in libExpanded) {
      final cap = exp.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
      bonusSpellNames.add(cap);
    }

    final addSpells = sub.customProperties['additionalSpells'] ?? sub.customProperties['subclassSpells'];
    if (addSpells != null) {
      final names = FeatureGrant.extractSpellNames(addSpells);
      for (final n in names) {
        final cap = n.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
        bonusSpellNames.add(cap);
      }
    }

    if (bonusSpellNames.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedSpells = bonusSpellNames.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 13, color: accentColor),
                const SizedBox(width: 5),
                Text(
                  'SUBCLASS / BONUS SPELLS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: sortedSpells.map((spName) {
                final clean = spName.toLowerCase().trim();
                final foundSpell = SpellbookLibrary.findSpell(clean);
                final isPinned = foundSpell != null &&
                    (SettingsScope.maybeOf(context)?.settings.pinnedSpellIds.contains(foundSpell.id) ?? false);

                return ActionChip(
                  avatar: Icon(
                    Icons.auto_awesome,
                    size: 12,
                    color: foundSpell != null ? accentColor : Colors.grey,
                  ),
                  label: Text(
                    spName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                  onPressed: () {
                    if (foundSpell != null) {
                      SpellComparisonDialog.show(
                        context,
                        spell: foundSpell,
                        isPinned: isPinned,
                        onTogglePin: () {
                          SettingsScope.maybeOf(context)?.togglePinSpell(foundSpell.id);
                        },
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$spName — expanded spell granted by ${sub.name}. Full text available in spellbook.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellsTab(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final resolvedEdition = _resolveEdition(context);

    // Filter spells
    final filtered = _allClassSpells.where((s) {
      if (_spellSearchQuery.isNotEmpty) {
        final query = _spellSearchQuery.toLowerCase();
        final matchesName = s.name.toLowerCase().contains(query);
        final matchesSchool = s.school.label.toLowerCase().contains(query);
        final sub = _spellToSubclassMap[s.id.toLowerCase()];
        final matchesSub = sub != null && sub.toLowerCase().contains(query);
        if (!matchesName && !matchesSchool && !matchesSub) return false;
      }

      if (_spellLevelFilter != null) {
        if (_spellLevelFilter == -1) {
          if (!_spellToSubclassMap.containsKey(s.id.toLowerCase())) return false;
        } else if (s.level != _spellLevelFilter) {
          return false;
        }
      }
      return true;
    }).toList();

    // Collect available spell levels
    final availableLevels = <int>{};
    for (final s in _allClassSpells) {
      availableLevels.add(s.level);
    }
    final sortedLevels = availableLevels.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: TextField(
            controller: _spellSearchController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search ${widget.characterClass.name} spells, schools, or subclasses...',
              hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _spellSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => setState(() {
                        _spellSearchController.clear();
                        _spellSearchQuery = '';
                      }),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (val) => setState(() => _spellSearchQuery = val.trim().toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),

        // Level Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text('All (${_allClassSpells.length})'),
                selected: _spellLevelFilter == null,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _spellLevelFilter = null),
              ),
              const SizedBox(width: 6),
              if (_spellToSubclassMap.isNotEmpty) ...[
                FilterChip(
                  avatar: const Icon(Icons.auto_awesome, size: 12),
                  label: Text('Subclass (${_spellToSubclassMap.length})'),
                  selected: _spellLevelFilter == -1,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _spellLevelFilter = _spellLevelFilter == -1 ? null : -1),
                ),
                const SizedBox(width: 6),
              ],
              for (final lvl in sortedLevels) ...[
                FilterChip(
                  label: Text(lvl == 0 ? 'Cantrip' : 'Level $lvl'),
                  selected: _spellLevelFilter == lvl,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _spellLevelFilter = _spellLevelFilter == lvl ? null : lvl),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Spells List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_normal, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'No spells found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No spells match your current search or level filters.',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, idx) {
                    final spell = filtered[idx];
                    final subName = _spellToSubclassMap[spell.id.toLowerCase()];
                    final rules = spell.getRules(resolvedEdition);
                    final isPinned = SettingsScope.maybeOf(context)?.settings.pinnedSpellIds.contains(spell.id) ?? false;
                    final isHomebrew = spell.id.startsWith('custom_') || spell.tags.contains('homebrew');

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          SpellComparisonDialog.show(
                            context,
                            spell: spell,
                            isPinned: isPinned,
                            onTogglePin: () {
                              SettingsScope.maybeOf(context)?.togglePinSpell(spell.id);
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  spell.level == 0 ? 'C' : '${spell.level}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: accentColor,
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
                                        Expanded(
                                          child: Text(
                                            spell.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        if (subName != null)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: accentColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              subName,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                        if (isHomebrew)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Homebrew',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purpleAccent,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${spell.levelLabel} ${spell.school.label} • ${rules.castingTime} • ${rules.range}${rules.concentration ? " • Conc." : ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
