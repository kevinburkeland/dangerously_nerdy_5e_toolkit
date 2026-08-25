import 'package:flutter/material.dart';
import '../models/tables/rollable_table.dart';
import '../models/tables/srd_tables_library.dart';
import '../services/haptic_service.dart';
import '../widgets/room_banner_widget.dart';
import '../widgets/tables/quick_roller_card.dart';
import '../widgets/tables/rollable_table_card.dart';
import '../widgets/tables/treasure_hoard_view.dart';

/// Main screen for the Table Index: 5e SRD Rollable Tables, Treasure Hoards & Chaos Generators.
class TableIndexScreen extends StatefulWidget {
  final int initialTabIndex;

  const TableIndexScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<TableIndexScreen> createState() => _TableIndexScreenState();
}

class _TableIndexScreenState extends State<TableIndexScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TableCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withAlpha(100)),
              ),
              child: const Icon(Icons.table_chart, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Table Index',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFF59E0B),
            labelColor: const Color(0xFFF59E0B),
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            tabs: const [
              Tab(
                icon: Icon(Icons.monetization_on_outlined, size: 18),
                text: 'Treasure Generator',
              ),
              Tab(
                icon: Icon(Icons.table_view_outlined, size: 18),
                text: 'All Tables Index',
              ),
              Tab(
                icon: Icon(Icons.auto_awesome, size: 18),
                text: 'Quick Rollers',
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          RoomBannerWidget(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Treasure Hoard & Loot Generator
                const TreasureHoardView(),

                // Tab 2: All Rollable Tables Directory
                _buildAllTablesDirectory(context, isDark),

                // Tab 3: Quick Rollers (Wild Magic, Trinkets, Madness)
                const QuickRollerCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllTablesDirectory(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final tables = SrdTablesLibrary.search(
      _searchQuery,
      category: _selectedCategory,
    );

    return Column(
      children: [
        // Search & Category Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search all SRD tables, loot items, magic surges...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('All Tables'),
                  selected: _selectedCategory == null,
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = null);
                  },
                ),
              ),
              ...TableCategory.values.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    avatar: Icon(cat.icon, size: 14, color: isSel ? Colors.black : cat.accentColor),
                    label: Text(cat.label),
                    selected: isSel,
                    selectedColor: cat.accentColor.withAlpha(50),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? cat.accentColor : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (val) {
                      HapticService.selectionTick(context);
                      setState(() => _selectedCategory = val ? cat : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const Divider(height: 12),

        // Table List
        Expanded(
          child: tables.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.withAlpha(100)),
                        const SizedBox(height: 12),
                        Text(
                          'No tables match "$_searchQuery"',
                          style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedCategory = null;
                            });
                          },
                          child: const Text('Reset Search & Filters'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: tables.length,
                  itemBuilder: (context, idx) {
                    final table = tables[idx];
                    return RollableTableCard(
                      key: ValueKey(table.id),
                      table: table,
                      searchQuery: _searchQuery,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
