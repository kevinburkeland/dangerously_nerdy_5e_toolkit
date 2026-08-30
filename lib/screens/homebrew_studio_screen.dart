import 'package:flutter/material.dart';
import '../models/domain/core_types.dart';
import '../models/domain/homebrew_extended_entities.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../services/haptic_service.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../widgets/homebrew/equipment_builder_dialog.dart';
import '../widgets/homebrew/homebrew_bulk_deleter_dialog.dart';
import '../widgets/homebrew/homebrew_export_dialog.dart';
import '../widgets/homebrew/homebrew_import_preview_dialog.dart';
import '../widgets/homebrew/homebrew_refresher_dialog.dart';
import '../widgets/homebrew/monster_builder_dialog.dart';
import '../widgets/homebrew/spell_builder_dialog.dart';

/// Comprehensive Homebrew Studio screen allowing users to create, edit, import, re-parse, and manage
/// custom spells, monsters, magic items, classes, subclasses, races, feats, backgrounds, and rules.
class HomebrewStudioScreen extends StatefulWidget {
  const HomebrewStudioScreen({super.key});

  @override
  State<HomebrewStudioScreen> createState() => _HomebrewStudioScreenState();
}

class _HomebrewStudioScreenState extends State<HomebrewStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _persistence = HomebrewPersistenceService();

  List<Spell> _spells = [];
  List<Monster> _monsters = [];
  List<EquipmentItem> _items = [];
  List<CharacterClass> _classes = [];
  List<Subclass> _subclasses = [];
  List<Race> _races = [];
  List<Feat> _feats = [];
  List<Background> _backgrounds = [];
  List<HomebrewCompendiumEntry> _otherEntries = [];
  bool _isLoading = true;

  // Multi-select batch deletion mode
  bool _isSelectionMode = false;
  final Set<String> _selectedSlugs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedSlugs.clear();
        });
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final spells = await _persistence.loadCustomSpells();
    final monsters = await _persistence.loadCustomMonsters();
    final items = await _persistence.loadCustomItems();
    final classes = await _persistence.loadCustomClasses();
    final subclasses = await _persistence.loadCustomSubclasses();
    final races = await _persistence.loadCustomRaces();
    final feats = await _persistence.loadCustomFeats();
    final backgrounds = await _persistence.loadCustomBackgrounds();
    final others = await _persistence.loadCustomOtherEntries();

    if (mounted) {
      setState(() {
        _spells = spells;
        _monsters = monsters;
        _items = items;
        _classes = classes;
        _subclasses = subclasses;
        _races = races;
        _feats = feats;
        _backgrounds = backgrounds;
        _otherEntries = others;
        _selectedSlugs.clear();
        _isLoading = false;
      });
    }
  }

  EntityType get _currentTabEntityType => switch (_tabController.index) {
        0 => EntityType.spell,
        1 => EntityType.monster,
        2 => EntityType.equipment,
        3 => EntityType.classDefinition,
        4 => EntityType.species,
        5 => EntityType.feat,
        6 => EntityType.background,
        7 => EntityType.custom,
        _ => EntityType.custom,
      };

  Future<void> _openRefresherDialog() async {
    HapticService.selectionTick(context);
    final result = await showDialog<ReparseResult>(
      context: context,
      builder: (ctx) => const HomebrewRefresherDialog(),
    );
    if (result != null) {
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refreshed & upgraded ${result.updatedCount} items'
              '${result.srdRemovedCount > 0 ? " (${result.srdRemovedCount} SRD duplicates pruned)" : ""}.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openBulkDeleterDialog() async {
    HapticService.selectionTick(context);
    final deleted = await showDialog<int>(
      context: context,
      builder: (ctx) => const HomebrewBulkDeleterDialog(),
    );
    if (deleted != null && deleted > 0) {
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully deleted $deleted custom entities.')),
        );
      }
    }
  }

  Future<void> _deleteSelectedInActiveTab() async {
    if (_selectedSlugs.isEmpty) return;
    final count = _selectedSlugs.length;
    final type = _currentTabEntityType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Selected Items?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $count selected items from this category? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete $count Items'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticService.selectionTick(context);
      await _persistence.deleteCustomEntitiesBatch(type, _selectedSlugs.toList());
      _selectedSlugs.clear();
      _isSelectionMode = false;
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count items')),
        );
      }
    }
  }

  Future<void> _clearActiveCategory() async {
    final type = _currentTabEntityType;
    final typeName = switch (type) {
      EntityType.spell => 'all Spells',
      EntityType.monster => 'all Monsters',
      EntityType.equipment => 'all Items',
      EntityType.classDefinition => 'all Classes and Subclasses',
      EntityType.species => 'all Species / Races',
      EntityType.feat => 'all Feats',
      EntityType.background => 'all Backgrounds',
      EntityType.custom => 'all Rules & Tables',
      _ => 'all entries in this category',
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Clear Entire Category?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete $typeName? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Category'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticService.selectionTick(context);
      if (type == EntityType.classDefinition) {
        await _persistence.clearHomebrewCategory(EntityType.classDefinition);
        await _persistence.clearHomebrewCategory(EntityType.subclass);
      } else {
        await _persistence.clearHomebrewCategory(type);
      }
      _selectedSlugs.clear();
      _isSelectionMode = false;
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cleared $typeName')),
        );
      }
    }
  }

  Future<void> _createOrEditSpell([Spell? existing]) async {
    final result = await showDialog<Spell>(
      context: context,
      builder: (ctx) => SpellBuilderDialog(initialSpell: existing),
    );
    if (result != null) {
      await _persistence.saveCustomSpell(result);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved spell "${result.name}"')),
        );
      }
    }
  }

  Future<void> _deleteSpell(String slug) async {
    await _persistence.deleteCustomSpell(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted spell')),
      );
    }
  }

  Future<void> _createOrEditMonster([Monster? existing]) async {
    final result = await showDialog<Monster>(
      context: context,
      builder: (ctx) => MonsterBuilderDialog(initialMonster: existing),
    );
    if (result != null) {
      await _persistence.saveCustomMonster(result);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved monster "${result.name}"')),
        );
      }
    }
  }

  Future<void> _deleteMonster(String slug) async {
    await _persistence.deleteCustomMonster(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted monster')),
      );
    }
  }

  Future<void> _createOrEditItem([EquipmentItem? existing]) async {
    final result = await showDialog<EquipmentItem>(
      context: context,
      builder: (ctx) => EquipmentBuilderDialog(initialItem: existing),
    );
    if (result != null) {
      await _persistence.saveCustomItem(result);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved item "${result.name}"')),
        );
      }
    }
  }

  Future<void> _deleteItem(String slug) async {
    await _persistence.deleteCustomItem(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted item')),
      );
    }
  }

  Future<void> _deleteClass(String slug) async {
    await _persistence.deleteCustomClass(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted class')),
      );
    }
  }

  Future<void> _deleteSubclass(String slug) async {
    await _persistence.deleteCustomSubclass(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted subclass')),
      );
    }
  }

  Future<void> _deleteRace(String slug) async {
    await _persistence.deleteCustomRace(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted race / species')),
      );
    }
  }

  Future<void> _deleteFeat(String slug) async {
    await _persistence.deleteCustomFeat(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted feat')),
      );
    }
  }

  Future<void> _deleteBackground(String slug) async {
    await _persistence.deleteCustomBackground(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted background')),
      );
    }
  }

  Future<void> _deleteOtherEntry(String slug) async {
    await _persistence.deleteCustomOtherEntry(slug);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleted compendium entry')),
      );
    }
  }

  void _showDetailModal({
    required String title,
    required String category,
    required String contentMarkdown,
    List<String>? metadataLines,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(category, style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (metadataLines != null && metadataLines.isNotEmpty) ...[
                for (final line in metadataLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                const Divider(),
              ],
              Text(
                contentMarkdown.isNotEmpty ? contentMarkdown : 'No additional descriptions provided.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openImportDialog() async {
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => const HomebrewImportPreviewDialog(),
    );
    if (count != null && count > 0) {
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported $count custom entities!',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openExportDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => const HomebrewExportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homebrew Studio'),
        actions: [
          IconButton(
            tooltip: 'JSON Refresher & AST Upgrade',
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _openRefresherDialog,
          ),
          IconButton(
            tooltip: 'Bulk Homebrew Deleter',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _openBulkDeleterDialog,
          ),
          IconButton(
            tooltip: 'Export Homebrew Pack',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _openExportDialog,
          ),
          IconButton(
            tooltip: 'Import Homebrew / Compendium JSON',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _openImportDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.auto_awesome), text: 'Spells (${_spells.length})'),
            Tab(icon: const Icon(Icons.pets), text: 'Monsters (${_monsters.length})'),
            Tab(icon: const Icon(Icons.shield), text: 'Items (${_items.length})'),
            Tab(icon: const Icon(Icons.military_tech), text: 'Classes (${_classes.length + _subclasses.length})'),
            Tab(icon: const Icon(Icons.person), text: 'Races (${_races.length})'),
            Tab(icon: const Icon(Icons.stars), text: 'Feats (${_feats.length})'),
            Tab(icon: const Icon(Icons.menu_book), text: 'Backgrounds (${_backgrounds.length})'),
            Tab(icon: const Icon(Icons.table_chart), text: 'Invocations & Rules (${_otherEntries.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSpellsTab(theme),
                _buildMonstersTab(theme),
                _buildItemsTab(theme),
                _buildClassesTab(theme),
                _buildRacesTab(theme),
                _buildFeatsTab(theme),
                _buildBackgroundsTab(theme),
                _buildOtherEntriesTab(theme),
              ],
            ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                switch (_tabController.index) {
                  case 0:
                    _createOrEditSpell();
                  case 1:
                    _createOrEditMonster();
                  case 2:
                    _createOrEditItem();
                  default:
                    _openImportDialog();
                }
              },
              icon: Icon(_tabController.index <= 2 ? Icons.add : Icons.download),
              label: Text(
                _tabController.index == 0
                    ? 'New Spell'
                    : (_tabController.index == 1
                        ? 'New Monster'
                        : (_tabController.index == 2 ? 'New Item' : 'Import JSON')),
              ),
            ),
    );
  }

  Widget _buildTabToolbar({
    required int totalCount,
    required List<String> allSlugs,
    required ThemeData theme,
  }) {
    if (totalCount == 0) return const SizedBox.shrink();

    if (_isSelectionMode) {
      final selectedCount = _selectedSlugs.length;
      final allSelected = selectedCount == totalCount && totalCount > 0;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        child: Row(
          children: [
            Checkbox(
              value: allSelected ? true : (selectedCount > 0 ? null : false),
              tristate: true,
              onChanged: (val) {
                setState(() {
                  if (allSelected) {
                    _selectedSlugs.clear();
                  } else {
                    _selectedSlugs.addAll(allSlugs);
                  }
                });
              },
            ),
            Text(
              'Selected: $selectedCount / $totalCount',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Spacer(),
            if (selectedCount > 0)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: _deleteSelectedInActiveTab,
                icon: const Icon(Icons.delete, size: 16),
                label: Text('Delete ($selectedCount)'),
              ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedSlugs.clear();
                });
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalCount custom ${totalCount == 1 ? "entry" : "entries"}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedSlugs.clear();
                  });
                },
                icon: const Icon(Icons.checklist, size: 16),
                label: const Text('Select Mode'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Clear category',
                icon: const Icon(Icons.delete_sweep, size: 18, color: Colors.redAccent),
                onPressed: _clearActiveCategory,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpellsTab(ThemeData theme) {
    if (_spells.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.auto_awesome_outlined,
        title: 'No Custom Spells',
        subtitle: 'Create your first homebrew spell or import compendium JSON.',
        onAction: () => _createOrEditSpell(),
      );
    }

    final slugs = _spells.map((s) => s.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _spells.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _spells.length,
            itemBuilder: (ctx, idx) {
              final spell = _spells[idx];
              final isSelected = _selectedSlugs.contains(spell.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(spell.id.slug);
                            } else {
                              _selectedSlugs.add(spell.id.slug);
                            }
                          });
                        }
                      : null,
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(spell.id.slug);
                              } else {
                                _selectedSlugs.remove(spell.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.purple.withValues(alpha: 0.2),
                          child: Text(
                            spell.level == 0 ? 'C' : '${spell.level}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                          ),
                        ),
                  title: Text(spell.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${spell.level == 0 ? "Cantrip" : "Level ${spell.level}"} ${spell.school} • ${spell.castingTime.actionType.name}',
                  ),
                  trailing: _isSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _createOrEditSpell(spell),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteSpell(spell.slug),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonstersTab(ThemeData theme) {
    if (_monsters.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.pets_outlined,
        title: 'No Custom Monsters',
        subtitle: 'Build custom creature statblocks or import bestiary JSON.',
        onAction: () => _createOrEditMonster(),
      );
    }

    final slugs = _monsters.map((m) => m.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _monsters.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _monsters.length,
            itemBuilder: (ctx, idx) {
              final monster = _monsters[idx];
              final isSelected = _selectedSlugs.contains(monster.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(monster.id.slug);
                            } else {
                              _selectedSlugs.add(monster.id.slug);
                            }
                          });
                        }
                      : null,
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(monster.id.slug);
                              } else {
                                _selectedSlugs.remove(monster.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.deepOrange.withValues(alpha: 0.2),
                          child: Text(
                            'CR ${monster.challengeRating}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),
                          ),
                        ),
                  title: Text(monster.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${monster.size} ${monster.monsterType} • AC ${monster.armorClass} • HP ${monster.hitPoints}',
                  ),
                  trailing: _isSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _createOrEditMonster(monster),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteMonster(monster.slug),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTab(ThemeData theme) {
    if (_items.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.shield_outlined,
        title: 'No Custom Items',
        subtitle: 'Craft custom magic items and equipment or import item JSON.',
        onAction: () => _createOrEditItem(),
      );
    }

    final slugs = _items.map((i) => i.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _items.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (ctx, idx) {
              final item = _items[idx];
              final isSelected = _selectedSlugs.contains(item.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(item.id.slug);
                            } else {
                              _selectedSlugs.add(item.id.slug);
                            }
                          });
                        }
                      : null,
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(item.id.slug);
                              } else {
                                _selectedSlugs.remove(item.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: 0.2),
                          child: const Icon(Icons.shield, color: Colors.amberAccent),
                        ),
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.rarity} ${item.itemType}'),
                  trailing: _isSelectionMode
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _createOrEditItem(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteItem(item.slug),
                            ),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassesTab(ThemeData theme) {
    final combinedCount = _classes.length + _subclasses.length;
    if (combinedCount == 0) {
      return _buildEmptyState(
        theme,
        icon: Icons.military_tech_outlined,
        title: 'No Custom Classes',
        subtitle: 'Import class or subclass packages via the JSON Importer.',
        onAction: _openImportDialog,
      );
    }

    final allSlugs = [
      ..._classes.map((c) => c.id.slug),
      ..._subclasses.map((s) => s.id.slug),
    ];

    return Column(
      children: [
        _buildTabToolbar(totalCount: combinedCount, allSlugs: allSlugs, theme: theme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_classes.isNotEmpty) ...[
                Text('Classes (${_classes.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final cl in _classes) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: _selectedSlugs.contains(cl.id.slug)
                        ? RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: ListTile(
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (_selectedSlugs.contains(cl.id.slug)) {
                                  _selectedSlugs.remove(cl.id.slug);
                                } else {
                                  _selectedSlugs.add(cl.id.slug);
                                }
                              });
                            }
                          : () => _showDetailModal(
                              title: cl.name,
                              category: 'Class (${cl.hitDie})',
                              contentMarkdown: cl.featuresMarkdown,
                              metadataLines: [
                                'Hit Die: ${cl.hitDie}',
                                if (cl.savingThrows.isNotEmpty) 'Saving Throws: ${cl.savingThrows.join(", ")}',
                                if (cl.primaryAbility != null) 'Primary Ability: ${cl.primaryAbility}',
                              ],
                            ),
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: _selectedSlugs.contains(cl.id.slug),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedSlugs.add(cl.id.slug);
                                  } else {
                                    _selectedSlugs.remove(cl.id.slug);
                                  }
                                });
                              },
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.2),
                              child: Text(cl.hitDie, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            ),
                      title: Text(cl.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Hit Die: ${cl.hitDie} • Primary: ${cl.primaryAbility ?? "Custom"} • Subclasses: ${cl.subclasses.length}'),
                      trailing: _isSelectionMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteClass(cl.id.slug),
                            ),
                    ),
                  ),
                ],
              ],
              if (_subclasses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Subclasses (${_subclasses.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final sub in _subclasses) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: _selectedSlugs.contains(sub.id.slug)
                        ? RoundedRectangleBorder(
                            side: BorderSide(color: theme.colorScheme.primary, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: ListTile(
                      onTap: _isSelectionMode
                          ? () {
                              setState(() {
                                if (_selectedSlugs.contains(sub.id.slug)) {
                                  _selectedSlugs.remove(sub.id.slug);
                                } else {
                                  _selectedSlugs.add(sub.id.slug);
                                }
                              });
                            }
                          : () => _showDetailModal(
                              title: sub.name,
                              category: 'Subclass (${sub.classSlug})',
                              contentMarkdown: sub.featuresMarkdown,
                            ),
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: _selectedSlugs.contains(sub.id.slug),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedSlugs.add(sub.id.slug);
                                  } else {
                                    _selectedSlugs.remove(sub.id.slug);
                                  }
                                });
                              },
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.indigo.withValues(alpha: 0.2),
                              child: const Icon(Icons.star, color: Colors.indigoAccent),
                            ),
                      title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Class: ${sub.classSlug} • ${sub.shortName}'),
                      trailing: _isSelectionMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteSubclass(sub.id.slug),
                            ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRacesTab(ThemeData theme) {
    if (_races.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.person_outline,
        title: 'No Custom Races / Species',
        subtitle: 'Import species or lineages via the JSON Importer.',
        onAction: _openImportDialog,
      );
    }

    final slugs = _races.map((r) => r.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _races.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _races.length,
            itemBuilder: (ctx, idx) {
              final race = _races[idx];
              final isSelected = _selectedSlugs.contains(race.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(race.id.slug);
                            } else {
                              _selectedSlugs.add(race.id.slug);
                            }
                          });
                        }
                      : () => _showDetailModal(
                          title: race.name,
                          category: 'Species / Race (${race.size})',
                          contentMarkdown: race.traitsMarkdown,
                          metadataLines: [
                            'Size: ${race.size}',
                            'Speed: ${race.speed}',
                            if (race.abilityScoreSummary != null) 'Abilities: ${race.abilityScoreSummary}',
                          ],
                        ),
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(race.id.slug);
                              } else {
                                _selectedSlugs.remove(race.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.teal.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, color: Colors.tealAccent),
                        ),
                  title: Text(race.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${race.size} • Speed: ${race.speed} • Subraces: ${race.subraces.length}'),
                  trailing: _isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteRace(race.id.slug),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatsTab(ThemeData theme) {
    if (_feats.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.stars_outlined,
        title: 'No Custom Feats',
        subtitle: 'Import homebrew feats and epic boons via the JSON Importer.',
        onAction: _openImportDialog,
      );
    }

    final slugs = _feats.map((f) => f.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _feats.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _feats.length,
            itemBuilder: (ctx, idx) {
              final feat = _feats[idx];
              final isSelected = _selectedSlugs.contains(feat.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(feat.id.slug);
                            } else {
                              _selectedSlugs.add(feat.id.slug);
                            }
                          });
                        }
                      : () => _showDetailModal(
                          title: feat.name,
                          category: 'Feat (${feat.category})',
                          contentMarkdown: feat.descriptionMarkdown,
                          metadataLines: [
                            'Category: ${feat.category}',
                            if (feat.prerequisite != null) 'Prerequisite: ${feat.prerequisite}',
                          ],
                        ),
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(feat.id.slug);
                              } else {
                                _selectedSlugs.remove(feat.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          child: const Icon(Icons.stars, color: Colors.orangeAccent),
                        ),
                  title: Text(feat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${feat.category}${feat.prerequisite != null ? " • Prereq: ${feat.prerequisite}" : ""}'),
                  trailing: _isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteFeat(feat.id.slug),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundsTab(ThemeData theme) {
    if (_backgrounds.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.menu_book_outlined,
        title: 'No Custom Backgrounds',
        subtitle: 'Import character backgrounds via the JSON Importer.',
        onAction: _openImportDialog,
      );
    }

    final slugs = _backgrounds.map((b) => b.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _backgrounds.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _backgrounds.length,
            itemBuilder: (ctx, idx) {
              final bg = _backgrounds[idx];
              final isSelected = _selectedSlugs.contains(bg.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(bg.id.slug);
                            } else {
                              _selectedSlugs.add(bg.id.slug);
                            }
                          });
                        }
                      : () => _showDetailModal(
                          title: bg.name,
                          category: 'Background',
                          contentMarkdown: bg.descriptionMarkdown,
                          metadataLines: [
                            if (bg.skillProficiencies.isNotEmpty) 'Skill Proficiencies: ${bg.skillProficiencies.join(", ")}',
                            if (bg.toolProficiencies.isNotEmpty) 'Tool Proficiencies: ${bg.toolProficiencies.join(", ")}',
                            if (bg.languages.isNotEmpty) 'Languages: ${bg.languages.join(", ")}',
                            if (bg.originFeat != null) 'Origin Feat: ${bg.originFeat}',
                          ],
                        ),
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(bg.id.slug);
                              } else {
                                _selectedSlugs.remove(bg.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.brown.withValues(alpha: 0.2),
                          child: const Icon(Icons.menu_book, color: Colors.amberAccent),
                        ),
                  title: Text(bg.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Skills: ${bg.skillProficiencies.join(", ")}${bg.originFeat != null ? " • Feat: ${bg.originFeat}" : ""}'),
                  trailing: _isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteBackground(bg.id.slug),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOtherEntriesTab(ThemeData theme) {
    if (_otherEntries.isEmpty) {
      return _buildEmptyState(
        theme,
        icon: Icons.table_chart_outlined,
        title: 'No Custom Invocations or Rules',
        subtitle: 'Import custom Eldritch Invocations, optional features, tables, or rules via the JSON Importer.',
        onAction: _openImportDialog,
      );
    }

    final slugs = _otherEntries.map((o) => o.id.slug).toList();

    return Column(
      children: [
        _buildTabToolbar(totalCount: _otherEntries.length, allSlugs: slugs, theme: theme),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _otherEntries.length,
            itemBuilder: (ctx, idx) {
              final entry = _otherEntries[idx];
              final isSelected = _selectedSlugs.contains(entry.id.slug);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: isSelected
                    ? RoundedRectangleBorder(
                        side: BorderSide(color: theme.colorScheme.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      )
                    : null,
                child: ListTile(
                  onTap: _isSelectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedSlugs.remove(entry.id.slug);
                            } else {
                              _selectedSlugs.add(entry.id.slug);
                            }
                          });
                        }
                      : () => _showDetailModal(
                          title: entry.name,
                          category: entry.category,
                          contentMarkdown: entry.descriptionMarkdown,
                        ),
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedSlugs.add(entry.id.slug);
                              } else {
                                _selectedSlugs.remove(entry.id.slug);
                              }
                            });
                          },
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                          child: const Icon(Icons.table_chart, color: Colors.cyanAccent),
                        ),
                  title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Category: ${entry.category}'),
                  trailing: _isSelectionMode
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteOtherEntry(entry.id.slug),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: const Text('Create New'),
            ),
          ],
        ),
      ),
    );
  }
}
