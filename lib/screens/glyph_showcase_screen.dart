import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/glyph_gallery_data.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../utils/glyph_image_exporter.dart';
import '../widgets/glyphs/glyph_tokens.dart';
import '../widgets/glyphs/dnd_glyph.dart';

/// Dynamic D&D Glyph Gallery: Real spells, creatures, Custom Glyph Builder, & Full Style Guide.
class GlyphShowcaseScreen extends StatefulWidget {
  const GlyphShowcaseScreen({super.key});

  @override
  State<GlyphShowcaseScreen> createState() => _GlyphShowcaseScreenState();
}

class _GlyphShowcaseScreenState extends State<GlyphShowcaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Spell Filters
  SpellSchool? _selectedSchool;

  // Creature Filters
  CreatureType? _selectedCreatureType;

  bool? _overrideDarkMode;
  double _glyphDisplaySize = 68.0;

  // ---------------------------------------------------------------------------
  // CUSTOM BUILDER STATE
  // ---------------------------------------------------------------------------
  bool _builderIsSpell = true;
  SpellSchool _builderSchool = SpellSchool.evocation;
  CreatureType _builderCreature = CreatureType.dragon;
  int _builderLevelOrTier = 3;
  GlyphFrameShape? _builderShapeOverride;
  double _builderSize = 88.0;
  List<ActionTraitRing> _builderRings = [
    const ActionTraitRing(ringType: ActionRingType.melee, damageType: DamageAccent.fire, label: 'Primary Attack'),
    const ActionTraitRing(ringType: ActionRingType.recharge, damageType: DamageAccent.fire, label: 'Breath Weapon'),
  ];
  final GlobalKey _glyphBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _overrideDarkMode ?? (Theme.of(context).brightness == Brightness.dark);

    return Theme(
      data: isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true),
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
            IconButton(
              tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                setState(() {
                  _overrideDarkMode = !isDark;
                });
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.memory), text: 'Spellbook Schematics'),
              Tab(icon: Icon(Icons.hub), text: 'Minion & Summon Matrix'),
              Tab(icon: Icon(Icons.build_circle), text: 'Custom Glyph Studio'),
              Tab(icon: Icon(Icons.architecture), text: 'Full Style Guide Codex'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_tabController.index == 0 || _tabController.index == 1)
              _buildSearchAndFilters(isDark),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSpellsGallery(isDark),
                  _buildCreaturesGallery(isDark),
                  _buildCustomBuilder(isDark),
                  _buildFullStyleGuide(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark) {
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
                    hintText: 'Search toolkit spells, minions, attack traits, damage types...',
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 52.0, label: Text('Compact')),
                  ButtonSegment(value: 68.0, label: Text('HUD View')),
                ],
                selected: {_glyphDisplaySize},
                onSelectionChanged: (set) => setState(() => _glyphDisplaySize = set.first),
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
                        onSelected: (_) => setState(() => _selectedSchool = null),
                      ),
                      const SizedBox(width: 6),
                      ...SpellSchool.values.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: s.getLegibleColor(isDark), shape: BoxShape.circle)),
                            label: Text(s.displayName),
                            selected: _selectedSchool == s,
                            onSelected: (sel) => setState(() => _selectedSchool = sel ? s : null),
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
                        label: const Text('All Summon Types'),
                        selected: _selectedCreatureType == null,
                        onSelected: (_) => setState(() => _selectedCreatureType = null),
                      ),
                      const SizedBox(width: 6),
                      ...CreatureType.values.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            avatar: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.getLegibleColor(isDark), shape: BoxShape.circle)),
                            label: Text(t.displayName),
                            selected: _selectedCreatureType == t,
                            onSelected: (sel) => setState(() => _selectedCreatureType = sel ? t : null),
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
  // SPELLS GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildSpellsGallery(bool isDark) {
    var spells = GlyphGalleryData.allSpells.where((s) {
      if (_selectedSchool != null && s.school != _selectedSchool) return false;
      if (_searchQuery.isNotEmpty) {
        final match = s.name.toLowerCase().contains(_searchQuery) ||
            s.school.displayName.toLowerCase().contains(_searchQuery) ||
            s.summary.toLowerCase().contains(_searchQuery) ||
            s.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                (r.damageType != null && r.damageType!.displayName.toLowerCase().contains(_searchQuery)) ||
                (r.label != null && r.label!.toLowerCase().contains(_searchQuery)));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (spells.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(height: 12),
              const Text('No spells matching current filters.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
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
      itemBuilder: (context, idx) {
        final spell = spells[idx];
        return _buildSpellCard(spell, isDark);
      },
    );
  }

  Widget _buildSpellCard(GlyphSpellEntry spell, bool isDark) {
    final schoolColor = spell.school.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: schoolColor.withValues(alpha: 0.55), width: 1.5),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: schoolColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: schoolColor.withValues(alpha: 0.6)),
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
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      spell.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: spell.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(schoolColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.damageType != null ? '${r.ringType.displayName} (${r.damageType!.displayName})' : r.ringType.displayName,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ringColor, fontFamily: 'monospace'),
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
  // CREATURES GALLERY
  // ---------------------------------------------------------------------------

  Widget _buildCreaturesGallery(bool isDark) {
    var creatures = GlyphGalleryData.allCreatures.where((c) {
      if (_selectedCreatureType != null && c.type != _selectedCreatureType) return false;
      if (_searchQuery.isNotEmpty) {
        final match = c.name.toLowerCase().contains(_searchQuery) ||
            c.type.displayName.toLowerCase().contains(_searchQuery) ||
            c.primaryAttack.toLowerCase().contains(_searchQuery) ||
            c.actionRings.any((r) =>
                r.ringType.displayName.toLowerCase().contains(_searchQuery) ||
                (r.damageType != null && r.damageType!.displayName.toLowerCase().contains(_searchQuery)) ||
                (r.label != null && r.label!.toLowerCase().contains(_searchQuery)));
        if (!match) return false;
      }
      return true;
    }).toList();

    if (creatures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(height: 12),
              const Text('No minion summons matching current filters.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
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
      itemBuilder: (context, idx) {
        final creature = creatures[idx];
        return _buildCreatureCard(creature, isDark);
      },
    );
  }

  Widget _buildCreatureCard(GlyphCreatureEntry creature, bool isDark) {
    final typeColor = creature.type.getLegibleColor(isDark);

    return Card(
      elevation: 4,
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: typeColor.withValues(alpha: 0.55), width: 1.5),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: typeColor.withValues(alpha: 0.6)),
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
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      creature.primaryAttack,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: creature.actionRings.map((r) {
                          final ringColor = r.getEffectiveColor(typeColor);
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: ringColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  r.damageType != null ? '${r.ringType.displayName} (${r.damageType!.displayName})' : r.ringType.displayName,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ringColor, fontFamily: 'monospace'),
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
  // TAB 3: CUSTOM GLYPH STUDIO & BUILDER
  // ---------------------------------------------------------------------------

  Widget _buildCustomBuilder(bool isDark) {
    final effectiveShape = _builderShapeOverride ??
        (_builderIsSpell ? _builderSchool.frameShape : _builderCreature.frameShape);

    final baseTheme = _builderIsSpell
        ? GlyphThemeData.fromSchool(_builderSchool)
        : GlyphThemeData.fromCreature(_builderCreature);

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
            'Compose custom holographic wireframe techno-runes with live container overrides, tier progression, and damage-colored action rings.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 20),

          // Live Preview Area
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeData.getPrimary(isDark).withValues(alpha: 0.6), width: 2),
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
                      child: _builderIsSpell
                          ? DndGlyph.spell(
                              school: _builderSchool,
                              themeData: themeData,
                              level: _builderLevelOrTier,
                              actionRings: _builderRings,
                              size: _builderSize,
                              isDarkMode: isDark,
                            )
                          : DndGlyph.monster(
                              creatureType: _builderCreature,
                              themeData: themeData,
                              crTier: _builderLevelOrTier,
                              actionRings: _builderRings,
                              size: _builderSize,
                              isDarkMode: isDark,
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _builderIsSpell
                        ? '${_builderSchool.displayName} • Level $_builderLevelOrTier'
                        : '${_builderCreature.displayName} • CR Tier $_builderLevelOrTier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: themeData.getPrimary(isDark),
                    ),
                  ),
                  Text(
                    'Container: ${effectiveShape.displayName}',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: isDark ? Colors.white70 : Colors.black54),
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
                    Icon(Icons.auto_awesome_mosaic, size: 18, color: themeData.getPrimary(isDark)),
                    const SizedBox(width: 8),
                    const Text(
                      'Auto-Populate / Read from Toolkit Presets:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    // Spell Preset Loader
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                        child: DropdownButton<SummonPreset>(
                          hint: const Text('🔮 Read Spell Card...', style: TextStyle(fontSize: 13)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          isDense: true,
                          items: SrdSummonsLibrary.allPresets.map((sp) {
                            return DropdownMenuItem<SummonPreset>(
                              value: sp,
                              child: Text('${sp.name} (${sp.levelDisplay})', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (sp) {
                            if (sp != null) {
                              setState(() {
                                _builderIsSpell = true;
                                _builderSchool = sp.glyphSchool;
                                _builderLevelOrTier = sp.glyphSpellLevel;
                                _builderShapeOverride = null;
                                _builderRings = List.from(sp.glyphActionRings);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    // Creature Stat Block Loader
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                        child: DropdownButton<MinionStatBlock>(
                          hint: const Text('🐉 Read Minion Stat Block...', style: TextStyle(fontSize: 13)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          isDense: true,
                          items: () {
                            final uniqueStatBlocks = <String, MinionStatBlock>{};
                            for (final p in SrdSummonsLibrary.allPresets) {
                              for (final sb in p.statBlocks) {
                                uniqueStatBlocks[sb.id] = sb;
                              }
                            }
                            return uniqueStatBlocks.values.map((sb) {
                              return DropdownMenuItem<MinionStatBlock>(
                                value: sb,
                                child: Text('${sb.name} (${sb.typeDisplay} CR ${sb.crDisplay})', style: const TextStyle(fontSize: 13)),
                              );
                            }).toList();
                          }(),
                          onChanged: (sb) {
                            if (sb != null) {
                              setState(() {
                                _builderIsSpell = false;
                                _builderCreature = sb.glyphCreatureType;
                                _builderLevelOrTier = sb.glyphCrTier;
                                _builderShapeOverride = null;
                                _builderRings = List.from(sb.glyphActionRings);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Controls Section
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, icon: Icon(Icons.auto_awesome), label: Text('Spell School')),
                    ButtonSegment(value: false, icon: Icon(Icons.pets), label: Text('Creature Type')),
                  ],
                  selected: {_builderIsSpell},
                  onSelectionChanged: (set) => setState(() => _builderIsSpell = set.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // School / Creature Picker
          if (_builderIsSpell) ...[
            const Text('Select Arcane Spell School:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          ] else ...[
            const Text('Select Creature Classification:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
          ],

          const SizedBox(height: 20),

          // Level / Tier Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_builderIsSpell ? 'Spell Level: $_builderLevelOrTier' : 'Threat Tier: Tier $_builderLevelOrTier', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(_builderIsSpell ? (_builderLevelOrTier == 0 ? 'Cantrip' : 'Tier ${(_builderLevelOrTier / 3).ceil()}') : 'CR ${(1 << (_builderLevelOrTier - 1)) * 4}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: _builderLevelOrTier.toDouble(),
            min: 0,
            max: _builderIsSpell ? 9 : 4,
            divisions: _builderIsSpell ? 9 : 4,
            label: '$_builderLevelOrTier',
            onChanged: (val) => setState(() => _builderLevelOrTier = val.toInt()),
          ),

          const SizedBox(height: 12),

          // Size Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Glyph Preview Size: ${_builderSize.toInt()}dp', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${_builderSize.toInt()} x ${_builderSize.toInt()} px', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          Slider(
            value: _builderSize,
            min: 48.0,
            max: 140.0,
            divisions: 23,
            label: '${_builderSize.toInt()}dp',
            onChanged: (val) => setState(() => _builderSize = val),
          ),

          const SizedBox(height: 12),

          // Frame Shape Override
          const Text('Container Shape Override (22 Geometry Silhouettes):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Default Shape'),
                selected: _builderShapeOverride == null,
                onSelected: (sel) => setState(() => _builderShapeOverride = null),
              ),
              ...GlyphFrameShape.values.map((shape) {
                return ChoiceChip(
                  label: Text(shape.displayName),
                  selected: _builderShapeOverride == shape,
                  onSelected: (sel) => setState(() => _builderShapeOverride = sel ? shape : null),
                );
              }),
            ],
          ),

          const SizedBox(height: 20),

          // Action Trait Rings Management
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dynamic Action & Attack Trait Rings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ElevatedButton.icon(
                onPressed: _builderRings.length >= 6
                    ? null
                    : () {
                        setState(() {
                          _builderRings.add(const ActionTraitRing(ringType: ActionRingType.melee));
                        });
                      },
                icon: const Icon(Icons.add, size: 16),
                label: Text(_builderRings.length >= 6 ? 'Max Rings (6)' : 'Add Ring'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_builderRings.length, (idx) {
            final ring = _builderRings[idx];
            final isConcentration = ring.ringType == ActionRingType.concentration;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Ring ${idx + 1}: ${ring.ringType.displayName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                          onPressed: () => setState(() => _builderRings.removeAt(idx)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        DropdownButton<ActionRingType>(
                          value: ring.ringType,
                          items: ActionRingType.values.map((art) => DropdownMenuItem(value: art, child: Text(art.displayName))).toList(),
                          onChanged: (newType) {
                            if (newType != null) {
                              setState(() {
                                _builderRings[idx] = ActionTraitRing(
                                  ringType: newType,
                                  damageType: newType == ActionRingType.concentration ? null : ring.damageType,
                                  label: ring.label,
                                );
                              });
                            }
                          },
                        ),
                        if (!isConcentration)
                          DropdownButton<DamageAccent?>(
                            value: ring.damageType,
                            hint: const Text('Physical (No Element)'),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Physical / Neutral')),
                              ...DamageAccent.values.map((da) => DropdownMenuItem(value: da, child: Row(children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: da.color, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(da.displayName),
                              ]))),
                            ],
                            onChanged: (newDamage) {
                              setState(() {
                                _builderRings[idx] = ActionTraitRing(ringType: ring.ringType, damageType: newDamage, label: ring.label);
                              });
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Pure Arcane Orbit (Non-Elemental)',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Export & Download Buttons
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _downloadGlyphImage,
                icon: const Icon(Icons.download, size: 20),
                label: const Text('Download Glyph Image (PNG)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final code = _builderIsSpell
                      ? 'DndGlyph.spell(school: SpellSchool.${_builderSchool.name}, level: $_builderLevelOrTier, actionRings: [...])'
                      : 'DndGlyph.monster(creatureType: CreatureType.${_builderCreature.name}, crTier: $_builderLevelOrTier, actionRings: [...])';
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied DndGlyph Dart snippet to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Dart Snippet', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _downloadGlyphImage() async {
    try {
      final boundary = _glyphBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        final name = _builderIsSpell
            ? 'glyph_spell_${_builderSchool.name}_lv$_builderLevelOrTier.png'
            : 'glyph_creature_${_builderCreature.name}_cr$_builderLevelOrTier.png';
        await GlyphImageExporter.downloadPngBytes(bytes, name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 8),
                  Text('Downloaded custom glyph image ($name)!'),
                ],
              ),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading glyph image: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 4: FULL STYLE GUIDE CODEX
  // ---------------------------------------------------------------------------

  Widget _buildFullStyleGuide(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('D&D App Glyph System: Techno-Wireframe HUD & Arcane Codex', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Official reference architecture for procedural vector glyphs, holographic wireframes, and dynamic action traits.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 24),

          // Section 1: 8 Schools of Magic
          const Text('1. The 8 Arcane Schools of Magic', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      DndGlyph.spell(school: s, level: 3, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: col)),
                          Text('Frame: ${s.frameShape.displayName}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          Text('#${s.primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}', style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
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
          const Text('2. The 14 Creature Classifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      DndGlyph.monster(creatureType: t, crTier: 2, size: 52, isDarkMode: isDark),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: col)),
                          Text('Shield: ${t.frameShape.displayName}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                          Text('#${t.primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}', style: TextStyle(fontSize: 11, color: col, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 3: 4 Progression Tiers & Threat Architecture
          const Text('3. The 4 Progression Tiers & Threat Architecture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Glyphs dynamically evolve their wireframe density, structural framing, and holographic glow based on spell level or monster Challenge Rating (CR).',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildTierInfoCard(
                tier: 1,
                title: 'Tier 1 • Initiate / CR 0–4',
                subtitle: 'Cantrips & Spell Levels 1–2 • Minor Summons',
                description: 'Single-line minimalist wireframe silhouette (1.0dp) with subtle cardinal coordinate ticks and clean vector geometry.',
                spellLevel: 1,
                isDark: isDark,
              ),
              _buildTierInfoCard(
                tier: 2,
                title: 'Tier 2 • Adept / CR 5–10',
                subtitle: 'Spell Levels 3–5 • Core Combat Summons',
                description: 'Secondary circuit wireframe trace lines, faceted corner notches, terminal solder nodes, and gimbal targeting rings.',
                spellLevel: 5,
                isDark: isDark,
              ),
              _buildTierInfoCard(
                tier: 3,
                title: 'Tier 3 • Master / CR 11–16',
                subtitle: 'Spell Levels 6–8 • Elite Planar Summons',
                description: 'Nested concentric double-frame geometry, horizontal raster scanlines, corner registration brackets [ ], and amplified neon energy glow.',
                spellLevel: 7,
                isDark: isDark,
              ),
              _buildTierInfoCard(
                tier: 4,
                title: 'Tier 4 • Archmage & Mythic Apex / CR 17+',
                subtitle: '9th-Level Pinnacle Magic • Legendary Behemoths',
                description: 'Golden apex crowning starburst, 8-point radiating energy rays, dual outer harmonic aura loops, and maximum multi-layer neon bloom.',
                spellLevel: 9,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Section 4: Action Trait Ring Geometries (Shown on their own, decoupled from color)
          const Text('4. Action & Attack Trait Ring Geometries (Standalone)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Each action trait possesses its own unique wireframe geometric profile. Rings are rendered in neutral titanium wireframe by default.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ActionRingType.values.map((art) {
              return _buildStandaloneRingCard(art, isDark);
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Section 5: Damage Illumination Spectrum (Independent Energy Color Layer)
          const Text('5. Damage Type Illumination Spectrum (11 Energy Types)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Any action trait ring can dynamically illuminate in any of these 11 damage energy hues when an attack deals that specific damage type.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: DamageAccent.values.map((da) {
              return Card(
                color: isDark ? const Color(0xFF090D16) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: da.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: da.color.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(da.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: da.color)),
                          Text('#${da.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}', style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? Colors.white60 : Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTierInfoCard({
    required int tier,
    required String title,
    required String subtitle,
    required String description,
    required int spellLevel,
    required bool isDark,
  }) {
    final tierColor = switch (tier) {
      1 => const Color(0xFF38BDF8), // Cyan
      2 => const Color(0xFFFBBF24), // Amber
      3 => const Color(0xFFA855F7), // Purple
      4 => const Color(0xFFF43F5E), // Rose / Apex Red
      _ => const Color(0xFF38BDF8),
    };

    return Card(
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tierColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                DndGlyph.spell(
                  school: SpellSchool.evocation,
                  level: spellLevel,
                  size: 54,
                  isDarkMode: isDark,
                ),
                const SizedBox(height: 6),
                DndGlyph.monster(
                  creatureType: CreatureType.dragon,
                  crTier: tier,
                  size: 54,
                  isDarkMode: isDark,
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: tierColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandaloneRingCard(ActionRingType ringType, bool isDark) {
    final ringColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    final description = switch (ringType) {
      ActionRingType.melee => 'Faceted Octagonal Ring with 4 Blade Ticks',
      ActionRingType.ranged => 'Circular Reticle Ring with 4-Axis Crosshairs',
      ActionRingType.recharge => 'Segmented Hexagonal Ring with 6 Pulse Gaps',
      ActionRingType.reaction => 'Shielded Square Ring with Corner Brackets',
      ActionRingType.concentration => 'Dual-Harmonic Orbital Wireframe Loop',
      ActionRingType.legendary => 'Radial Starburst Crown with 8 Apex Rays',
    };

    return Card(
      color: isDark ? const Color(0xFF090D16) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: CustomPaint(
                painter: _StandaloneRingPainter(
                  ringType: ringType,
                  color: ringColor,
                  isDarkMode: isDark,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ringType.displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ringColor)),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETAIL DIALOGS
  // ---------------------------------------------------------------------------

  void _showSpellDetails(GlyphSpellEntry spell, bool isDark) {
    final schoolColor = spell.school.getLegibleColor(isDark);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
        title: Row(
          children: [
            DndGlyph.spell(
              school: spell.school,
              level: spell.level,
              actionRings: spell.actionRings,
              damageAccent: spell.damageAccent,
              size: 72,
              isDarkMode: isDark,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spell.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(
                    '${spell.school.displayName} (${spell.levelDescription})',
                    style: TextStyle(fontSize: 13, color: schoolColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Casting Time', spell.castingTime),
            _buildDetailRow('Range', spell.range),
            _buildDetailRow('Duration', spell.duration),
            const SizedBox(height: 12),
            const Text('Effect Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(spell.summary, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: schoolColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: schoolColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action Trait Rings Telemetry:',
                    style: TextStyle(fontSize: 12, color: schoolColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...spell.actionRings.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• ${r.ringType.displayName}: ${r.label ?? ""} ${r.damageType != null ? "(${r.damageType!.displayName} Glow)" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: r.getEffectiveColor(schoolColor),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreatureDetails(GlyphCreatureEntry creature, bool isDark) {
    final typeColor = creature.type.getLegibleColor(isDark);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
        title: Row(
          children: [
            DndGlyph.monster(
              creatureType: creature.type,
              crTier: creature.crTier,
              actionRings: creature.actionRings,
              actionBadge: creature.actionBadge,
              size: 72,
              isDarkMode: isDark,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(creature.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(
                    '${creature.type.displayName} (CR ${creature.cr})',
                    style: TextStyle(fontSize: 13, color: typeColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Armor Class', '${creature.ac}'),
            _buildDetailRow('Hit Points', '${creature.hp}'),
            _buildDetailRow('Speed', creature.speed),
            _buildDetailRow('Primary Attack', creature.primaryAttack),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: typeColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action Trait Rings Telemetry:',
                    style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  ...creature.actionRings.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• ${r.ringType.displayName}: ${r.label ?? ""} ${r.damageType != null ? "(${r.damageType!.displayName} Glow)" : ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: r.getEffectiveColor(typeColor),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
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
            child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: accentColor,
                fontWeight: accentColor != null ? FontWeight.bold : FontWeight.normal,
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

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

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
    _drawRingGeometry(canvas, center, r, ringType, scale, glowPaint, finePaint, nodeFill, isGlow: true);
    _drawRingGeometry(canvas, center, r, ringType, scale, strokePaint, finePaint, nodeFill, isGlow: false);
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
          canvas.drawLine(Offset(center.dx, center.dy - r - 1.5 * scale), Offset(center.dx, center.dy - r + 1.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx, center.dy + r - 1.5 * scale), Offset(center.dx, center.dy + r + 1.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx - r - 1.5 * scale, center.dy), Offset(center.dx - r + 1.5 * scale, center.dy), finePaint);
          canvas.drawLine(Offset(center.dx + r - 1.5 * scale, center.dy), Offset(center.dx + r + 1.5 * scale, center.dy), finePaint);
          canvas.drawCircle(Offset(center.dx, center.dy - r), 1.0 * scale, nodeFill);
          canvas.drawCircle(Offset(center.dx, center.dy + r), 1.0 * scale, nodeFill);
          canvas.drawCircle(Offset(center.dx - r, center.dy), 1.0 * scale, nodeFill);
          canvas.drawCircle(Offset(center.dx + r, center.dy), 1.0 * scale, nodeFill);
        }
      case ActionRingType.ranged:
        canvas.drawCircle(center, r, strokePaint);
        if (!isGlow) {
          canvas.drawLine(Offset(center.dx, center.dy - r - 2.5 * scale), Offset(center.dx, center.dy - r + 2.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx, center.dy + r - 2.5 * scale), Offset(center.dx, center.dy + r + 2.5 * scale), finePaint);
          canvas.drawLine(Offset(center.dx - r - 2.5 * scale, center.dy), Offset(center.dx - r + 2.5 * scale, center.dy), finePaint);
          canvas.drawLine(Offset(center.dx + r - 2.5 * scale, center.dy), Offset(center.dx + r + 2.5 * scale, center.dy), finePaint);
        }
      case ActionRingType.recharge:
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final a1 = (i * 60.0 + 8.0) * 3.14159265 / 180.0;
          final a2 = ((i + 1) * 60.0 - 8.0) * 3.14159265 / 180.0;
          final p1 = Offset(center.dx + r * 0.95 * cos(a1), center.dy + r * 0.95 * sin(a1));
          final p2 = Offset(center.dx + r * 0.95 * cos(a2), center.dy + r * 0.95 * sin(a2));
          if (i == 0) {
            path.moveTo(p1.dx, p1.dy);
          } else {
            path.moveTo(p1.dx, p1.dy);
          }
          path.lineTo(p2.dx, p2.dy);
        }
        canvas.drawPath(path, strokePaint);
      case ActionRingType.reaction:
        final half = r * 0.85;
        final rect = Rect.fromCenter(center: center, width: half * 2, height: half * 2);
        canvas.drawRect(rect, strokePaint);
        if (!isGlow) {
          canvas.drawCircle(rect.topLeft, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.topRight, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.bottomLeft, 1.2 * scale, nodeFill);
          canvas.drawCircle(rect.bottomRight, 1.2 * scale, nodeFill);
        }
      case ActionRingType.concentration:
        canvas.drawOval(Rect.fromCenter(center: center, width: r * 2.1, height: r * 1.5), strokePaint);
        if (!isGlow) {
          canvas.drawOval(Rect.fromCenter(center: center, width: r * 1.5, height: r * 2.1), finePaint);
        }
      case ActionRingType.legendary:
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final a = (i * 45.0 - 90.0) * 3.14159265 / 180.0;
          final outerR = (i % 2 == 0) ? r * 1.15 : r * 0.85;
          final pt = Offset(center.dx + outerR * cos(a), center.dy + outerR * sin(a));
          if (i == 0) {
            path.moveTo(pt.dx, pt.dy);
          } else {
            path.lineTo(pt.dx, pt.dy);
          }
        }
        path.close();
        canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StandaloneRingPainter oldDelegate) =>
      oldDelegate.ringType != ringType ||
      oldDelegate.color != color ||
      oldDelegate.isDarkMode != isDarkMode;
}

