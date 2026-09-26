import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/homebrew_other_category.dart';
import '../../services/haptic_service.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog allowing users to view entity counts by category, select categories to delete in bulk,
/// or perform a full homebrew storage wipe with double-confirmation safeguards.
class HomebrewBulkDeleterDialog extends StatefulWidget {
  const HomebrewBulkDeleterDialog({super.key});

  @override
  State<HomebrewBulkDeleterDialog> createState() =>
      _HomebrewBulkDeleterDialogState();
}

class _HomebrewBulkDeleterDialogState extends State<HomebrewBulkDeleterDialog> {
  final _persistence = HomebrewPersistenceService();
  final Set<EntityType> _selectedCategories = {};
  final Set<HomebrewOtherCategory> _selectedOtherCategories = {};

  Map<EntityType, int> _categoryCounts = {};
  Map<HomebrewOtherCategory, int> _otherCategoryCounts = {};
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final spells = await _persistence.loadCustomSpells();
    final monsters = await _persistence.loadCustomMonsters();
    final items = await _persistence.loadCustomItems();
    final classes = await _persistence.loadCustomClasses();
    final subclasses = await _persistence.loadCustomSubclasses();
    final races = await _persistence.loadCustomRaces();
    final feats = await _persistence.loadCustomFeats();
    final backgrounds = await _persistence.loadCustomBackgrounds();
    final otherCounts = await _persistence.loadOtherCategoryCounts();

