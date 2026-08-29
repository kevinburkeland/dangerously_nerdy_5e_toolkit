import 'package:flutter/material.dart';
import '../../models/arena/arena_combatant.dart';
import '../../models/dm_screen_data.dart';
import '../../models/monster_codex_data.dart';
import '../../models/srd_summons/minion_stat_block.dart';
import '../dialogs/creature_stat_block_dialog.dart';
import '../glyphs/dnd_glyph.dart';

/// Modal bottom sheet allowing users to search, filter, and add monsters to an Arena team.
class ArenaMonsterPickerSheet extends StatefulWidget {
  final ArenaTeam team;
  final DmRulesEdition edition;
  final void Function(MonsterItem monster, int count) onMonstersSelected;

  const ArenaMonsterPickerSheet({
    super.key,
    required this.team,
    required this.edition,
    required this.onMonstersSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required ArenaTeam team,
    required DmRulesEdition edition,
    required void Function(MonsterItem monster, int count) onMonstersSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ArenaMonsterPickerSheet(
        team: team,
        edition: edition,
        onMonstersSelected: onMonstersSelected,
      ),
    );
  }

  @override
  State<ArenaMonsterPickerSheet> createState() => _ArenaMonsterPickerSheetState();
}

class _ArenaMonsterPickerSheetState extends State<ArenaMonsterPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  MonsterCrBand _selectedBand = MonsterCrBand.all;
  String? _selectedType;
  int _selectedCount = 1;

  final List<String> _creatureTypes = [
    'All Types',
    'Aberration',
    'Beast',
    'Celestial',
    'Construct',
    'Dragon',
    'Elemental',
    'Fey',
    'Fiend',
    'Giant',
    'Humanoid',
    'Monstrosity',
    'Ooze',
    'Plant',
    'Undead',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MonsterItem> _filterMonsters() {
    final query = _searchController.text.trim();
    double? minCr;
    double? maxCr;

    switch (_selectedBand) {
      case MonsterCrBand.cr0ToQuarter:
        minCr = 0;
        maxCr = 0.25;
      case MonsterCrBand.crHalfToOne:
        minCr = 0.5;
        maxCr = 1.0;
      case MonsterCrBand.crTwoToFour:
        minCr = 2.0;
        maxCr = 4.0;
      case MonsterCrBand.crFiveToEight:
        minCr = 5.0;
        maxCr = 8.0;
      case MonsterCrBand.crNinePlus:
        minCr = 9.0;
        maxCr = double.infinity;
      case MonsterCrBand.all:
        break;
    }

    final typeFilter = (_selectedType == null || _selectedType == 'All Types') ? null : _selectedType;

    return MonsterCodexLibrary.search(
      query,
      typeFilter: typeFilter,
      minCr: minCr,
      maxCr: maxCr,
      edition: widget.edition,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final teamColor = widget.team.color;
    final monsters = _filterMonsters();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: teamColor.withAlpha(50),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(100),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(widget.team.icon, color: teamColor, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Add Monster to ${widget.team.label}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: teamColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search input & Quantity selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search SRD monsters, traits, attacks...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Quantity Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: teamColor.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _selectedCount > 1
                            ? () => setState(() => _selectedCount--)
                            : null,
                      ),
                      Text(
                        'x$_selectedCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: teamColor,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _selectedCount < 20
                            ? () => setState(() => _selectedCount++)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter chips (CR Band)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: MonsterCrBand.values.map((band) {
                final isSelected = _selectedBand == band;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(band.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedBand = band;
                      });
                    },
                    selectedColor: teamColor.withAlpha(40),
                    checkmarkColor: teamColor,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? teamColor : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          // Filter chips (Creature Type)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: _creatureTypes.map((type) {
                final isSelected = (_selectedType == null && type == 'All Types') || (_selectedType == type);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedType = type == 'All Types' ? null : type;
                      });
                    },
                    selectedColor: teamColor.withAlpha(35),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? teamColor : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 8),

          // Monster List
          Expanded(
            child: monsters.isEmpty
                ? Center(
                    child: Text(
                      'No monsters match filters.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: monsters.length,
                    itemBuilder: (context, index) {
                      final monster = monsters[index];
                      final sb = monster.getStatBlock(widget.edition);

                      final monsterName = monster.getName(widget.edition);

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: DndGlyph.monster(
                            creatureType: sb.glyphCreatureType,
                            crTier: sb.glyphCrTier,
                            actionRings: sb.glyphActionRings,
                            glyphColor: teamColor,
                            size: 38,
                            isDarkMode: isDark,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  monsterName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (monster.isHomebrew) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.6)),
                                  ),
                                  child: const Text('HOMEBREW', style: TextStyle(color: Colors.purpleAccent, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'CR ${sb.crDisplay} • HP ${sb.maxHp} • AC ${sb.ac} • ${sb.typeDisplay}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          onTap: () {
                            CreatureStatBlockDialog.show(
                              context,
                              statBlock: sb,
                              addToSquadLabel: 'ADD TO ${widget.team.label.toUpperCase()}',
                              onAddToSquad: () {
                                widget.onMonstersSelected(monster, _selectedCount);
                                Navigator.pop(context);
                              },
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: teamColor.withAlpha(isDark ? 220 : 200),
                                ),
                                tooltip: '$monsterName Codex Card',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  CreatureStatBlockDialog.show(
                                    context,
                                    statBlock: sb,
                                    addToSquadLabel: 'ADD TO ${widget.team.label.toUpperCase()}',
                                    onAddToSquad: () {
                                      widget.onMonstersSelected(monster, _selectedCount);
                                      Navigator.pop(context);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(_selectedCount > 1 ? 'Add ($_selectedCount)' : 'Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teamColor.withAlpha(35),
                                  foregroundColor: teamColor,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: teamColor.withAlpha(120)),
                                  ),
                                ),
                                onPressed: () {
                                  widget.onMonstersSelected(monster, _selectedCount);
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
