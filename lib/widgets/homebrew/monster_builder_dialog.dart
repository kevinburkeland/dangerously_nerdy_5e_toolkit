import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog for building or editing a custom Homebrew Monster / Creature.
class MonsterBuilderDialog extends StatefulWidget {
  final Monster? initialMonster;

  const MonsterBuilderDialog({super.key, this.initialMonster});

  @override
  State<MonsterBuilderDialog> createState() => _MonsterBuilderDialogState();
}

class _MonsterBuilderDialogState extends State<MonsterBuilderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _sizeController;
  late TextEditingController _typeController;
  late TextEditingController _alignmentController;
  late TextEditingController _acController;
  late TextEditingController _hpController;
  late TextEditingController _hitDiceController;
  late TextEditingController _crController;
  late TextEditingController _actionsController;

  @override
  void initState() {
    super.initState();
    final init = widget.initialMonster;
    _nameController = TextEditingController(text: init?.name ?? '');
    _sizeController = TextEditingController(text: init?.size ?? 'Medium');
    _typeController = TextEditingController(text: init?.monsterType ?? 'Humanoid');
    _alignmentController = TextEditingController(text: init?.alignment ?? 'Neutral');
    _acController = TextEditingController(text: (init?.armorClass ?? 13).toString());
    _hpController = TextEditingController(text: (init?.hitPoints ?? 22).toString());
    _hitDiceController = TextEditingController(text: init?.hitDieFormula ?? '4d8 + 4');
    _crController = TextEditingController(text: init?.challengeRating ?? '1');
    _actionsController = TextEditingController(text: init?.actionsMarkdown ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    _typeController.dispose();
    _alignmentController.dispose();
    _acController.dispose();
    _hpController.dispose();
    _hitDiceController.dispose();
    _crController.dispose();
    _actionsController.dispose();
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
    final ac = int.tryParse(_acController.text.trim()) ?? 10;
    final hp = int.tryParse(_hpController.text.trim()) ?? 10;

    final monster = Monster(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      size: _sizeController.text.trim().isEmpty ? 'Medium' : _sizeController.text.trim(),
      monsterType: _typeController.text.trim().isEmpty ? 'Humanoid' : _typeController.text.trim(),
      alignment: _alignmentController.text.trim().isEmpty ? 'unaligned' : _alignmentController.text.trim(),
      armorClass: ac,
      hitPoints: hp,
      hitDieFormula: _hitDiceController.text.trim(),
      challengeRating: _crController.text.trim().isEmpty ? '1' : _crController.text.trim(),
      actionsMarkdown: _actionsController.text.trim(),
    );

    Navigator.of(context).pop(monster);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogFrame(
      icon: Icons.pets,
      iconColor: Colors.deepOrangeAccent,
      title: widget.initialMonster == null ? 'Create Custom Monster' : 'Edit Monster',
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
                  labelText: 'Monster Name',
                  hintText: 'e.g. Shadow Stalker',
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
                      controller: _sizeController,
                      decoration: const InputDecoration(
                        labelText: 'Size',
                        hintText: 'Small, Medium, Large',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _typeController,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        hintText: 'Beast, Fiend, Undead',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _alignmentController,
                      decoration: const InputDecoration(
                        labelText: 'Alignment',
                        hintText: 'Neutral Evil, Unaligned',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _crController,
                      decoration: const InputDecoration(
                        labelText: 'Challenge Rating (CR)',
                        hintText: '1/4, 1/2, 1, 5',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _acController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Armor Class (AC)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _hpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hit Points (HP)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _hitDiceController,
                      decoration: const InputDecoration(
                        labelText: 'Hit Dice Formula',
                        hintText: '4d8 + 8',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actionsController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Actions & Traits (Markdown)',
                  hintText: '**Multiattack**: Makes two attacks.\n\n**Bite**: Melee Weapon Attack: +5 to hit, reach 5 ft., 1d8+3 piercing.',
                  alignLabelWithHint: true,
                ),
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
          label: const Text('Save Monster'),
        ),
      ],
    );
  }
}