    if (mounted) {
      setState(() {
        _categoryCounts = {
          EntityType.spell: spells.length,
          EntityType.monster: monsters.length,
          EntityType.equipment: items.length,
          EntityType.classDefinition: classes.length,
          EntityType.subclass: subclasses.length,
          EntityType.species: races.length,
          EntityType.feat: feats.length,
          EntityType.background: backgrounds.length,
        };
        _otherCategoryCounts = otherCounts;
        _isLoading = false;
      });
    }
  }

  int get _totalSelectedItems {
    int sum = 0;
    for (final cat in _selectedCategories) {
      sum += _categoryCounts[cat] ?? 0;
    }
    for (final sub in _selectedOtherCategories) {
      sum += _otherCategoryCounts[sub] ?? 0;
    }
    return sum;
  }

  int get _totalAllItems {
    final coreTotal = _categoryCounts.values.fold(0, (a, b) => a + b);
    final otherTotal = _otherCategoryCounts.values.fold(0, (a, b) => a + b);
    return coreTotal + otherTotal;
  }

  void _selectAll() {
    HapticService.selectionTick(context);
    setState(() {
      _selectedCategories.addAll(
          _categoryCounts.keys.where((k) => (_categoryCounts[k] ?? 0) > 0));
      _selectedOtherCategories.addAll(_otherCategoryCounts.keys
          .where((k) => (_otherCategoryCounts[k] ?? 0) > 0));
    });
  }

  void _deselectAll() {
    HapticService.selectionTick(context);
    setState(() {
      _selectedCategories.clear();
      _selectedOtherCategories.clear();
    });
  }

  Future<void> _confirmAndDeleteSelected() async {
    if ((_selectedCategories.isEmpty && _selectedOtherCategories.isEmpty) ||
        _totalSelectedItems == 0) return;

    final count = _totalSelectedItems;
    final catCount =
        _selectedCategories.length + _selectedOtherCategories.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete $count custom entities across $catCount selected categories? '
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
      setState(() => _isDeleting = true);
      try {
        for (final cat in _selectedCategories) {
          await _persistence.clearHomebrewCategory(cat);
        }
        if (_selectedOtherCategories.isNotEmpty) {
          await _persistence
              .clearOtherEntriesByCategories(_selectedOtherCategories);
        }
        if (mounted) {
          Navigator.of(context).pop(count);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmAndDeleteAll() async {
    if (_totalAllItems == 0) return;
    final count = _totalAllItems;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Purge ALL Homebrew?'),
          ],
        ),
        content: Text(
          'WARNING: This will permanently wipe ALL $count custom spells, monsters, items, classes, species, feats, backgrounds, deities, tables, vehicles, and rules from your toolkit. '
          'Saved character sheets and dice presets will remain untouched.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      try {
        await _persistence.clearAllHomebrew();
        if (mounted) {
          Navigator.of(context).pop(count);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear homebrew: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final otherTotal = _otherCategoryCounts.values.fold(0, (a, b) => a + b);

    return AppDialogFrame(
      icon: Icons.delete_sweep_outlined,
      iconColor: Colors.redAccent,
      title: 'Bulk Homebrew Deleter',
      maxWidth: 520,
      content: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select specific homebrew categories to delete in bulk or purge all custom content at once.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Total in Storage: $_totalAllItems items',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _selectAll,
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: _deselectAll,
                            child: const Text('Clear Selection'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      'Core Compendium & Character Content',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildCategoryTile(
                    type: EntityType.spell,
                    title: 'Spells & Cantrips',
                    icon: Icons.auto_awesome,
                    iconColor: Colors.purpleAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.monster,
                    title: 'Monsters & NPCs',
                    icon: Icons.pets,
                    iconColor: Colors.deepOrangeAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.equipment,
                    title: 'Items & Equipment',
                    icon: Icons.shield,
                    iconColor: Colors.amberAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.classDefinition,
                    title: 'Classes',
                    icon: Icons.military_tech,
                    iconColor: Colors.blueAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.subclass,
                    title: 'Subclasses',
                    icon: Icons.star,
                    iconColor: Colors.indigoAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.species,
                    title: 'Species & Races',
                    icon: Icons.person,
                    iconColor: Colors.tealAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.feat,
                    title: 'Feats & Boons',
                    icon: Icons.stars,
                    iconColor: Colors.orangeAccent,
                    theme: theme,
                  ),
                  _buildCategoryTile(
                    type: EntityType.background,
                    title: 'Backgrounds',
                    icon: Icons.menu_book,
                    iconColor: Colors.amberAccent,
                    theme: theme,
                  ),
                  if (otherTotal > 0) ...[
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Codex, Worldbuilding & Rules ($otherTotal)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            onPressed: () {
                              final allOtherSelected =
                                  _selectedOtherCategories.length ==
                                      _otherCategoryCounts.length;
                              setState(() {
                                if (allOtherSelected) {
                                  _selectedOtherCategories.clear();
                                } else {
                                  _selectedOtherCategories.addAll(
                                      _otherCategoryCounts.keys.where((k) =>
                                          (_otherCategoryCounts[k] ?? 0) > 0));
                                }
                              });
                            },
                            child: Text(
                              _selectedOtherCategories.length ==
                                      _otherCategoryCounts.length
                                  ? 'Deselect All Codex'
                                  : 'Select All Codex',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.tables,
                      title: 'Rollable Tables',
                      icon: Icons.table_chart,
                      iconColor: Colors.cyanAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.deities,
                      title: 'Deities & Pantheons',
                      icon: Icons.wb_sunny,
                      iconColor: Colors.amberAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.vehicles,
                      title: 'Vehicles & Vessels',
                      icon: Icons.directions_boat,
                      iconColor: Colors.tealAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.trapsAndHazards,
                      title: 'Traps & Hazards',
                      icon: Icons.warning_amber,
                      iconColor: Colors.redAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.invocationsAndPacts,
                      title: 'Invocations & Pact Boons',
                      icon: Icons.auto_awesome,
                      iconColor: Colors.purpleAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.infusions,
                      title: 'Infusions',
                      icon: Icons.build_circle,
                      iconColor: Colors.indigoAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.charmsAndRewards,
                      title: 'Charms & Rewards',
                      icon: Icons.card_giftcard,
                      iconColor: Colors.greenAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.conditionsAndDiseases,
                      title: 'Conditions & Diseases',
                      icon: Icons.coronavirus,
                      iconColor: Colors.pinkAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.characterOptions,
                      title: 'Character Options',
                      icon: Icons.psychology,
                      iconColor: Colors.lightBlueAccent,
                      theme: theme,
                    ),
                    _buildOtherSubcategoryTile(
                      subcat: HomebrewOtherCategory.rulesAndReference,
                      title: 'Rules & Reference',
                      icon: Icons.menu_book,
                      iconColor: Colors.blueGrey,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_totalAllItems > 0)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
            ),
            onPressed: _isDeleting ? null : _confirmAndDeleteAll,
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Purge All'),
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: ((_selectedCategories.isEmpty &&
                      _selectedOtherCategories.isEmpty) ||
                  _totalSelectedItems == 0 ||
                  _isDeleting)
              ? null
              : _confirmAndDeleteSelected,
          icon: const Icon(Icons.delete, size: 18),
          label: Text(
            _totalSelectedItems == 0
                ? 'Delete Selected'
                : 'Delete Selected ($_totalSelectedItems)',
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTile({
    required EntityType type,
    required String title,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
  }) {
    final count = _categoryCounts[type] ?? 0;
    final isSelected = _selectedCategories.contains(type);
    final hasItems = count > 0;

    return CheckboxListTile(
      value: isSelected,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      enabled: hasItems,
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: iconColor.withValues(alpha: 0.2),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: hasItems
              ? null
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      subtitle: Text(
        '$count ${count == 1 ? "item" : "items"} in storage',
        style: TextStyle(
          fontSize: 11,
          color: hasItems ? theme.colorScheme.onSurfaceVariant : Colors.grey,
        ),
      ),
      onChanged: hasItems
          ? (val) {
              setState(() {
                if (val == true) {
                  _selectedCategories.add(type);
                } else {
                  _selectedCategories.remove(type);
                }
              });
            }
          : null,
    );
  }

  Widget _buildOtherSubcategoryTile({
    required HomebrewOtherCategory subcat,
    required String title,
    required IconData icon,
    required Color iconColor,
    required ThemeData theme,
  }) {
    final count = _otherCategoryCounts[subcat] ?? 0;
    final isSelected = _selectedOtherCategories.contains(subcat);
    final hasItems = count > 0;

    return CheckboxListTile(
      value: isSelected,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      enabled: hasItems,
      secondary: CircleAvatar(
        radius: 16,
        backgroundColor: iconColor.withValues(alpha: 0.2),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: hasItems
              ? null
              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      subtitle: Text(
        '$count ${count == 1 ? "item" : "items"} in storage',
        style: TextStyle(
          fontSize: 11,
          color: hasItems ? theme.colorScheme.onSurfaceVariant : Colors.grey,
        ),
      ),
      onChanged: hasItems
          ? (val) {
              setState(() {
                if (val == true) {
                  _selectedOtherCategories.add(subcat);
                } else {
                  _selectedOtherCategories.remove(subcat);
                }
              });
            }
          : null,
    );
  }
}
