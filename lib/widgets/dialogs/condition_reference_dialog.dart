import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../dm_reference/rules_edition_toggle.dart';

class ConditionReferenceDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ConditionReferenceDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ConditionReferenceDialog(initialEdition: edition),
    );
  }

  @override
  State<ConditionReferenceDialog> createState() => _ConditionReferenceDialogState();
}

class _ConditionReferenceDialogState extends State<ConditionReferenceDialog> {
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;

    final filtered = DmScreenLibrary.conditions.where((c) {
      if (_selectedCategory != 'All' && c.subCategory != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return c.matches(_searchQuery);
    }).toList();

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
                  const Icon(Icons.medical_information_outlined, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        '5e Status Effects & Conditions',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: RulesEditionToggle(
                      currentEdition: edition,
                      isDense: true,
                      onEditionChanged: (newEdition) {
                        setState(() => _localEditionOverride = newEdition);
                        settingsProvider?.setRulesEdition(newEdition);
                      },
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
                  hintText: 'Search conditions (e.g. Advantage, Saving throw, Crit, Speed 0)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent, size: 18),
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

            // Category Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DmScreenLibrary.conditionCategories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70)),
                        selected: isSelected,
                        selectedColor: Colors.cyanAccent,
                        backgroundColor: const Color(0xFF252236),
                        checkmarkColor: Colors.black,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white12),

            // List of Conditions
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching conditions found.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final bulletPoints = item.getRules(edition);
                        return Card(
                          color: const Color(0xFF252236),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: item.color.withValues(alpha: 0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: item.color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(item.icon, color: item.color, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: item.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (item.subCategory != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.subCategory!,
                                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...bulletPoints.map(
                                  (pt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(color: item.color, fontWeight: FontWeight.bold),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pt,
                                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
      ),
    );
  }
}
