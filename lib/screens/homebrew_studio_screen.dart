import 'package:flutter/material.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../services/ingestion/compendium_json_ingestion_pipeline.dart';
import '../services/persistence/homebrew_persistence_service.dart';
import '../widgets/homebrew/equipment_builder_dialog.dart';
import '../widgets/homebrew/homebrew_import_dialog.dart';
import '../widgets/homebrew/monster_builder_dialog.dart';
import '../widgets/homebrew/spell_builder_dialog.dart';

/// Comprehensive Homebrew Studio screen allowing users to create, edit, import, and manage
/// custom spells, monsters, and magic items/equipment.
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    if (mounted) {
      setState(() {
        _spells = spells;
        _monsters = monsters;
        _items = items;
        _isLoading = false;
      });
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

  Future<void> _openImportDialog() async {
    final result = await showDialog<IngestionBatchResult>(
      context: context,
      builder: (ctx) => const HomebrewImportDialog(),
    );
    if (result != null && result.totalEntities > 0) {
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${result.totalEntities} custom entities!',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Homebrew Studio'),
        actions: [
          IconButton(
            tooltip: 'Import Compendium JSON',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _openImportDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.auto_awesome), text: 'Spells (${_spells.length})'),
            Tab(icon: const Icon(Icons.pets), text: 'Monsters (${_monsters.length})'),
            Tab(icon: const Icon(Icons.shield), text: 'Items (${_items.length})'),
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
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          switch (_tabController.index) {
            case 0:
              _createOrEditSpell();
              break;
            case 1:
              _createOrEditMonster();
              break;
            case 2:
              _createOrEditItem();
              break;
          }
        },
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0
              ? 'New Spell'
              : (_tabController.index == 1 ? 'New Monster' : 'New Item'),
        ),
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _spells.length,
      itemBuilder: (ctx, idx) {
        final spell = _spells[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
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
            trailing: Row(
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _monsters.length,
      itemBuilder: (ctx, idx) {
        final monster = _monsters[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
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
            trailing: Row(
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (ctx, idx) {
        final item = _items[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withValues(alpha: 0.2),
              child: const Icon(Icons.shield, color: Colors.amberAccent),
            ),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item.rarity} ${item.itemType}'),
            trailing: Row(
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
