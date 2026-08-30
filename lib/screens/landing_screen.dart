import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/landing_tool_item.dart';
import '../models/party/campaign_membership.dart';
import '../models/spellbook_data.dart';
import '../providers/settings_provider.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../services/haptic_service.dart';
import '../services/party/campaign_registry_service.dart';
import '../utils/pwa_helper.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/interactive/pressable_card.dart';
import '../widgets/dialogs/legal_dialogs.dart';
import '../widgets/app_logo.dart';
import '../widgets/glyphs/dnd_glyph.dart';
import '../widgets/party/campaign_dialogs.dart';
import '../widgets/room_banner_widget.dart';
import 'character_builder_screen.dart';
import 'dice_roller_screen.dart';
import 'dm_reference_screen.dart';
import 'dpr_calculator_screen.dart';
import 'glyph_showcase_screen.dart';
import 'item_compendium_screen.dart';
import 'monster_codex_screen.dart';
import 'party_room_screen.dart';
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
            icon: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary),
            tooltip: "Rules Compendium (SRD 5.1 / 5.2)",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RulesCompendiumScreen()),
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
                        const SizedBox(height: 14),
                        _buildHeroGlyphBadges(context, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildCampaignHubSection(context, isDark),
                  const SizedBox(height: 16),
                  RoomBannerWidget(),
                  const SizedBox(height: 16),

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
                      'SEARCH RESULTS (${searchResults.length})',
                      theme.colorScheme.primary,
                      glyph: DndGlyph.spell(
                        school: SpellSchool.divination,
                        level: 0,
                        size: 20,
                        isDarkMode: isDark,
                      ),
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
                      'CORE UTILITIES',
                      theme.colorScheme.primary,
                      glyph: DndGlyph.spell(
                        school: SpellSchool.divination,
                        level: 1,
                        glyphColor: theme.colorScheme.primary,
                        size: 20,
                        isDarkMode: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Core Utilities')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 2: TOOLS FOR NERDS (COMBAT MATH, THEORYCRAFT & DPS)
                    _buildSectionHeader(
                      'TOOLS FOR NERDS',
                      isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                      glyph: DndGlyph.item(
                        category: ItemCategory.weapon,
                        rarity: ItemRarity.rare,
                        damageAccent: DamageAccent.force,
                        glyphColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
                        size: 20,
                        isDarkMode: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Tools for Nerds')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 3: SPELL MINION COMPANIONS (ANIMATE OBJECTS & CONJURE SPELLS)
                    _buildSectionHeader(
                      'SPELL MINION COMPANIONS',
                      theme.colorScheme.secondary,
                      glyph: DndGlyph.spell(
                        school: SpellSchool.conjuration,
                        level: 3,
                        glyphColor: theme.colorScheme.secondary,
                        size: 20,
                        isDarkMode: isDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildToolGrid(
                      context,
                      children: _tools
                          .where((t) => t.category == 'Spell Minion Companions')
                          .map((tool) => _buildToolCardFromItem(context, tool))
                          .toList(),
                    ),

                    const SizedBox(height: 28),

                    // CATEGORY 4: MAGIC ITEMS & SUMMONING ARTIFACTS
                    _buildSectionHeader(
                      'MAGIC ITEM ROLLERS & MINIONS',
                      isDark ? Colors.amberAccent : const Color(0xFFB45309),
                      glyph: DndGlyph.item(
                        category: ItemCategory.wondrousItem,
                        rarity: ItemRarity.rare,
                        glyphColor: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                        size: 20,
                        isDarkMode: isDark,
                      ),
                    ),
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

                    // CATEGORY 5: ART & DESIGN TOOLS (SUBSECTION AT BOTTOM)
                    _buildSectionHeader(
                      'ART & DESIGN TOOLS',
                      isDark
                          ? const Color(0xFFC084FC)
                          : const Color(0xFF7E22CE),
                      glyph: DndGlyph.spell(
                        school: SpellSchool.divination,
                        level: 9,
                        glyphColor: isDark
                            ? const Color(0xFFC084FC)
                            : const Color(0xFF7E22CE),
                        size: 20,
                        isDarkMode: isDark,
                      ),
                    ),
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

  Widget _buildHeroGlyphBadges(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickGlyphBadge(
            context,
            label: 'Spellbook',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.spell(
                    school: SpellSchool.evocation,
                    level: 3,
                    damageAccent: DamageAccent.fire,
                    glyphColor: Colors.purpleAccent,
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SpellbookScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Bestiary Codex',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.monster(
                    creatureType: CreatureType.dragon,
                    crTier: 3,
                    glyphColor: Colors.greenAccent,
                    actionRings: const [
                      ActionTraitRing(
                          ringType: ActionRingType.recharge,
                          damageType: DamageAccent.fire),
                    ],
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MonsterCodexScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Magic Items',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.item(
                    category: ItemCategory.wondrousItem,
                    rarity: ItemRarity.veryRare,
                    requiresAttunement: true,
                    glyphColor: Colors.tealAccent,
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ItemCompendiumScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Character Studio',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.classFeature(
                    classType: DndClassType.fighter,
                    glyphColor: Colors.amberAccent,
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CharacterBuilderScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Combat DPR',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.item(
                    category: ItemCategory.weapon,
                    rarity: ItemRarity.rare,
                    damageAccent: DamageAccent.force,
                    glyphColor: Colors.cyanAccent,
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DprCalculatorScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Dice & Party',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.genericUi(
                    uiType: GenericUiGlyphType.d20,
                    glyphColor: Colors.cyanAccent,
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiceRollerScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickGlyphBadge(
            context,
            label: 'Glyph Studio',
            glyph: RepaintBoundary(
              child: SizedBox(
                width: 24,
                height: 24,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: DndGlyph.spell(
                    school: SpellSchool.divination,
                    level: 9,
                    glyphColor: const Color(0xFFC084FC),
                    size: 24,
                    isDarkMode: isDark,
                  ),
                ),
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GlyphShowcaseScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGlyphBadge(
    BuildContext context, {
    required String label,
    required Widget glyph,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticService.selectionTick(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, {Widget? glyph}) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              glyph,
              const SizedBox(width: 8),
            ],
            Flexible(
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
          ],
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

    const spellGlyphIdsByToolId = <String, String>{
      'animate_objects': 'spell_animate_objects',
      'conjure_animals': 'spell_conjure_animals',
      'animate_dead': 'spell_animate_dead',
      'create_undead': 'spell_create_undead',
      'conjure_elementals': 'spell_conjure_elemental',
      'conjure_elemental': 'spell_conjure_elemental',
      'conjure_minor_elementals': 'spell_conjure_minor_elementals',
      'giant_insect': 'spell_giant_insect',
    };

    final activeEdition = SettingsScope.maybeOf(context)?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final spellId = spellGlyphIdsByToolId[item.id];
    if (spellId != null) {
      final spell = SpellbookLibrary.getSpellById(spellId);
      if (spell != null) {
        glyphWidget = DndGlyph.spell(
          school: spell.getSchool(activeEdition),
          level: spell.level,
          glyphColor: item.accentColor,
          actionRings: spell.getGlyphActionRings(activeEdition),
          damageAccent: spell.getGlyphPrimaryDamageAccent(activeEdition),
          size: 42,
          isDarkMode: isDark,
        );
      }
    }

    // Check for Magic Item or Spell Summon presets
    if (glyphWidget == null) {
      final summonPreset = SrdSummonsLibrary.allPresets.cast<SummonPreset?>().firstWhere(
        (p) => p?.id == item.id,
        orElse: () => null,
      );
      if (summonPreset != null) {
        glyphWidget = summonPreset.buildGlyph(
          size: 42,
          isDarkMode: isDark,
          glyphColor: item.accentColor,
        );
      }
    }

    if (glyphWidget == null) {
      switch (item.id) {
        case 'dice_roller':
          glyphWidget = DndGlyph.genericUi(
            uiType: GenericUiGlyphType.d20,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'character_builder':
          glyphWidget = DndGlyph.classFeature(
            classType: DndClassType.fighter,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.hitDie, label: 'd10 Hit Die'),
              ActionTraitRing(ringType: ActionRingType.resource, label: 'Second Wind'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'dpr_calculator':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.weapon,
            rarity: ItemRarity.veryRare,
            damageAccent: DamageAccent.force,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.force, label: 'DPS & Graph'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'party_room':
          glyphWidget = DndGlyph.species(
            speciesType: SpeciesType.human,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.passive, label: 'Party Sync'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'homebrew_studio':
          glyphWidget = DndGlyph.genericUi(
            uiType: GenericUiGlyphType.d100,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'dm_screen':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.armor,
            rarity: ItemRarity.rare,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.legendary, label: '2014 & 2024 Rules'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'srd_spellbook':
          glyphWidget = DndGlyph.spell(
            school: SpellSchool.evocation,
            level: 3,
            glyphColor: item.accentColor,
            damageAccent: DamageAccent.fire,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: 'Fireball & 2024 Diffs'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'monster_codex':
          glyphWidget = DndGlyph.monster(
            creatureType: CreatureType.dragon,
            crTier: 3,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: 'SRD Bestiary'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'monster_arena':
          glyphWidget = DndGlyph.monster(
            creatureType: CreatureType.monstrosity,
            crTier: 4,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.legendary, damageType: DamageAccent.slashing, label: 'Pit Fight Simulator'),
              ActionTraitRing(ringType: ActionRingType.recharge, label: 'Monte Carlo Win Odds'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'item_compendium':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.legendary,
            requiresAttunement: true,
            glyphColor: item.accentColor,
            damageAccent: DamageAccent.radiant,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.attunement, label: 'Attunement & Crafting'),
              ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.radiant, label: 'Reliquary'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'glyph_studio':
          glyphWidget = DndGlyph.spell(
            school: SpellSchool.divination,
            level: 9,
            glyphColor: item.accentColor,
            actionRings: const [
              ActionTraitRing(ringType: ActionRingType.legendary, label: 'Techno-Rune Studio'),
            ],
            size: 42,
            isDarkMode: isDark,
          );
        case 'gray_bag':
        case 'rust_bag':
        case 'tan_bag':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.uncommon,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'horn_of_valhalla_silver':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.rare,
            damageAccent: DamageAccent.slashing,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'horn_of_valhalla_brass':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.rare,
            damageAccent: DamageAccent.slashing,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'horn_of_valhalla_bronze':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.veryRare,
            damageAccent: DamageAccent.slashing,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'horn_of_valhalla_iron':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.legendary,
            damageAccent: DamageAccent.slashing,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
        case 'figurines_of_wondrous_power':
          glyphWidget = DndGlyph.item(
            category: ItemCategory.wondrousItem,
            rarity: ItemRarity.rare,
            glyphColor: item.accentColor,
            size: 42,
            isDarkMode: isDark,
          );
      }
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
                RepaintBoundary(child: glyphWidget)
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

  Widget _buildCampaignHubSection(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final registry = CampaignRegistryService();

    return ValueListenableBuilder<List<CampaignMembership>>(
      valueListenable: registry.membershipsNotifier,
      builder: (context, memberships, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF191D2B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_moon_outlined, color: colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ACTIVE CAMPAIGNS & PARTY ROOMS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.1,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create New Campaign', style: TextStyle(fontSize: 12)),
                    onPressed: () => CreateCampaignDialog.show(
                      context,
                      onCreated: (code) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PartyRoomScreen(roomCode: code)),
                        );
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Join Campaign', style: TextStyle(fontSize: 12)),
                    onPressed: () => JoinCampaignDialog.show(
                      context,
                      onJoined: (code) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PartyRoomScreen(roomCode: code)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (memberships.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hub_outlined, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No Active Campaigns Connected',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create a campaign room to track party loot, coins, and dice rolls, or join with a room code from your DM.',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: memberships.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final m = memberships[index];
                      return _buildCampaignCard(context, m, isDark);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaignCard(BuildContext context, CampaignMembership m, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color badgeColor = Colors.blue;
    String badgeText = 'Player';
    if (m.role == CampaignRole.host) {
      badgeColor = Colors.amber.shade700;
      badgeText = 'DM';
    } else if (m.role == CampaignRole.coDm) {
      badgeColor = Colors.orange;
      badgeText = 'Co-DM';
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      color: isDark ? const Color(0xFF222738) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticService.selectionTick(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PartyRoomScreen(roomCode: m.roomCode),
            ),
          );
        },
        onLongPress: () {
          HapticService.selectionTick(context);
          if (m.role == CampaignRole.player) {
            ClaimDmPasskeyDialog.show(
              context,
              initialRoomCode: m.roomCode,
              initialPlayerName: m.characterId,
            );
          } else if (m.hasHostKey) {
            ShareDmPasskeyDialog.show(context, m);
          }
        },
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      m.roomCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: colorScheme.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                m.campaignName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatLastPlayed(m.lastPlayed),
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastPlayed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
