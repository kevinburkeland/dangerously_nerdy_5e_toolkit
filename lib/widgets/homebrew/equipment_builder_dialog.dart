import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog for building or editing a custom Homebrew Equipment / Magic Item.
class EquipmentBuilderDialog extends StatefulWidget {
  final EquipmentItem? initialItem;

  const EquipmentBuilderDialog({super.key, this.initialItem});

  @override
  State<EquipmentBuilderDialog> createState() => _EquipmentBuilderDialogState();
}

class _EquipmentBuilderDialogState extends State<EquipmentBuilderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _itemTypeController;
  late TextEditingController _descController;

  String _rarity = 'Rare';
  bool _requiresAttunement = false;

  final List<String> _rarities = const [
    'Common',
    'Uncommon',
    'Rare',
    'Very Rare',
    'Legendary',
    'Artifact',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialItem;
    _nameController = TextEditingController(text: init?.name ?? '');
    _itemTypeController = TextEditingController(text: init?.itemType ?? 'Wondrous Item');
    _descController = TextEditingController(text: init?.descriptionMarkdown ?? '');

    if (init != null) {
      _rarity = init.rarity;
      _requiresAttunement = init.requiresAttunement;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemTypeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final slug = _slugify(name);

    final item = EquipmentItem(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      itemType: _itemTypeController.text.trim().isEmpty
          ? 'Wondrous Item'
          : _itemTypeController.text.trim(),
      rarity: _rarity,
      requiresAttunement: _requiresAttunement,
      descriptionMarkdown: _descController.text.trim(),
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      icon: Icons.shield,
      iconColor: Colors.amberAccent,
      title: widget.initialItem == null ? 'Create Custom Item' : 'Edit Item',
      maxWidth: 540,
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Ring of Spell Storing',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _itemTypeController,
                      decoration: const InputDecoration(
                        labelText: 'Category / Type',
                        hintText: 'Weapon, Armor, Wondrous Item, Ring',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _rarities.contains(_rarity) ? _rarity : 'Rare',
                      decoration: const InputDecoration(labelText: 'Rarity'),
                      items: _rarities
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) => setState(() => _rarity = val ?? 'Rare'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilterChip(
                label: const Text('Requires Attunement'),
                selected: _requiresAttunement,
                onSelected: (val) => setState(() => _requiresAttunement = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Item Description & Properties (Markdown)',
                  hintText: 'Describe magic properties, bonus damage, and activated charges...',
                  alignLabelWithHint: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a description'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.check),
          label: const Text('Save Item'),
        ),
      ],
    );
  }
}
