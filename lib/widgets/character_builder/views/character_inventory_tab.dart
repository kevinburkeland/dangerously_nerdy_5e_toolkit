import 'package:material_ui/material_ui.dart';
import '../../../models/domain/character_models.dart';
import '../../../models/domain/core_types.dart';
import '../../../models/magic_items/magic_item_library.dart';
import '../../../services/rules/inventory_transaction_service.dart';

class CharacterInventoryTab extends StatelessWidget {
  final Character? character;
  final VoidCallback onGoToRoster;
  final ValueChanged<Character> onCharacterUpdated;

  const CharacterInventoryTab({
    super.key,
    required this.character,
    required this.onGoToRoster,
    required this.onCharacterUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final char = character;
    if (char == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text('No Active Character',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                  'Select or create a character to manage inventory and equipment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.groups_outlined, size: 18),
                label: const Text('Go to Character Roster'),
                onPressed: () {
                  onGoToRoster();
                },
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Attunement Counter Card
        Card(
          color: const Color(0xFF1E293B),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Attunement: ${char.attunedItemCount} / ${char.maxAttunementSlots} Slots',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                Text('Gold: ${char.purse.gp} GP',
                    style: const TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CHARACTER INVENTORY',
                style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Add SRD Item'),
              onPressed: () => _showAddSrdItemDialog(context, char),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ...char.inventory.map((item) {
          return Card(
            color: const Color(0xFF1E293B),
            child: ListTile(
              title: Text(item.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Qty: ${item.quantity} • ${item.isEquipped ? "Equipped in ${_formatEquippedSlot(item.equippedSlot)}" : "In Backpack"}${item.requiresAttunement ? (item.isAttuned ? " • [Attuned]" : " • [Unattuned]") : ""}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresAttunement)
                    IconButton(
                      icon: Icon(
                          item.isAttuned ? Icons.star : Icons.star_border,
                          color: item.isAttuned
                              ? Colors.purpleAccent
                              : Colors.white60),
                      tooltip: item.isAttuned ? 'Unattune' : 'Attune',
                      onPressed: () {
                        try {
                          final updated =
                              InventoryTransactionService.attuneItem(
                                  char, item.instanceId, !item.isAttuned);
                          onCharacterUpdated(updated);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(
                        item.isEquipped
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: item.isEquipped
                            ? Colors.cyanAccent
                            : Colors.white60),
                    tooltip: item.isEquipped ? 'Unequip' : 'Equip',
                    onPressed: () {
                      final targetSlot =
                          InventoryTransactionService.resolveDefaultSlot(item);
                      final updated = item.isEquipped
                          ? InventoryTransactionService.unequipItem(
                              char, item.instanceId)
                          : InventoryTransactionService.equipItem(
                              char, item.instanceId, targetSlot);
                      onCharacterUpdated(updated);
                    },
                  ),
                ],
              ),
            ),
          );
        }),

        if (char.inventory.isEmpty)
          const Card(
            color: Color(0xFF1E293B),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Inventory is empty. Tap "Add SRD Item" above to add gear and equipment.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
      ],
    );
  }


  void _showAddSrdItemDialog(BuildContext context, Character char) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allItems = MagicItemLibrary.allItems;
            final filtered = searchQuery.trim().isEmpty
                ? allItems.take(50).toList()
                : allItems
                    .where((item) =>
                        item.name
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase()) ||
                        item.category.name
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase()) ||
                        item.tags.any((t) => t
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase())))
                    .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2, color: Colors.cyanAccent),
                              SizedBox(width: 8),
                              Text('Equipment & Magic Items',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Search SRD & homebrew weapons, armor, potions, gear...',
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.cyanAccent),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            return Card(
                              color: const Color(0xFF1E293B),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                                subtitle: Text(
                                  '${item.category.name.toUpperCase()} • ${item.rarityTier.name}${item.cost != null ? " • ${item.cost}" : ""}\n${item.rules2024.summary.isNotEmpty ? item.rules2024.summary : item.rules2014.summary}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Colors.white70),
                                ),
                                trailing: ElevatedButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.cyan.shade800,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    final resolvedSlot =
                                        InventoryTransactionService
                                            .resolveDefaultSlot(
                                      InventoryItemInstance(
                                        instanceId: 'temp',
                                        itemRef: EntityReference(
                                          refType: EntityType.equipment,
                                          slug: item.id.slug,
                                          displayName: item.name,
                                        ),
                                        customProperties: {
                                          'category': item.category.name,
                                          'tags': item.tags,
                                        },
                                      ),
                                    );
                                    final newInstance = InventoryItemInstance(
                                      instanceId:
                                          'srd-${item.id.slug}-${DateTime.now().millisecondsSinceEpoch}',
                                      itemRef: EntityReference(
                                        refType: EntityType.equipment,
                                        slug: item.id.slug,
                                        displayName: item.name,
                                      ),
                                      quantity: 1,
                                      equippedSlot: resolvedSlot,
                                      requiresAttunement:
                                          item.requiresAttunement,
                                      customProperties: {
                                        'category': item.category.name,
                                        'tags': item.tags,
                                      },
                                    );
                                    final updatedInventory =
                                        List<InventoryItemInstance>.from(
                                            char.inventory)
                                          ..add(newInstance);
                                    final updatedChar = char.copyWith(
                                        inventory: updatedInventory);
                                    onCharacterUpdated(updatedChar);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Added ${item.name} to inventory!')),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatEquippedSlot(dynamic slot) {
    if (slot == null) return 'Gear Slot';
    if (slot is EquipmentSlot) return slot.displayName;
    final str = slot.toString().trim();
    for (final s in EquipmentSlot.values) {
      if (s.name.toLowerCase() == str.toLowerCase() ||
          s.displayName.toLowerCase() == str.toLowerCase()) {
        return s.displayName;
      }
    }
    return str.isNotEmpty ? str : 'Gear Slot';
  }

}
