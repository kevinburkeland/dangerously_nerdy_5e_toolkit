import 'package:flutter/material.dart';
import '../../models/dpr/dpr_models.dart';

/// Modal bottom sheet for selecting standard weapons, cantrips, and magic items for DPR profiles.
class DprWeaponPickerSheet extends StatefulWidget {
  final ValueChanged<DprWeaponPreset> onSelected;

  const DprWeaponPickerSheet({
    super.key,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<DprWeaponPreset> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DprWeaponPickerSheet(
        onSelected: (preset) {
          Navigator.of(ctx).pop();
          onSelected(preset);
        },
      ),
    );
  }

  @override
  State<DprWeaponPickerSheet> createState() => _DprWeaponPickerSheetState();
}

class _DprWeaponPickerSheetState extends State<DprWeaponPickerSheet> {
  String _search = '';
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = ['All', 'Standard Melee', 'Standard Ranged', 'Damage Cantrip', 'Magic Weapon'];

    final filtered = DprWeaponPreset.allPresets.where((p) {
      if (_selectedCategory != 'All' && p.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty && !p.name.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high, color: Colors.cyanAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Select Weapon, Cantrip, or Magic Item',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search Greatsword, Fire Bolt, Rapier, Eldritch Blast...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => setState(() => _search = val),
              ),
            ),
            const SizedBox(height: 10),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),

            // Weapon Preset List
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final item = filtered[index];
                  final isMagic = item.category == 'Magic Weapon';
                  final isCantrip = item.isCantrip || item.category == 'Damage Cantrip';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isMagic
                          ? Colors.purpleAccent.withValues(alpha: 0.2)
                          : isCantrip
                              ? Colors.amberAccent.withValues(alpha: 0.2)
                              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      child: Icon(
                        isMagic
                            ? Icons.auto_awesome
                            : isCantrip
                                ? Icons.local_fire_department
                                : (item.isRanged ? Icons.gps_fixed : Icons.colorize),
                        color: isMagic
                            ? Colors.purpleAccent
                            : isCantrip
                                ? Colors.amberAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isMagic
                            ? Colors.purpleAccent
                            : isCantrip
                                ? Colors.amberAccent
                                : null,
                      ),
                    ),
                    subtitle: Text(
                      '${item.diceCount}d${item.diceSides} ${item.damageType}'
                      '${item.flatBonus > 0 ? ' (+${item.flatBonus} magic)' : ''}'
                      '${item.secondaryDiceCount > 0 ? ' + ${item.secondaryDiceCount}d${item.secondaryDiceSides} ${item.secondaryDamageType ?? ""}' : ''}'
                      '${item.defaultMastery != WeaponMastery.none ? ' • Mastery: ${item.defaultMastery.label.split(" ").first}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => widget.onSelected(item),
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
