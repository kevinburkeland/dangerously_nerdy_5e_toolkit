import 'package:flutter/material.dart';
import '../../models/domain/core_types.dart';
import '../../models/domain/spell_monster_equipment.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog for building or editing a custom Homebrew Spell.
class SpellBuilderDialog extends StatefulWidget {
  final Spell? initialSpell;

  const SpellBuilderDialog({super.key, this.initialSpell});

  @override
  State<SpellBuilderDialog> createState() => _SpellBuilderDialogState();
}

class _SpellBuilderDialogState extends State<SpellBuilderDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _rangeController;
  late TextEditingController _diceFormulaController;
  late TextEditingController _materialDescController;
  late TextEditingController _descController;
  late TextEditingController _higherLevelsController;

  int _level = 1;
  String _school = 'Evocation';
  ActionType _actionType = ActionType.action;
  DurationType _durationType = DurationType.instantaneous;
  bool _concentration = false;
  bool _verbal = true;
  bool _somatic = true;
  bool _material = false;
  DamageType _damageType = DamageType.fire;

  final List<String> _schools = const [
    'Abjuration',
    'Conjuration',
    'Divination',
    'Enchantment',
    'Evocation',
    'Illusion',
    'Necromancy',
    'Transmutation',
    'Universal',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialSpell;
    _nameController = TextEditingController(text: init?.name ?? '');
    _rangeController = TextEditingController(text: init?.range ?? '60 feet');
    _diceFormulaController = TextEditingController(
      text: init != null && init.damageMath.isNotEmpty
          ? init.damageMath.first.diceFormula
          : '',
    );
    _materialDescController = TextEditingController(
      text: init?.components.materialDescription ?? '',
    );
    _descController = TextEditingController(
      text: init?.descriptionMarkdown ?? '',
    );
    _higherLevelsController = TextEditingController(
      text: init?.higherLevelsMarkdown ?? '',
    );

    if (init != null) {
      _level = init.level;
      _school = init.school;
      _actionType = init.castingTime.actionType;
      _durationType = init.duration.type;
      _concentration = init.duration.requiresConcentration;
      _verbal = init.components.v;
      _somatic = init.components.s;
      _material = init.components.m;
      if (init.damageMath.isNotEmpty) {
        _damageType = init.damageMath.first.damageType;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rangeController.dispose();
    _diceFormulaController.dispose();
    _materialDescController.dispose();
    _descController.dispose();
    _higherLevelsController.dispose();
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

    final damageList = <EvaluationMath>[];
    if (_diceFormulaController.text.trim().isNotEmpty) {
      damageList.add(EvaluationMath(
        diceFormula: _diceFormulaController.text.trim(),
        damageType: _damageType,
      ));
    }

    final spell = Spell(
      id: EntityId(slug: slug, ruleset: RulesetVersion.homebrew),
      name: name,
      level: _level,
      school: _school,
      castingTime: CastingTime(
        cost: 1,
        actionType: _actionType,
      ),
      duration: SpellDuration(
        type: _durationType,
        requiresConcentration: _concentration,
      ),
      range: _rangeController.text.trim().isEmpty ? 'Self' : _rangeController.text.trim(),
      components: SpellComponents(
        v: _verbal,
        s: _somatic,
        m: _material,
        materialDescription: _material ? _materialDescController.text.trim() : null,
      ),
      descriptionMarkdown: _descController.text.trim(),
      higherLevelsMarkdown: _higherLevelsController.text.trim().isNotEmpty
          ? _higherLevelsController.text.trim()
          : null,
      damageMath: damageList,
    );

    Navigator.of(context).pop(spell);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogFrame(
      icon: Icons.auto_awesome,
      iconColor: Colors.purpleAccent,
      title: widget.initialSpell == null ? 'Create Custom Spell' : 'Edit Spell',
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
                  labelText: 'Spell Name',
                  hintText: 'e.g. Abyssal Rift',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _level,
                      decoration: const InputDecoration(labelText: 'Level'),
                      items: List.generate(
                        10,
                        (idx) => DropdownMenuItem(
                          value: idx,
                          child: Text(idx == 0 ? 'Cantrip' : 'Level $idx'),
                        ),
                      ),
                      onChanged: (val) => setState(() => _level = val ?? 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _school,
                      decoration: const InputDecoration(labelText: 'School'),
                      items: _schools
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => _school = val ?? 'Evocation'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ActionType>(
                      initialValue: _actionType,
                      decoration: const InputDecoration(labelText: 'Casting Time'),
                      items: const [
                        DropdownMenuItem(
                            value: ActionType.action, child: Text('1 Action')),
                        DropdownMenuItem(
                            value: ActionType.bonusAction,
                            child: Text('1 Bonus Action')),
                        DropdownMenuItem(
                            value: ActionType.reaction, child: Text('1 Reaction')),
                        DropdownMenuItem(
                            value: ActionType.minute, child: Text('1 Minute')),
                      ],
                      onChanged: (val) =>
                          setState(() => _actionType = val ?? ActionType.action),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rangeController,
                      decoration: const InputDecoration(
                        labelText: 'Range',
                        hintText: 'e.g. 60 feet, Self, Touch',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<DurationType>(
                      initialValue: _durationType,
                      decoration: const InputDecoration(labelText: 'Duration'),
                      items: const [
                        DropdownMenuItem(
                            value: DurationType.instantaneous,
                            child: Text('Instantaneous')),
                        DropdownMenuItem(
                            value: DurationType.timed, child: Text('Timed')),
                        DropdownMenuItem(
                            value: DurationType.permanent,
                            child: Text('Permanent')),
                      ],
                      onChanged: (val) => setState(
                          () => _durationType = val ?? DurationType.instantaneous),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Concentration'),
                    selected: _concentration,
                    onSelected: (val) => setState(() => _concentration = val),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Components:', style: theme.textTheme.labelLarge),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('V (Verbal)'),
                    selected: _verbal,
                    onSelected: (val) => setState(() => _verbal = val),
                  ),
                  FilterChip(
                    label: const Text('S (Somatic)'),
                    selected: _somatic,
                    onSelected: (val) => setState(() => _somatic = val),
                  ),
                  FilterChip(
                    label: const Text('M (Material)'),
                    selected: _material,
                    onSelected: (val) => setState(() => _material = val),
                  ),
                ],
              ),
              if (_material) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _materialDescController,
                  decoration: const InputDecoration(
                    labelText: 'Material Description',
                    hintText: 'e.g. a pinch of sulfur',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _diceFormulaController,
                      decoration: const InputDecoration(
                        labelText: 'Damage / Heal Formula',
                        hintText: 'e.g. 8d6 or 2d8 + mod',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<DamageType>(
                      initialValue: _damageType,
                      decoration: const InputDecoration(labelText: 'Damage Type'),
                      items: DamageType.values
                          .map((d) => DropdownMenuItem(
                              value: d, child: Text(d.name.toUpperCase())))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _damageType = val ?? DamageType.fire),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Spell Description (Markdown supported)',
                  alignLabelWithHint: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Please enter a description'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _higherLevelsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'At Higher Levels Scaling (Optional)',
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
          label: const Text('Save Spell'),
        ),
      ],
    );
  }
}
