import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../../services/haptic_service.dart';

class ActionEconomyDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ActionEconomyDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ActionEconomyDialog(initialEdition: edition),
    );
  }

  @override
  State<ActionEconomyDialog> createState() => _ActionEconomyDialogState();
}

class _ActionEconomyDialogState extends State<ActionEconomyDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;
    final is2024 = edition == DmRulesEdition.v2024;

    final standardActions = is2024 ? ActionEconomyLibrary.standardActions2024 : ActionEconomyLibrary.standardActions2014;
    final bonusActions = is2024 ? ActionEconomyLibrary.bonusActions2024 : ActionEconomyLibrary.bonusActions2014;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: const Color(0xFF1E1B2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        '5e Combat Action Economy',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Edition Toggle Button
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252236),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEditionChip(
                          label: '2014',
                          isActive: !is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            setState(() => _localEditionOverride = DmRulesEdition.v2014);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2014);
                          },
                        ),
                        _buildEditionChip(
                          label: '2024',
                          isActive: is2024,
                          onTap: () {
                            HapticService.selectionTick(context);
                            setState(() => _localEditionOverride = DmRulesEdition.v2024);
                            settingsProvider?.setRulesEdition(DmRulesEdition.v2024);
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    tooltip: 'Close dialog',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search actions (e.g., Dodge, Cover, Grapple, Potion)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.amber, size: 18),
                  filled: true,
                  fillColor: const Color(0xFF252236),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white54,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: '1 Action (Standard)'),
                Tab(text: 'Bonus Action'),
                Tab(text: 'Reaction'),
                Tab(text: 'Cover Rules'),
              ],
            ),
            const Divider(height: 1, color: Colors.white12),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(standardActions),
                  _buildList(bonusActions),
                  _buildList(ActionEconomyLibrary.reactions),
                  _buildList(ActionEconomyLibrary.coverRules),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditionChip({required String label, required bool isActive, required VoidCallback onTap}) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '$label Edition Rules',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? Colors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<CombatActionItem> items) {
    final filtered = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      return i.title.toLowerCase().contains(_searchQuery) ||
          i.desc.toLowerCase().contains(_searchQuery) ||
          i.cost.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No matching combat actions found.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return Card(
          color: const Color(0xFF252236),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: item.color.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.cost,
                              style: TextStyle(color: item.color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.desc,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
