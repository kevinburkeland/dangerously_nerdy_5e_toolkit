import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/landing_tool_item.dart';
import '../models/spellbook_data.dart';
import '../services/haptic_service.dart';
import '../utils/pwa_helper.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/interactive/pressable_card.dart';
import '../widgets/dialogs/legal_dialogs.dart';
import '../widgets/app_logo.dart';
import '../widgets/glyphs/dnd_glyph.dart';
import 'dm_reference_screen.dart';
import 'settings_screen.dart';
import 'spellbook_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final List<LandingToolItem> _tools;

  @override
  void initState() {
    super.initState();
    _tools = LandingToolRegistry.defaultTools;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _clearSearch() {
    HapticService.selectionTick(context);
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim();
    final isSearching = query.isNotEmpty;
    final searchResults = _tools.where((t) => t.matches(query)).toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 32),
            const SizedBox(width: 10),
            Flexible(
              child: Semantics(
                header: true,
                child: const Text(
                  'DangerouslyNerdy 5e Toolkit',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu_book, color: theme.colorScheme.secondary),
            tooltip: 'Spellbook Companion',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SpellbookScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.shield_outlined, color: theme.colorScheme.primary),
            tooltip: "DM's Screen & Rulebook (2014 / 2024)",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DmReferenceScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Preferences & Theme Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Quick References & More',
            onSelected: (val) {
              if (val == 'economy') ActionEconomyDialog.show(context);
              if (val == 'conditions') ConditionReferenceDialog.show(context);
              if (val == 'install') PwaHelper.promptInstall();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'economy',
                child: Row(
                  children: [
                    Icon(Icons.flash_on_outlined,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Text('Action Economy Guide'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'conditions',
                child: Row(
                  children: [
                    Icon(Icons.medical_information_outlined,
                        color: theme.colorScheme.secondary, size: 20),
                    const SizedBox(width: 10),
                    const Text('Status Effects & Conditions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'install',
                child: Row(
                  children: [
                    Icon(Icons.download_for_offline,
                        color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    const Text('Install PWA App'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppLogo(
                              size: 68,
                              showGlow: true,
                              showRings: true,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Select a Tool',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Choose from the DangerouslyNerdy suite of dedicated 5th Edition (5e) compatible player tools designed for minion combat management, magic item rollers, dice math, and live party rooms.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.75),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // HIGH-CONTRAST SEARCH BAR
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSearching
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSearching
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface, fontSize: 15),
                      cursorColor: theme.colorScheme.primary,
                      decoration: InputDecoration(
                        hintText:
                            'Search tools, spells, summons (e.g. wolves, dice, undead, bag)...',
                        hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: theme.colorScheme.primary, size: 22),
                        suffixIcon: isSearching
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    size: 20),
                                tooltip: 'Clear Search',
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (isSearching) ...[
                    // SEARCH RESULTS SECTION
                    _buildSectionHeader(
                      '🔍 SEARCH RESULTS (${searchResults.length})',
                      theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    if (searchResults.isNotEmpty)
                      _buildToolGrid(
                        context,
                        children: searchResults
                            .map(
                                (tool) => _buildToolCardFromItem(context, tool))
                            .toList(),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.search_off,
                                size: 48,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'No tools found matching "$query"',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Try searching for spells, monsters, or dice keywords.',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.clear, size: 18),
                              label: const Text('Clear Search',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    // CATEGORY 1: GENERAL UTILITIES (CORE APP AT TOP)
                    _buildSectionHeader(
                        '🎲 CORE UTILITIES', theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Core Utilities')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 2: SPELL MINION COMPANIONS (ANIMATE OBJECTS & CONJURE SPELLS)
                    _buildSectionHeader('🔮 SPELL MINION COMPANIONS',
                        theme.colorScheme.secondary),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Spell Minion Companions')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 3: MAGIC ITEMS & SUMMONING ARTIFACTS
                    _buildSectionHeader('📯 MAGIC ITEM ROLLERS & MINIONS',
                        isDark ? Colors.amberAccent : const Color(0xFFB45309)),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) =>
                              t.category == 'Magic Item Rollers & Minions')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 4: ART & DESIGN TOOLS (SUBSECTION AT BOTTOM)
                    _buildSectionHeader(
                        '🎨 ART & DESIGN TOOLS',
                        isDark
                            ? const Color(0xFFC084FC)
                            : const Color(0xFF7E22CE)),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Art & Design Tools')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // FOOTER
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'DangerouslyNerdy 5e Toolkit • D&D 5e / SRD 5.1 Compatible Combat System',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  LegalDialogs.showPrivacyPolicy(context),
                              child: Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  LegalDialogs.showTermsOfService(context),
                              child: Text(
                                'Terms of Service',
                                style: TextStyle(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  LegalDialogs.showAttribution(context),
                              child: Text(
                                'Legal & SRD 5.1 Attribution',
                                style: TextStyle(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.8),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildToolGrid(BuildContext context,
      {required List<Widget> children}) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth =
            (constraints.maxWidth - ((crossAxisCount - 1) * 16)) /
                crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildToolCardFromItem(BuildContext context, LandingToolItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget? glyphWidget;

    String? spellIdForTool(String id) {
      switch (id) {
        case 'animate_objects':
          return 'spell_animate_objects';
        case 'conjure_animals':
          return 'spell_conjure_animals';
        case 'animate_dead':
          return 'spell_animate_dead';
        case 'create_undead':
          return 'spell_create_undead';
        case 'conjure_elementals':
        case 'conjure_elemental':
          return 'spell_conjure_elemental';
        case 'conjure_minor_elementals':
          return 'spell_conjure_minor_elementals';
        case 'giant_insect':
          return 'spell_giant_insect';
      }
      return null;
    }

    final spellId = spellIdForTool(item.id);
    if (spellId != null) {
      final spell = SpellbookLibrary.getSpellById(spellId);
      if (spell != null) {
        glyphWidget = DndGlyph.spell(
          school: spell.getSchool(DmRulesEdition.v2024),
          level: spell.level,
          actionRings: spell.getGlyphActionRings(DmRulesEdition.v2024),
          damageAccent: spell.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024),
          size: 40,
          isDarkMode: isDark,
        );
      }
    }

    switch (item.id) {
      case 'glyph_studio':
        glyphWidget = DndGlyph.spell(
          school: SpellSchool.divination,
          level: 9,
          size: 40,
          isDarkMode: isDark,
        );
    }

    return _buildToolCard(
      context,
      title: item.title,
      badgeText: item.badgeText,
      badgeColor: item.getLegibleBadge(isDark),
      icon: item.icon,
      accentColor: item.getLegibleAccent(isDark),
      description: item.description,
      glyphWidget: glyphWidget,
      onTap: () {
        HapticService.selectionTick(context);
        item.onLaunch(context);
      },
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color accentColor,
    required String description,
    Widget? glyphWidget,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return PressableCard(
      onTap: onTap,
      semanticLabel: '$title, $badgeText. $description. Tap to launch tool.',
      excludeChildSemantics: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (glyphWidget != null)
                glyphWidget
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Launch Tool',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: accentColor, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}
