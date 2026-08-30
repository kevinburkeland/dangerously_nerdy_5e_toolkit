import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dm_screen_data.dart';
import '../models/glyph_gallery_data.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import '../widgets/glyphs/dnd_glyph.dart';

/// Dynamic D&D Glyph Gallery: Spells, Minions, Items, Feats, Classes, Species, Generic UI & Studio.
class GlyphShowcaseScreen extends StatefulWidget {
  const GlyphShowcaseScreen({super.key});

  @override
  State<GlyphShowcaseScreen> createState() => _GlyphShowcaseScreenState();
}

class _GlyphShowcaseScreenState extends State<GlyphShowcaseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Rules Edition State
  DmRulesEdition? _localEditionOverride;

  // Gallery Filters
  SpellSchool? _selectedSchool;
  CreatureType? _selectedCreatureType;
  ItemCategory? _selectedItemCategory;
  FeatCategory? _selectedFeatCategory;
  DndClassType? _selectedClassType;
  SpeciesType? _selectedSpeciesType;
  String? _selectedGenericGroup;

  bool? _overrideDarkMode;
  double _glyphDisplaySize = 68.0;

  // ---------------------------------------------------------------------------
  // CUSTOM BUILDER STATE
  // ---------------------------------------------------------------------------
  int _builderMode = 0; // 0: Spell, 1: Creature, 2: Magic Item, 3: Feat, 4: Class, 5: Species, 6: Generic UI
  SpellSchool _builderSchool = SpellSchool.evocation;
  CreatureType _builderCreature = CreatureType.dragon;
  ItemCategory _builderItemCategory = ItemCategory.weapon;
  ItemRarity _builderItemRarity = ItemRarity.rare;
  bool _builderItemRequiresAttunement = true;
  FeatCategory _builderFeatCategory = FeatCategory.general;
  String _builderFeatId = 'feat_war_caster';
  DndClassType _builderClassType = DndClassType.fighter;
  SpeciesType _builderSpeciesType = SpeciesType.elf;
  GenericUiGlyphType _builderGenericUiType = GenericUiGlyphType.d20;
  int _builderLevelOrTier = 3;
  GlyphFrameShape? _builderShapeOverride;
  final double _builderSize = 88.0;
  List<ActionTraitRing> _builderRings = [
    const ActionTraitRing(
        ringType: ActionRingType.melee,
        damageType: DamageAccent.fire,
        label: 'Primary Attack'),
    const ActionTraitRing(
        ringType: ActionRingType.recharge,
        damageType: DamageAccent.fire,
        label: 'Breath Weapon'),
  ];
  final GlobalKey _glyphBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onEditionChanged(BuildContext context, DmRulesEdition newEdition) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final current = _localEditionOverride ??
        settingsProvider?.settings.rulesEdition ??
        DmRulesEdition.v2024;
    if (current == newEdition) return;
    HapticService.selectionTick(context);
    setState(() {
      _localEditionOverride = newEdition;
    });
    settingsProvider?.setRulesEdition(newEdition);
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ??
        settingsProvider?.settings.rulesEdition ??
        DmRulesEdition.v2024;

    final isDark =
        _overrideDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    return Theme(
      data: isDark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.terminal, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text('D&D Glyph Studio & Codex'),
            ],
          ),
          actions: [
            RulesEditionToggle(
              currentEdition: edition,
              onEditionChanged: (newEdition) =>
                  _onEditionChanged(context, newEdition),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip:
                  isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  _overrideDarkMode = !isDark;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(icon: Icon(Icons.memory), text: 'Spellbook Schematics'),
              const Tab(icon: Icon(Icons.hub), text: 'Minion & Summon Matrix'),
              const Tab(icon: Icon(Icons.shield_outlined), text: 'Magic Items'),
              const Tab(icon: Icon(Icons.stars_outlined), text: 'Feats & Boons'),
              const Tab(icon: Icon(Icons.shield), text: 'Classes & Hit Dice'),
              Tab(
                icon: const Icon(Icons.groups_outlined),
                text: edition == DmRulesEdition.v2014
                    ? 'Races & Heritages'
                    : 'Species & Heritages',
              ),
              const Tab(icon: Icon(Icons.widgets_outlined), text: 'Generic UI & Dice'),
              const Tab(icon: Icon(Icons.build_circle), text: 'Custom Glyph Studio'),
              const Tab(icon: Icon(Icons.architecture), text: 'Full Style Guide Codex'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_tabController.index < 7)
              _buildSearchAndFilters(isDark, edition),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSpellsGallery(isDark, edition),
                  _buildCreaturesGallery(isDark, edition),
                  _buildItemsGallery(isDark, edition),
                  _buildFeatsGallery(isDark, edition),
                  _buildClassesGallery(isDark, edition),
                  _buildSpeciesGallery(isDark, edition),
                  _buildGenericUiGallery(isDark, edition),
                  _buildCustomBuilder(isDark, edition),
                  _buildFullStyleGuide(isDark, edition),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark, DmRulesEdition edition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? const Color(0xFF030712) : const Color(0xFFF1F5F9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Search spells, minions, items, feats, classes, species, dice...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 52.0, label: Text('Compact')),
                  ButtonSegment(value: 68.0, label: Text('HUD View')),
                ],
                selected: {_glyphDisplaySize},
                onSelectionChanged: (set) =>
                    setState(() => _glyphDisplaySize = set.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              final activeTab = _tabController.index;
              if (activeTab == 0) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Schools'),
                        selected: _selectedSchool == null,
                        onSelected: (_) =>
                            setState(() => _selectedSchool = null),
                      ),
                      const SizedBox(width: 6),
                      ...SpellSchool.values.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: s.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text(s.displayName),
                            selected: _selectedSchool == s,
                            onSelected: (sel) => setState(
                                () => _selectedSchool = sel ? s : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 1) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Minion Types'),
                        selected: _selectedCreatureType == null,
                        onSelected: (_) =>
                            setState(() => _selectedCreatureType = null),
                      ),
                      const SizedBox(width: 6),
                      ...CreatureType.values.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: t.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text(t.displayName),
                            selected: _selectedCreatureType == t,
                            onSelected: (sel) => setState(
                                () => _selectedCreatureType = sel ? t : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 2) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Item Categories'),
                        selected: _selectedItemCategory == null,
                        onSelected: (_) =>
                            setState(() => _selectedItemCategory = null),
                      ),
                      const SizedBox(width: 6),
                      ...ItemCategory.values.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: c.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text(c.displayName),
                            selected: _selectedItemCategory == c,
                            onSelected: (sel) => setState(
                                () => _selectedItemCategory = sel ? c : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 3) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Feat Tiers'),
                        selected: _selectedFeatCategory == null,
                        onSelected: (_) =>
                            setState(() => _selectedFeatCategory = null),
                      ),
                      const SizedBox(width: 6),
                      ...FeatCategory.values.where((fc) {
                        if (edition == DmRulesEdition.v2014 && fc == FeatCategory.origin) {
                          return false;
                        }
                        return true;
                      }).map(
                        (fc) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: fc.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text(fc.displayName),
                            selected: _selectedFeatCategory == fc,
                            onSelected: (sel) => setState(
                                () => _selectedFeatCategory = sel ? fc : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 4) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Classes'),
                        selected: _selectedClassType == null,
                        onSelected: (_) =>
                            setState(() => _selectedClassType = null),
                      ),
                      const SizedBox(width: 6),
                      ...DndClassType.values.map(
                        (ct) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: ct.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text('${ct.displayName} (d${ct.hitDieSides})'),
                            selected: _selectedClassType == ct,
                            onSelected: (sel) => setState(
                                () => _selectedClassType = sel ? ct : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 5) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text(edition == DmRulesEdition.v2014
                            ? 'All Races'
                            : 'All Species'),
                        selected: _selectedSpeciesType == null,
                        onSelected: (_) =>
                            setState(() => _selectedSpeciesType = null),
                      ),
                      const SizedBox(width: 6),
                      ...SpeciesType.values.map(
                        (st) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: st.getLegibleColor(isDark),
                                    shape: BoxShape.circle)),
                            label: Text(st.displayName),
                            selected: _selectedSpeciesType == st,
                            onSelected: (sel) => setState(
                                () => _selectedSpeciesType = sel ? st : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (activeTab == 6) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All UI Glyphs'),
                        selected: _selectedGenericGroup == null,
                        onSelected: (_) =>
                            setState(() => _selectedGenericGroup = null),
                      ),
                      const SizedBox(width: 6),
                      ...['Dice Polyhedrals', 'Status HUD Badges', 'Action Economy'].map(
                        (grp) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(grp),
                            selected: _selectedGenericGroup == grp,
                            onSelected: (sel) => setState(
                                () => _selectedGenericGroup = sel ? grp : null),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SPELLS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildSpellsGallery(bool isDark, DmRulesEdition edition) {
    var spells = GlyphGalleryData.allSpells.where((s) {
      if (_selectedSchool != null && s.school != _selectedSchool) return false;
      if (_searchQuery.isNotEmpty) {
        final match = s.name.toLowerCase().contains(_searchQuery) ||
            s.school.displayName.toLowerCase().contains(_searchQuery) ||
            s.summary.toLowerCase().contains(_searchQuery) ||
            s.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                r.damageLegend.toLowerCase().contains(_searchQuery) ||
                (r.label?.toLowerCase().contains(_searchQuery) ?? false));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (spells.isEmpty) {
      return _buildEmptyState('No spells matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: spells.length,
      itemBuilder: (context, idx) => _buildSpellCard(spells[idx], isDark),
    );
  }

  Widget _buildSpellCard(GlyphSpellEntry spell, bool isDark) {
    final schoolColor = spell.school.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: schoolColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSpellDetails(spell, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.spell(
                school: spell.school,
                level: spell.level,
                actionRings: spell.actionRings,
                damageAccent: spell.damageAccent,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                spell.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: schoolColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: schoolColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '[LV-${spell.level.toString().padLeft(2, '0')}]',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: schoolColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              spell.school.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: schoolColor,
                              ),
                            ),
                            Text(
                              '// ${spell.school.frameShape.name.toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      spell.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: spell.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(schoolColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: ringColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.damageLegend.isNotEmpty
                                      ? '${r.ringType.displayName} (${r.damageLegend})'
                                      : r.ringType.displayName,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: ringColor,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. CREATURES & MINIONS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildCreaturesGallery(bool isDark, DmRulesEdition edition) {
    var creatures = GlyphGalleryData.allCreatures.where((c) {
      if (_selectedCreatureType != null && c.type != _selectedCreatureType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = c.name.toLowerCase().contains(_searchQuery) ||
            c.type.displayName.toLowerCase().contains(_searchQuery) ||
            c.primaryAttack.toLowerCase().contains(_searchQuery) ||
            c.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                r.damageLegend.toLowerCase().contains(_searchQuery) ||
                (r.label?.toLowerCase().contains(_searchQuery) ?? false));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (creatures.isEmpty) {
      return _buildEmptyState('No summons matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: creatures.length,
      itemBuilder: (context, idx) =>
          _buildCreatureCard(creatures[idx], isDark),
    );
  }

  Widget _buildCreatureCard(GlyphCreatureEntry creature, bool isDark) {
    final typeColor = creature.type.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: typeColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCreatureDetails(creature, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.monster(
                creatureType: creature.type,
                crTier: creature.crTier,
                actionRings: creature.actionRings,
                actionBadge: creature.actionBadge,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                creature.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: typeColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '[CR ${creature.cr}]',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              creature.type.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                            Text(
                              '// ${creature.type.frameShape.name.toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color:
                                      isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      creature.primaryAttack,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: creature.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(typeColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: ringColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.damageLegend.isNotEmpty
                                      ? '${r.ringType.displayName} (${r.damageLegend})'
                                      : r.ringType.displayName,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: ringColor,
                                      fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. MAGIC ITEMS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildItemsGallery(bool isDark, DmRulesEdition edition) {
    var items = GlyphGalleryData.allItems.where((i) {
      if (_selectedItemCategory != null && i.category != _selectedItemCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = i.name.toLowerCase().contains(_searchQuery) ||
            i.category.displayName.toLowerCase().contains(_searchQuery) ||
            i.rarity.displayName.toLowerCase().contains(_searchQuery) ||
            i.summary.toLowerCase().contains(_searchQuery) ||
            i.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                (r.label?.toLowerCase().contains(_searchQuery) ?? false));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (items.isEmpty) {
      return _buildEmptyState('No magic items matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) => _buildItemCard(items[idx], isDark),
    );
  }

  Widget _buildItemCard(GlyphItemEntry item, bool isDark) {
    final catColor = item.category.getLegibleColor(isDark);
    final rarityColor = item.rarity.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: rarityColor.withValues(alpha: 0.65), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showItemDetails(item, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.item(
                category: item.category,
                rarity: item.rarity,
                requiresAttunement: item.requiresAttunement,
                actionRings: item.actionRings,
                damageAccent: item.damageAccent,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: rarityColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: rarityColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                item.rarity.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: rarityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          children: [
                            Text(
                              item.category.displayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                            if (item.requiresAttunement)
                              const Text(
                                '• ATTUNEMENT',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.cyanAccent),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      item.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: item.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(rarityColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              r.label ?? r.ringType.displayName,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ringColor,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. FEATS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildFeatsGallery(bool isDark, DmRulesEdition edition) {
    var feats = GlyphGalleryData.allFeats.where((f) {
      if (edition == DmRulesEdition.v2014 && f.featCategory == FeatCategory.origin) {
        return false;
      }
      if (_selectedFeatCategory != null &&
          f.featCategory != _selectedFeatCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = f.name.toLowerCase().contains(_searchQuery) ||
            f.featCategory.displayName.toLowerCase().contains(_searchQuery) ||
            f.summary.toLowerCase().contains(_searchQuery) ||
            (f.prerequisite?.toLowerCase().contains(_searchQuery) ?? false) ||
            f.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                (r.label?.toLowerCase().contains(_searchQuery) ?? false));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (feats.isEmpty) {
      return _buildEmptyState('No feats matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: feats.length,
      itemBuilder: (context, idx) => _buildFeatCard(feats[idx], isDark),
    );
  }

  Widget _buildFeatCard(GlyphFeatEntry feat, bool isDark) {
    final catColor = feat.featCategory.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: catColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showFeatDetails(feat, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.feat(
                category: feat.featCategory,
                featId: feat.featId,
                displayName: feat.name,
                actionRings: feat.actionRings,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                feat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: catColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '[LV ${feat.minLevel}+]',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: catColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          feat.featCategory.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: catColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      feat.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: feat.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(catColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              r.label ?? r.ringType.displayName,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ringColor,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. CHARACTER CLASSES GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildClassesGallery(bool isDark, DmRulesEdition edition) {
    var classes = GlyphGalleryData.allClasses.where((c) {
      if (_selectedClassType != null && c.classType != _selectedClassType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = c.name.toLowerCase().contains(_searchQuery) ||
            c.primaryAbility.toLowerCase().contains(_searchQuery) ||
            c.primaryResource.toLowerCase().contains(_searchQuery) ||
            c.summary.toLowerCase().contains(_searchQuery);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (classes.isEmpty) {
      return _buildEmptyState('No classes matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: classes.length,
      itemBuilder: (context, idx) => _buildClassCard(classes[idx], isDark),
    );
  }

  Widget _buildClassCard(GlyphClassEntry classEntry, bool isDark) {
    final classColor = classEntry.classType.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: classColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showClassDetails(classEntry, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.classFeature(
                classType: classEntry.classType,
                actionRings: classEntry.actionRings,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                classEntry.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: classColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: classColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '[d${classEntry.classType.hitDieSides}]',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: classColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'KEY: ${classEntry.primaryAbility.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: classColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      classEntry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: classEntry.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(classColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              r.label ?? r.ringType.displayName,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ringColor,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. SPECIES / RACES GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildSpeciesGallery(bool isDark, DmRulesEdition edition) {
    var species = GlyphGalleryData.allSpecies.where((s) {
      if (_selectedSpeciesType != null && s.speciesType != _selectedSpeciesType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = s.name.toLowerCase().contains(_searchQuery) ||
            s.getTraits(edition).toLowerCase().contains(_searchQuery) ||
            s.getSummary(edition).toLowerCase().contains(_searchQuery);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (species.isEmpty) {
      return _buildEmptyState(
          edition == DmRulesEdition.v2014
              ? 'No races matching current filters.'
              : 'No species matching current filters.',
          isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: species.length,
      itemBuilder: (context, idx) =>
          _buildSpeciesCard(species[idx], isDark, edition),
    );
  }

  Widget _buildSpeciesCard(
      GlyphSpeciesEntry species, bool isDark, DmRulesEdition edition) {
    final speciesColor = species.speciesType.getLegibleColor(isDark);
    final spSpeed = species.getSpeed(edition);
    final spSize = species.getSize(edition);
    final spSummary = species.getSummary(edition);
    final spRings = species.getActionRings(edition);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: speciesColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showSpeciesDetails(species, isDark, edition),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.species(
                speciesType: species.speciesType,
                actionRings: spRings,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                species.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: speciesColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: speciesColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                '[$spSpeed FT • ${edition.label}]',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: speciesColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'SIZE: ${spSize.toUpperCase()} // ${species.speciesType.frameShape.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: speciesColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      spSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: spRings.map((r) {
                          final ringColor = r.getEffectiveColor(speciesColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                  color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              r.label ?? r.ringType.displayName,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: ringColor,
                                  fontFamily: 'monospace'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. GENERIC UI & POLYHEDRALS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildGenericUiGallery(bool isDark, DmRulesEdition edition) {
    var entries = GlyphGalleryData.allGenericUi.where((g) {
      if (_selectedGenericGroup != null && g.group != _selectedGenericGroup) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final match = g.name.toLowerCase().contains(_searchQuery) ||
            g.group.toLowerCase().contains(_searchQuery) ||
            g.summary.toLowerCase().contains(_searchQuery);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (entries.isEmpty) {
      return _buildEmptyState('No generic UI icons matching current filters.', isDark);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 460,
        mainAxisExtent: _glyphDisplaySize > 60 ? 225 : 190,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: entries.length,
      itemBuilder: (context, idx) => _buildGenericUiCard(entries[idx], isDark),
    );
  }

  Widget _buildGenericUiCard(GlyphGenericEntry entry, bool isDark) {
    final uiColor = entry.uiType.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: uiColor.withValues(alpha: 0.55), width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showGenericUiDetails(entry, isDark),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              DndGlyph.genericUi(
                uiType: entry.uiType,
                actionRings: entry.actionRings,
                size: _glyphDisplaySize,
                isDarkMode: isDark,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                entry.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: uiColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: uiColor.withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                entry.group.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: uiColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '// ${entry.uiType.frameShape.name.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: uiColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      entry.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. CUSTOM GLYPH STUDIO & BUILDER
  // ---------------------------------------------------------------------------

  Widget _buildCustomBuilder(bool isDark, DmRulesEdition edition) {
    final effectiveShape = _builderShapeOverride ??
        (_builderMode == 0
            ? _builderSchool.frameShape
            : _builderMode == 1
                ? _builderCreature.frameShape
                : _builderMode == 2
                    ? _builderItemCategory.frameShape
                    : _builderMode == 3
                        ? _builderFeatCategory.frameShape
                        : _builderMode == 4
                            ? _builderClassType.frameShape
                            : _builderMode == 5
                                ? _builderSpeciesType.frameShape
                                : _builderGenericUiType.frameShape);

    final baseTheme = _builderMode == 0
        ? GlyphThemeData.fromSchool(_builderSchool)
        : _builderMode == 1
            ? GlyphThemeData.fromCreature(_builderCreature)
            : _builderMode == 2
                ? GlyphThemeData.fromItem(_builderItemCategory,
                    rarity: _builderItemRarity)
                : _builderMode == 3
                    ? GlyphThemeData.fromFeat(_builderFeatCategory)
                    : _builderMode == 4
                        ? GlyphThemeData.fromClass(_builderClassType)
                        : _builderMode == 5
                            ? GlyphThemeData.fromSpecies(_builderSpeciesType)
                            : GlyphThemeData.fromGenericUi(_builderGenericUiType);

    final themeData = GlyphThemeData(
      primary: baseTheme.primary,
      lightFill: baseTheme.lightFill,
      darkFill: baseTheme.darkFill,
      border: baseTheme.border,
      frameShape: effectiveShape,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interactive Custom Glyph Studio',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Compose custom holographic wireframe techno-runes across Spells, Minions, Items, Feats, Classes, Species, and Generic UI with live container overrides.',
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 20),

          // Live Preview Area
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: themeData.getPrimary(isDark).withValues(alpha: 0.6),
                    width: 2),
                boxShadow: [
                  BoxShadow(
                    color: themeData.getPrimary(isDark).withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  RepaintBoundary(
                    key: _glyphBoundaryKey,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.transparent,
                      child: switch (_builderMode) {
                        0 => DndGlyph.spell(
                            school: _builderSchool,
                            themeData: themeData,
                            level: _builderLevelOrTier,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        1 => DndGlyph.monster(
                            creatureType: _builderCreature,
                            themeData: themeData,
                            crTier: _builderLevelOrTier,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        2 => DndGlyph.item(
                            category: _builderItemCategory,
                            rarity: _builderItemRarity,
                            requiresAttunement: _builderItemRequiresAttunement,
                            themeData: themeData,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        3 => DndGlyph.feat(
                            category: _builderFeatCategory,
                            featId: _builderFeatId,
                            displayName: _builderFeatId.replaceAll('feat_', '').replaceAll('_', ' ').toUpperCase(),
                            themeData: themeData,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        4 => DndGlyph.classFeature(
                            classType: _builderClassType,
                            themeData: themeData,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        5 => DndGlyph.species(
                            speciesType: _builderSpeciesType,
                            themeData: themeData,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                        _ => DndGlyph.genericUi(
                            uiType: _builderGenericUiType,
                            themeData: themeData,
                            actionRings: _builderRings,
                            size: _builderSize,
                            isDarkMode: isDark,
                          ),
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    switch (_builderMode) {
                      0 => '${_builderSchool.displayName} • Level $_builderLevelOrTier',
                      1 => '${_builderCreature.displayName} • CR Tier $_builderLevelOrTier',
                      2 => '${_builderItemCategory.displayName} • ${_builderItemRarity.displayName}${_builderItemRequiresAttunement ? " (Attunement)" : ""}',
                      3 => '${_builderFeatCategory.displayName} • $_builderFeatId',
                      4 => '${_builderClassType.displayName} • d${_builderClassType.hitDieSides} Hit Die',
                      5 => '${_builderSpeciesType.displayName} • ${_builderSpeciesType.getSize(edition)}, ${_builderSpeciesType.getSpeed(edition)} ft',
                      _ => _builderGenericUiType.displayName,
                    },
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeData.getPrimary(isDark),
                    ),
                  ),
                  Text(
                    'Container: ${effectiveShape.displayName}',
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Preset Importer Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: themeData.getPrimary(isDark).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_mosaic,
                        size: 18, color: themeData.getPrimary(isDark)),
                    const SizedBox(width: 8),
                    const Text(
                      'Auto-Populate / Read from Toolkit Presets:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Spell Preset Loader
                    _buildPresetDropdown<SummonPreset>(
                      label: '🔮 Read Spell Card...',
                      isDark: isDark,
                      items: SrdSummonsLibrary.allPresets
                          .map((sp) => DropdownMenuItem(
                                value: sp,
                                child: Text('${sp.name} (${sp.levelDisplay})',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (sp) {
                        if (sp != null) {
                          setState(() {
                            _builderMode = 0;
                            _builderSchool = sp.glyphSchool;
                            _builderLevelOrTier = sp.glyphSpellLevel;
                            _builderShapeOverride = null;
                            _builderRings = List.from(sp.glyphActionRings);
                          });
                        }
                      },
                    ),
                    // Creature Stat Block Loader
                    _buildPresetDropdown<MinionStatBlock>(
                      label: '🐉 Read Minion Stat Block...',
                      isDark: isDark,
                      items: () {
                        final uniqueStatBlocks = <String, MinionStatBlock>{};
                        for (final p in SrdSummonsLibrary.allPresets) {
                          for (final sb in p.statBlocks) {
                            uniqueStatBlocks[sb.id] = sb;
                          }
                        }
                        return uniqueStatBlocks.values
                            .map((sb) => DropdownMenuItem(
                                  value: sb,
                                  child: Text(
                                      '${sb.name} (${sb.typeDisplay} CR ${sb.crDisplay})',
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList();
                      }(),
                      onChanged: (sb) {
                        if (sb != null) {
                          setState(() {
                            _builderMode = 1;
                            _builderCreature = sb.glyphCreatureType;
                            _builderLevelOrTier = sb.glyphCrTier;
                            _builderShapeOverride = null;
                            _builderRings = List.from(sb.glyphActionRings);
                          });
                        }
                      },
                    ),
                    // Magic Item Preset Loader
                    _buildPresetDropdown<GlyphItemEntry>(
                      label: '🛡️ Read Magic Item...',
                      isDark: isDark,
                      items: GlyphGalleryData.allItems
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                    '${item.name} (${item.rarity.displayName})',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (item) {
                        if (item != null) {
                          setState(() {
                            _builderMode = 2;
                            _builderItemCategory = item.category;
                            _builderItemRarity = item.rarity;
                            _builderItemRequiresAttunement =
                                item.requiresAttunement;
                            _builderLevelOrTier = item.rarity.tierLevel;
                            _builderShapeOverride = null;
                            _builderRings = List.from(item.actionRings);
                          });
                        }
                      },
                    ),
                    // Feat Preset Loader
                    _buildPresetDropdown<GlyphFeatEntry>(
                      label: '⭐ Read Feat / Boon...',
                      isDark: isDark,
                      items: GlyphGalleryData.allFeats
                          .map((feat) => DropdownMenuItem(
                                value: feat,
                                child: Text('${feat.name} (${feat.featCategory.displayName})',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (feat) {
                        if (feat != null) {
                          setState(() {
                            _builderMode = 3;
                            _builderFeatCategory = feat.featCategory;
                            _builderFeatId = feat.featId;
                            _builderLevelOrTier = feat.minLevel;
                            _builderShapeOverride = null;
                            _builderRings = List.from(feat.actionRings);
                          });
                        }
                      },
                    ),
                    // Class Preset Loader
                    _buildPresetDropdown<GlyphClassEntry>(
                      label: '🛡️ Read Character Class...',
                      isDark: isDark,
                      items: GlyphGalleryData.allClasses
                          .map((cls) => DropdownMenuItem(
                                value: cls,
                                child: Text('${cls.name} (d${cls.classType.hitDieSides})',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (cls) {
                        if (cls != null) {
                          setState(() {
                            _builderMode = 4;
                            _builderClassType = cls.classType;
                            _builderShapeOverride = null;
                            _builderRings = List.from(cls.actionRings);
                          });
                        }
                      },
                    ),
                    // Species Preset Loader
                    _buildPresetDropdown<GlyphSpeciesEntry>(
                      label: edition == DmRulesEdition.v2014
                          ? '👥 Read Race (2014 SRD)...'
                          : '👥 Read Species (2024 SRD)...',
                      isDark: isDark,
                      items: GlyphGalleryData.allSpecies
                          .map((spec) => DropdownMenuItem(
                                value: spec,
                                child: Text(spec.name,
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (spec) {
                        if (spec != null) {
                          setState(() {
                            _builderMode = 5;
                            _builderSpeciesType = spec.speciesType;
                            _builderShapeOverride = null;
                            _builderRings = List.from(spec.getActionRings(edition));
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Controls Mode Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                const ButtonSegment(value: 0, icon: Icon(Icons.memory), label: Text('Spell')),
                const ButtonSegment(value: 1, icon: Icon(Icons.pets), label: Text('Creature')),
                const ButtonSegment(value: 2, icon: Icon(Icons.shield_outlined), label: Text('Item')),
                const ButtonSegment(value: 3, icon: Icon(Icons.stars_outlined), label: Text('Feat')),
                const ButtonSegment(value: 4, icon: Icon(Icons.shield), label: Text('Class')),
                ButtonSegment(
                  value: 5,
                  icon: const Icon(Icons.groups_outlined),
                  label: Text(edition == DmRulesEdition.v2014 ? 'Race' : 'Species'),
                ),
                const ButtonSegment(value: 6, icon: Icon(Icons.widgets_outlined), label: Text('UI Icon')),
              ],
              selected: {_builderMode},
              onSelectionChanged: (val) {
                setState(() {
                  _builderMode = val.first;
                  _builderShapeOverride = null;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Controls per mode
          if (_builderMode == 0) ...[
            const Text('Select Arcane Spell School:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SpellSchool.values.map((s) {
                return ChoiceChip(
                  label: Text(s.displayName),
                  selected: _builderSchool == s,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderSchool = s);
                  },
                );
              }).toList(),
            ),
          ] else if (_builderMode == 1) ...[
            const Text('Select Creature Classification:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CreatureType.values.map((t) {
                return ChoiceChip(
                  label: Text(t.displayName),
                  selected: _builderCreature == t,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderCreature = t);
                  },
                );
              }).toList(),
            ),
          ] else if (_builderMode == 2) ...[
            const Text('Select Item Category:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemCategory.values.map((c) {
                return ChoiceChip(
                  label: Text(c.displayName),
                  selected: _builderItemCategory == c,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderItemCategory = c);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Select Item Rarity:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItemRarity.values.map((r) {
                return ChoiceChip(
                  label: Text(r.displayName),
                  selected: _builderItemRarity == r,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _builderItemRarity = r;
                        _builderLevelOrTier = r.tierLevel;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            FilterChip(
              avatar: Icon(
                _builderItemRequiresAttunement
                    ? Icons.link
                    : Icons.link_off,
                size: 16,
              ),
              label: const Text('Requires Attunement'),
              selected: _builderItemRequiresAttunement,
              onSelected: (sel) =>
                  setState(() => _builderItemRequiresAttunement = sel),
            ),
          ] else if (_builderMode == 3) ...[
            const Text('Select Feat Tier Category:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FeatCategory.values.map((fc) {
                return ChoiceChip(
                  label: Text(fc.displayName),
                  selected: _builderFeatCategory == fc,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderFeatCategory = fc);
                  },
                );
              }).toList(),
            ),
          ] else if (_builderMode == 4) ...[
            const Text('Select Character Class:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DndClassType.values.map((ct) {
                return ChoiceChip(
                  label: Text('${ct.displayName} (d${ct.hitDieSides})'),
                  selected: _builderClassType == ct,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderClassType = ct);
                  },
                );
              }).toList(),
            ),
          ] else if (_builderMode == 5) ...[
            Text('Select ${edition == DmRulesEdition.v2014 ? "Race (2014 SRD)" : "Species (2024 SRD)"}:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SpeciesType.values.map((st) {
                return ChoiceChip(
                  label: Text(st.displayName),
                  selected: _builderSpeciesType == st,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderSpeciesType = st);
                  },
                );
              }).toList(),
            ),
          ] else ...[
            const Text('Select Generic UI Icon:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GenericUiGlyphType.values.map((gt) {
                return ChoiceChip(
                  label: Text(gt.displayName),
                  selected: _builderGenericUiType == gt,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderGenericUiType = gt);
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // Container Override Section
          const Text('Override Container Frame Shape:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Default (Automatic)'),
                selected: _builderShapeOverride == null,
                onSelected: (_) =>
                    setState(() => _builderShapeOverride = null),
              ),
              ...GlyphFrameShape.values.map((shape) {
                return ChoiceChip(
                  label: Text(shape.displayName),
                  selected: _builderShapeOverride == shape,
                  onSelected: (sel) {
                    if (sel) setState(() => _builderShapeOverride = shape);
                  },
                );
              }),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Action Rings Composition Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dynamic Action Trait Rings:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Ring'),
                onPressed: () {
                  setState(() {
                    _builderRings.add(
                      const ActionTraitRing(
                        ringType: ActionRingType.melee,
                        damageType: DamageAccent.physical,
                        label: 'New Trait',
                      ),
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_builderRings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No action trait rings configured (renders base symbol only).',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54),
              ),
            )
          else
            ..._builderRings.asMap().entries.map((entry) {
              final idx = entry.key;
              final ring = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    Text('#${idx + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<ActionRingType>(
                        value: ring.ringType,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: ActionRingType.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t.displayName,
                                style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (newType) {
                          if (newType != null) {
                            setState(() {
                              _builderRings[idx] = ActionTraitRing(
                                ringType: newType,
                                damageType: ring.damageType,
                                damageTypes: ring.damageTypes,
                                label: ring.label,
                              );
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<DamageAccent?>(
                      value: ring.damageType,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      hint: const Text('Neutral', style: TextStyle(fontSize: 12)),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('Neutral / Default',
                                style: TextStyle(fontSize: 12))),
                        ...DamageAccent.values.map((da) {
                          return DropdownMenuItem(
                            value: da,
                            child: Text(da.displayName,
                                style: const TextStyle(fontSize: 12)),
                          );
                        }),
                      ],
                      onChanged: (newAccent) {
                        setState(() {
                          _builderRings[idx] = ActionTraitRing(
                            ringType: ring.ringType,
                            damageType: newAccent,
                            damageTypes: ring.damageTypes,
                            label: ring.label,
                          );
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _builderRings.removeAt(idx);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Code preview and copy button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Generated Dart Widget Code:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Dart Code'),
                onPressed: () {
                  final code = _generateDartCode();
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied complete DndGlyph Dart code to clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _generateDartCode(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.lightGreenAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _generateDartCode() {
    final sb = StringBuffer();
    if (_builderMode == 0) {
      sb.writeln('DndGlyph.spell(');
      sb.writeln('  school: SpellSchool.${_builderSchool.name},');
      sb.writeln('  level: $_builderLevelOrTier,');
    } else if (_builderMode == 1) {
      sb.writeln('DndGlyph.monster(');
      sb.writeln('  creatureType: CreatureType.${_builderCreature.name},');
      sb.writeln('  crTier: $_builderLevelOrTier,');
    } else if (_builderMode == 2) {
      sb.writeln('DndGlyph.item(');
      sb.writeln('  category: ItemCategory.${_builderItemCategory.name},');
      sb.writeln('  rarity: ItemRarity.${_builderItemRarity.name},');
      if (_builderItemRequiresAttunement) {
        sb.writeln('  requiresAttunement: true,');
      }
    } else if (_builderMode == 3) {
      sb.writeln('DndGlyph.feat(');
      sb.writeln('  category: FeatCategory.${_builderFeatCategory.name},');
      sb.writeln('  featId: \'$_builderFeatId\',');
    } else if (_builderMode == 4) {
      sb.writeln('DndGlyph.classFeature(');
      sb.writeln('  classType: DndClassType.${_builderClassType.name},');
    } else if (_builderMode == 5) {
      sb.writeln('DndGlyph.species(');
      sb.writeln('  speciesType: SpeciesType.${_builderSpeciesType.name},');
    } else {
      sb.writeln('DndGlyph.genericUi(');
      sb.writeln('  uiType: GenericUiGlyphType.${_builderGenericUiType.name},');
    }
    if (_builderShapeOverride != null) {
      sb.writeln('  frameShapeOverride: GlyphFrameShape.${_builderShapeOverride!.name},');
    }
    if (_builderRings.isNotEmpty) {
      sb.writeln('  actionRings: const [');
      for (final r in _builderRings) {
        sb.writeln('    ActionTraitRing(');
        sb.writeln('      ringType: ActionRingType.${r.ringType.name},');
        if (r.damageType != null) {
          sb.writeln('      damageType: DamageAccent.${r.damageType!.name},');
        }
        if (r.label != null) {
          sb.writeln('      label: \'${r.label}\',');
        }
        sb.writeln('    ),');
      }
      sb.writeln('  ],');
    }
    sb.writeln('  size: $_builderSize,');
    sb.write(')');
    return sb.toString();
  }

  Widget _buildPresetDropdown<T>({
    required String label,
    required bool isDark,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: DropdownButton<T>(
          hint: Text(label, style: const TextStyle(fontSize: 13)),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9. FULL STYLE GUIDE CODEX
  // ---------------------------------------------------------------------------

  Widget _buildFullStyleGuide(bool isDark, DmRulesEdition edition) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
              'D&D App Glyph System: Techno-Wireframe HUD & Arcane Codex',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Official reference architecture for procedural vector glyphs, holographic wireframes, Hit Die geometry, and dynamic action traits.',
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 24),

          // Section 1: 8 Schools of Magic
          const Text('1. The 8 Arcane Schools of Magic',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: SpellSchool.values.map((s) {
              final col = s.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.spell(
                          school: s, level: 3, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Frame: ${s.frameShape.displayName}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                          Text(
                              '#${s.primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: col,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 2: 14 Creature Classifications
          const Text('2. The 14 Creature Classifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: CreatureType.values.map((t) {
              final col = t.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.monster(
                          creatureType: t, crTier: 2, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Frame: ${t.frameShape.displayName}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 3: Magic Item & Equipment Categories
          const Text('3. The 9 Magic Item & Equipment Categories',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ItemCategory.values.map((c) {
              final col = c.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.item(
                          category: c, rarity: ItemRarity.rare, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Frame: ${c.frameShape.displayName}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 4: Item Rarities
          const Text('4. The 6 Standard 5e Item Rarities',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ItemRarity.values.map((r) {
              final col = r.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.item(
                          category: ItemCategory.wondrousItem, rarity: r, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Tier Level: ${r.tierLevel}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 5: Progression Tiers
          const Text('5. The 4 Progression Tiers & Threat Architecture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tier 1 • Initiate / CR 0–4',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),

          // Section 6: Character Classes & Hit Die Geometries
          const Text('6. Character Classes & Hit Die Geometries (d6 - d12)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: DndClassType.values.map((ct) {
              final col = ct.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.classFeature(
                          classType: ct, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ct.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Hit Die: d${ct.hitDieSides} (${ct.hitDieSides} Vertices)',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                          Text('Resource: ${ct.primaryResource}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 7: Feat Categories & Epic Boons
          const Text('7. Feat Tiers & Epic Boons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: FeatCategory.values.map((fc) {
              final col = fc.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.feat(
                          category: fc,
                          featId: 'feat_sample',
                          size: 52,
                          isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fc.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Tier Level: ${fc.tierLevel}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                          Text('Frame: ${fc.frameShape.displayName}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 8: Species & Heritages
          Text(
              '8. ${edition == DmRulesEdition.v2014 ? "Races" : "Species"} & Heritage Sigils (${edition.label} SRD)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: SpeciesType.values.map((st) {
              final col = st.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.species(
                          speciesType: st, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(st.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('${st.getSize(edition)} • ${st.getSpeed(edition)} ft Speed',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                          Text(st.getTraits(edition),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 9: Generic UI & Polyhedral Wireframes
          const Text('9. Generic UI & Polyhedral Dice Wireframes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: GenericUiGlyphType.values.map((gt) {
              final col = gt.getLegibleColor(isDark);
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DndGlyph.genericUi(
                          uiType: gt, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(gt.displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: col)),
                          Text('Frame: ${gt.frameShape.displayName}',
                              style: const TextStyle(
                                  fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 10: Action & Attack Trait Rings
          const Text('10. Action & Attack Trait Rings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ActionRingType.values.map((rt) {
              return _buildStandaloneRingCard(rt, isDark);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneRingCard(ActionRingType ringType, bool isDark) {
    final ring = ActionTraitRing(ringType: ringType);
    final col = ring.getEffectiveColor(Colors.cyanAccent, isDarkMode: isDark);

    return Card(
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: CustomPaint(
                painter: _StandaloneRingPainter(
                  ringType: ringType,
                  color: col,
                  isDarkMode: isDark,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ringType.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: col)),
                Text(
                  switch (ringType) {
                    ActionRingType.melee => 'Faceted Octagonal Blade Ticks',
                    ActionRingType.ranged => '4-Axis Targeting Crosshair Reticle',
                    ActionRingType.recharge => '6-Segment Pulse Energy Gaps',
                    ActionRingType.reaction => 'Square Corner Deflection Brackets',
                    ActionRingType.control => 'Tri-Node Restraint Lattice',
                    ActionRingType.sustain => 'Dual Harmonic Cradle Rings',
                    ActionRingType.legendary => 'Spiked Starburst Crown Rays',
                    ActionRingType.concentration => 'Orbital Satellite Pulse Loop',
                    ActionRingType.attunement => 'Sacred Knot Crosshair Tether',
                    ActionRingType.bonusAction => 'Triple-Spark Triangulation Rays',
                    ActionRingType.resource => '4-Segment Rest & Recharge Matrix',
                    ActionRingType.passive => 'Continuous Harmonic Double Ring',
                    ActionRingType.speed => 'Velocity Motion Vector Chevrons',
                    ActionRingType.sense => 'Sensory Radar Sonar Crosshairs',
                    ActionRingType.hitDie => 'Polyhedral Hit Die Geometry',
                  },
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL MODALS
  // ---------------------------------------------------------------------------

  void _showSpellDetails(GlyphSpellEntry spell, bool isDark) {
    final schoolColor = spell.school.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.spell(
                school: spell.school,
                level: spell.level,
                actionRings: spell.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(spell.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('School', spell.school.displayName, accentColor: schoolColor),
            _buildDetailRow('Level', spell.levelDescription),
            _buildDetailRow('Casting Time', spell.castingTime),
            _buildDetailRow('Range', spell.range),
            _buildDetailRow('Duration', spell.duration),
            const SizedBox(height: 10),
            Text(spell.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showCreatureDetails(GlyphCreatureEntry creature, bool isDark) {
    final typeColor = creature.type.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.monster(
                creatureType: creature.type,
                crTier: creature.crTier,
                actionRings: creature.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(creature.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', creature.type.displayName, accentColor: typeColor),
            _buildDetailRow('Challenge Rating', 'CR ${creature.cr}'),
            _buildDetailRow('Armor Class', '${creature.ac}'),
            _buildDetailRow('Hit Points', '${creature.hp} HP'),
            _buildDetailRow('Speed', creature.speed),
            _buildDetailRow('Attack', creature.primaryAttack),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showItemDetails(GlyphItemEntry item, bool isDark) {
    final catColor = item.category.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.item(
                category: item.category,
                rarity: item.rarity,
                requiresAttunement: item.requiresAttunement,
                actionRings: item.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Category', item.category.displayName, accentColor: catColor),
            _buildDetailRow('Rarity', item.rarity.displayName),
            _buildDetailRow('Attunement', item.requiresAttunement ? 'Requires Attunement' : 'No'),
            const SizedBox(height: 10),
            Text(item.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showFeatDetails(GlyphFeatEntry feat, bool isDark) {
    final catColor = feat.featCategory.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.feat(
                category: feat.featCategory,
                featId: feat.featId,
                displayName: feat.name,
                actionRings: feat.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(feat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tier', feat.featCategory.displayName, accentColor: catColor),
            _buildDetailRow('Min Level', 'Level ${feat.minLevel}+'),
            if (feat.prerequisite != null)
              _buildDetailRow('Prerequisite', feat.prerequisite!),
            _buildDetailRow('Trigger', feat.triggerType.displayName),
            const SizedBox(height: 10),
            Text(feat.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showClassDetails(GlyphClassEntry classEntry, bool isDark) {
    final classColor = classEntry.classType.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.classFeature(
                classType: classEntry.classType,
                actionRings: classEntry.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(classEntry.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Hit Die', 'd${classEntry.classType.hitDieSides}', accentColor: classColor),
            _buildDetailRow('Primary Ability', classEntry.primaryAbility),
            _buildDetailRow('Saving Throws', classEntry.savingThrows),
            _buildDetailRow('Primary Resource', classEntry.primaryResource),
            const SizedBox(height: 10),
            Text(classEntry.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showSpeciesDetails(
      GlyphSpeciesEntry species, bool isDark, DmRulesEdition edition) {
    final speciesColor = species.speciesType.getLegibleColor(isDark);
    final speed = species.getSpeed(edition);
    final size = species.getSize(edition);
    final traits = species.getTraits(edition);
    final summary = species.getSummary(edition);
    final rings = species.getActionRings(edition);

    final speed2014 = species.getSpeed(DmRulesEdition.v2014);
    final speed2024 = species.getSpeed(DmRulesEdition.v2024);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.species(
                speciesType: species.speciesType,
                actionRings: rings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(species.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    edition == DmRulesEdition.v2014
                        ? '2014 SRD Race'
                        : '2024 SRD Species',
                    style: TextStyle(
                        fontSize: 11,
                        color: speciesColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Rules Edition', '${edition.label} SRD Rules',
                  accentColor: speciesColor),
              _buildDetailRow('Size', size),
              _buildDetailRow(
                  'Movement Speed', '$speed feet (${edition.label} SRD)'),
              _buildDetailRow('Heritage Traits', traits),
              const SizedBox(height: 10),
              Text(summary, style: const TextStyle(fontSize: 13)),
              if (speed2014 != speed2024) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: speciesColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: speciesColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.compare_arrows, size: 16, color: speciesColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2014 Speed: $speed2014 ft ➔ 2024 Speed: $speed2024 ft',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: speciesColor,
                              fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showGenericUiDetails(GlyphGenericEntry entry, bool isDark) {
    final uiColor = entry.uiType.getLegibleColor(isDark);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            DndGlyph.genericUi(
                uiType: entry.uiType,
                actionRings: entry.actionRings,
                size: 40,
                isDarkMode: isDark),
            const SizedBox(width: 12),
            Expanded(
                child: Text(entry.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Group', entry.group, accentColor: uiColor),
            _buildDetailRow('Frame Shape', entry.uiType.frameShape.displayName),
            const SizedBox(height: 10),
            Text(entry.summary, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(height: 12),
            Text(message,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? accentColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight:
                    accentColor != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to render standalone action trait rings on their own on a HUD schematic grid.
class _StandaloneRingPainter extends CustomPainter {
  final ActionRingType ringType;
  final Color color;
  final bool isDarkMode;

  const _StandaloneRingPainter({
    required this.ringType,
    required this.color,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    // Draw background blueprint grid
    final gridPaint = Paint()
      ..color = color.withValues(alpha: isDarkMode ? 0.12 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawLine(
        Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

    // Draw standalone ring
    final scale = s / 24.0;
    final r = 8.5 * scale;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final finePaint = Paint()
      ..color = color.withValues(alpha: isDarkMode ? 0.70 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75 * scale;

    final nodeFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: isDarkMode ? 0.35 : 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * scale
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * scale);

    // Render using shared geometry
    _drawRingGeometry(
        canvas, center, r, ringType, scale, glowPaint, finePaint, nodeFill,
        isGlow: true);
    _drawRingGeometry(
        canvas, center, r, ringType, scale, strokePaint, finePaint, nodeFill,
        isGlow: false);
  }

  void _drawRingGeometry(
    Canvas canvas,
    Offset center,
    double r,
    ActionRingType type,
    double scale,
    Paint strokePaint,
    Paint finePaint,
    Paint nodeFill, {
    required bool isGlow,
  }) {
    switch (type) {
      case ActionRingType.melee:
        final path = Path()
          ..moveTo(center.dx, center.dy - r)
          ..lineTo(center.dx + r * 0.7, center.dy - r * 0.7)
          ..lineTo(center.dx + r, center.dy)
          ..lineTo(center.dx + r * 0.7, center.dy + r * 0.7)
          ..lineTo(center.dx, center.dy + r)
          ..lineTo(center.dx - r * 0.7, center.dy + r * 0.7)
          ..lineTo(center.dx - r, center.dy)
          ..lineTo(center.dx - r * 0.7, center.dy - r * 0.7)
          ..close();
        canvas.drawPath(path, strokePaint);
        if (!isGlow) {
          canvas.drawLine(Offset(center.dx, center.dy - r - 1.5 * scale),
              Offset(center.dx, center.dy - r + 1.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx, center.dy + r - 1.5 * scale),
              Offset(center.dx, center.dy + r + 1.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx - r - 1.5 * scale, center.dy),
              Offset(center.dx - r + 1.5 * scale, center.dy), finePaint);
          canvas.drawLine(Offset(center.dx + r - 1.5 * scale, center.dy),
              Offset(center.dx + r + 1.5 * scale, center.dy), finePaint);
          canvas.drawCircle(
              Offset(center.dx, center.dy - r), 1.0 * scale, nodeFill);
          canvas.drawCircle(
              Offset(center.dx, center.dy + r), 1.0 * scale, nodeFill);
          canvas.drawCircle(
              Offset(center.dx - r, center.dy), 1.0 * scale, nodeFill);
          canvas.drawCircle(
              Offset(center.dx + r, center.dy), 1.0 * scale, nodeFill);
        }
      case ActionRingType.ranged:
        canvas.drawCircle(center, r, strokePaint);
        if (!isGlow) {
          canvas.drawLine(Offset(center.dx, center.dy - r - 2.5 * scale),
              Offset(center.dx, center.dy - r + 2.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx, center.dy + r - 2.5 * scale),
              Offset(center.dx, center.dy + r + 2.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx - r - 2.5 * scale, center.dy),
              Offset(center.dx - r + 2.5 * scale, center.dy), finePaint);
          canvas.drawLine(Offset(center.dx + r - 2.5 * scale, center.dy),
              Offset(center.dx + r + 2.5 * scale, center.dy), finePaint);
        }
      case ActionRingType.recharge:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a1 = (i * 60.0 + 8.0) * 3.14159265 / 180.0;
          final a2 = ((i + 1) * 60.0 - 8.0) * 3.14159265 / 180.0;
          final p1 = Offset(
              center.dx + r * 0.95 * cos(a1), center.dy + r * 0.95 * sin(a1));
          final p2 = Offset(
              center.dx + r * 0.95 * cos(a2), center.dy + r * 0.95 * sin(a2));
          path.moveTo(p1.dx, p1.dy);
          path.lineTo(p2.dx, p2.dy);
        }
        canvas.drawPath(path, strokePaint);
      case ActionRingType.reaction:
        final half = r * 0.85;
        final rect =
            Rect.fromCenter(center: center, width: half * 2, height: half * 2);
        canvas.drawRect(rect, strokePaint);
        if (!isGlow) {
          canvas.drawCircle(rect.topLeft, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.topRight, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.bottomLeft, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.bottomRight, 1.2 * scale, nodeFill);
        }
      case ActionRingType.control:
        canvas.drawCircle(center, r, strokePaint);
        if (!isGlow) {
          final pTop = Offset(center.dx, center.dy - r);
          final pLeft = Offset(center.dx - r * 0.86, center.dy + r * 0.5);
          final pRight = Offset(center.dx + r * 0.86, center.dy + r * 0.5);
          final tri = Path()
            ..moveTo(pTop.dx, pTop.dy)
            ..lineTo(pLeft.dx, pLeft.dy)
            ..lineTo(pRight.dx, pRight.dy)
            ..close();
          canvas.drawPath(tri, finePaint);
          canvas.drawCircle(pTop, 1.1 * scale, nodeFill);
          canvas.drawCircle(pLeft, 1.1 * scale, nodeFill);
          canvas.drawCircle(pRight, 1.1 * scale, nodeFill);
        }
      case ActionRingType.sustain:
        canvas.drawOval(
            Rect.fromCenter(center: center, width: r * 2.0, height: r * 1.45),
            strokePaint);
        if (!isGlow) {
          canvas.drawOval(
              Rect.fromCenter(center: center, width: r * 1.45, height: r * 2.0),
              finePaint);
          final apex = Offset(center.dx, center.dy - r * 0.58);
          final left = Offset(center.dx - r * 0.55, center.dy + r * 0.35);
          final right = Offset(center.dx + r * 0.55, center.dy + r * 0.35);
          canvas.drawLine(left, apex, finePaint);
          canvas.drawLine(apex, right, finePaint);
          canvas.drawCircle(apex, 1.0 * scale, nodeFill);
          canvas.drawCircle(left, 1.0 * scale, nodeFill);
          canvas.drawCircle(right, 1.0 * scale, nodeFill);
        }
      case ActionRingType.concentration:
        final outerOrbit =
            Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.45);
        final innerOrbit =
            Rect.fromCenter(center: center, width: r * 1.45, height: r * 2.1);
        canvas.drawOval(outerOrbit, strokePaint);
        canvas.drawOval(innerOrbit, finePaint);
        if (!isGlow) {
          final satEast = Offset(center.dx + r * 1.05, center.dy);
          final satWest = Offset(center.dx - r * 1.05, center.dy);
          final satNorth = Offset(center.dx, center.dy - r * 1.05);
          final satSouth = Offset(center.dx, center.dy + r * 1.05);

          canvas.drawCircle(satEast, 1.1 * scale, nodeFill);
          canvas.drawCircle(satWest, 1.1 * scale, nodeFill);
          canvas.drawCircle(satNorth, 0.9 * scale, nodeFill);
          canvas.drawCircle(satSouth, 0.9 * scale, nodeFill);

          canvas.drawLine(satEast - Offset(0, 1.2 * scale),
              satEast + Offset(0, 1.2 * scale), finePaint);
          canvas.drawLine(satWest - Offset(0, 1.2 * scale),
              satWest + Offset(0, 1.2 * scale), finePaint);
          canvas.drawLine(satNorth - Offset(1.2 * scale, 0),
              satNorth + Offset(1.2 * scale, 0), finePaint);
          canvas.drawLine(satSouth - Offset(1.2 * scale, 0),
              satSouth + Offset(1.2 * scale, 0), finePaint);
        }
      case ActionRingType.attunement:
        canvas.drawCircle(center, r, strokePaint);
        if (!isGlow) {
          for (int i = 0; i < 4; i++) {
            final a = (i * 90.0) * pi / 180.0;
            final pOuter = Offset(center.dx + (r + 1.2 * scale) * cos(a),
                center.dy + (r + 1.2 * scale) * sin(a));
            final pInner = Offset(center.dx + (r - 1.2 * scale) * cos(a),
                center.dy + (r - 1.2 * scale) * sin(a));
            canvas.drawLine(pInner, pOuter, finePaint);
            canvas.drawCircle(pOuter, 0.85 * scale, nodeFill);
          }
        }
      case ActionRingType.legendary:
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final a = (i * 45.0 - 90.0) * 3.14159265 / 180.0;
          final outerR = (i % 2 == 0) ? r * 1.15 : r * 0.85;
          final pt =
              Offset(center.dx + outerR * cos(a), center.dy + outerR * sin(a));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, strokePaint);
      case ActionRingType.bonusAction:
        canvas.drawCircle(center, r, strokePaint);
        if (!isGlow) {
          for (int i = 0; i < 3; i++) {
            final a = (i * 120.0 - 90.0) * pi / 180.0;
            final pInner = Offset(center.dx + (r - 1.5 * scale) * cos(a),
                center.dy + (r - 1.5 * scale) * sin(a));
            final pOuter = Offset(center.dx + (r + 1.8 * scale) * cos(a),
                center.dy + (r + 1.8 * scale) * sin(a));
            canvas.drawLine(pInner, pOuter, finePaint);
            canvas.drawCircle(pOuter, 1.0 * scale, nodeFill);
          }
        }
      case ActionRingType.resource:
        const segments = 4;
        for (int i = 0; i < segments; i++) {
          final aStart = (i * 90.0 + 10.0) * pi / 180.0;
          final aEnd = (i * 90.0 + 80.0) * pi / 180.0;
          final rect = Rect.fromCircle(center: center, radius: r);
          canvas.drawArc(rect, aStart, aEnd - aStart, false, strokePaint);
        }
      case ActionRingType.passive:
        canvas.drawCircle(center, r, strokePaint);
        canvas.drawCircle(center, r - 0.9 * scale, finePaint);
      case ActionRingType.speed:
        final rect = Rect.fromCircle(center: center, radius: r);
        canvas.drawArc(rect, -pi * 0.75, pi * 1.5, false, strokePaint);
      case ActionRingType.sense:
        canvas.drawCircle(center, r, strokePaint);
        canvas.drawCircle(center, r * 0.7, finePaint);
      case ActionRingType.hitDie:
        final poly = Path();
        for (int i = 0; i < 6; i++) {
          final a = (i * 60.0 - 30.0) * pi / 180.0;
          final pt = Offset(center.dx + r * cos(a), center.dy + r * sin(a));
          if (i == 0) {
            poly.moveTo(pt.dx, pt.dy);
          } else {
            poly.lineTo(pt.dx, pt.dy);
          }
        }
        poly.close();
        canvas.drawPath(poly, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StandaloneRingPainter oldDelegate) =>
      oldDelegate.ringType != ringType ||
      oldDelegate.color != color ||
      oldDelegate.isDarkMode != isDarkMode;
}
