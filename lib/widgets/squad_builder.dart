import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../models/srd_summons.dart';
import '../services/a11y_service.dart';

class SquadBuilderBottomSheet extends StatefulWidget {
  final SpellSession session;
  final VoidCallback onSquadUpdated;

  const SquadBuilderBottomSheet({
    super.key,
    required this.session,
    required this.onSquadUpdated,
  });

  @override
  State<SquadBuilderBottomSheet> createState() => _SquadBuilderBottomSheetState();
}

class _SquadBuilderBottomSheetState extends State<SquadBuilderBottomSheet> {
  late SummonPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.session.activePreset;
  }

  void _addPresetObjects(ObjectSize size, int count, {String? customName}) {
    int added = 0;
    for (int i = 0; i < count; i++) {
      if (widget.session.canAddObject(size)) {
        widget.session.addObject(size, customName: customName);
        added++;
      } else {
        final msg = 'Not enough remaining point capacity for more ${size.displayName} objects!';
        A11yService.announce(msg);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
        break;
      }
    }
    if (added > 0) {
      A11yService.announce('Added $added ${customName ?? size.displayName} to squad.');
    }
    setState(() {});
    widget.onSquadUpdated();
  }

  void _addMinions(MinionStatBlock statBlock, int count) {
    int added = 0;
    for (int i = 0; i < count; i++) {
      if (widget.session.canAddMinion(statBlock)) {
        widget.session.addMinionFromStatBlock(statBlock);
        added++;
      } else {
        final maxAllowed = widget.session.getMaxAllowedCount(statBlock.id);
        final msg = maxAllowed <= 0
            ? '${statBlock.name} is not available at spell slot level ${widget.session.spellLevel}!'
            : 'Reached limit ($maxAllowed) for ${statBlock.name} at slot level ${widget.session.spellLevel}!';
        A11yService.announce(msg);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
        break;
      }
    }
    if (added > 0) {
      A11yService.announce('Added $added ${statBlock.name} to squad.');
    }
    setState(() {});
    widget.onSquadUpdated();
  }

  void _rollBagOfTricks() {
    final pulled = widget.session.rollBagOfTricks();
    final msg = 'Pulled a ${pulled.name} from the Bag of Tricks!';
    A11yService.announce(msg);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎲 $msg'),
        backgroundColor: Colors.purpleAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
    setState(() {});
    widget.onSquadUpdated();
  }

  void _rollHornOfValhalla(String variant, String label) {
    final count = widget.session.rollHornOfValhalla(variant);
    final msg = 'Blew the $label and summoned $count Berserkers!';
    A11yService.announce(msg);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📯 $msg'),
        backgroundColor: Colors.deepOrange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
    setState(() {});
    widget.onSquadUpdated();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1B2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header & Preset Picker
            const Text(
              '🔮 SELECT SPELL OR ITEM',
              style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2840),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SummonPreset>(
                  value: _selectedPreset,
                  dropdownColor: const Color(0xFF2C2840),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                  items: [
                    ...SrdSummonsLibrary.spellPresets.map((preset) {
                      return DropdownMenuItem<SummonPreset>(
                        value: preset,
                        child: Text(
                          '🔮 ${preset.name} (${preset.levelDisplay})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      );
                    }),
                    ...SrdSummonsLibrary.magicItemPresets.map((preset) {
                      return DropdownMenuItem<SummonPreset>(
                        value: preset,
                        child: Text(
                          '📯 ${preset.name} (${preset.levelDisplay})',
                          style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      );
                    }),
                  ],
                  onChanged: (newVal) {
                    if (newVal != null) {
                      setState(() {
                        _selectedPreset = newVal;
                        widget.session.switchPreset(newVal);
                      });
                      widget.onSquadUpdated();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bag of Tricks Special Action
            if (_selectedPreset.isRandomTable) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.casino),
                label: const Text('🎲 Roll & Pull Random Animal from Bag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: _rollBagOfTricks,
              ),
              const SizedBox(height: 16),
            ],

            // Horn of Valhalla Special Variant Rollers
            if (_selectedPreset.id == 'horn_of_valhalla') ...[
              const Text(
                '📯 ROLL HORN OF VALHALLA VARIANTS',
                style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip('📯 Silver (2d4+2)', () => _rollHornOfValhalla('silver', 'Silver Horn')),
                  _buildChip('📯 Brass (3d4+3)', () => _rollHornOfValhalla('brass', 'Brass Horn')),
                  _buildChip('📯 Bronze (4d4+4)', () => _rollHornOfValhalla('bronze', 'Bronze Horn')),
                  _buildChip('📯 Iron (5d4+5)', () => _rollHornOfValhalla('iron', 'Iron Horn')),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Quick Add Section for Current Preset
            const Text(
              '⚡ QUICK ADD MINIONS',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_selectedPreset.id == 'animate_objects') ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip('10x Tiny (Coins)', () => _addPresetObjects(ObjectSize.tiny, 10, customName: 'Animated Coin')),
                  _buildChip('5x Small (Daggers)', () => _addPresetObjects(ObjectSize.small, 5, customName: 'Animated Dagger')),
                  _buildChip('5x Medium (Swords)', () => _addPresetObjects(ObjectSize.medium, 5, customName: 'Animated Sword')),
                  _buildChip('2x Large (Statues)', () => _addPresetObjects(ObjectSize.large, 2, customName: 'Animated Statue')),
                  _buildChip('1x Huge (Boulders)', () => _addPresetObjects(ObjectSize.huge, 1, customName: 'Animated Boulder')),
                ],
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedPreset.statBlocks.map((sb) {
                  return _buildChip('+1 ${sb.name}', () => _addMinions(sb, 1));
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // Stat Block Cards List for active preset
            Text(
              '➕ AVAILABLE ${widget.session.activePreset.name.toUpperCase()} CREATURES',
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Column(
              children: _selectedPreset.statBlocks.map((sb) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sb.accentColor.withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: sb.accentColor.withValues(alpha: 0.2),
                      child: Text(
                        sb.crDisplay,
                        style: TextStyle(color: sb.accentColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(sb.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        if (sb.hasPackTactics) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Pack Tactics', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      'HP ${sb.maxHp} | AC ${sb.ac} | +${sb.attackBonus} to hit | ${sb.fullDamageFormula}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.amber),
                          tooltip: 'Add 1 ${sb.name} to squad',
                          onPressed: () => _addMinions(sb, 1),
                        ),
                        if (_selectedPreset.id != 'animate_objects')
                          Semantics(
                            label: 'Add 4 ${sb.name} to squad',
                            button: true,
                            excludeSemantics: true,
                            child: TextButton(
                              onPressed: () => _addMinions(sb, 4),
                              child: const Text('+4', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, VoidCallback onTap) {
    return ActionChip(
      backgroundColor: const Color(0xFF2C2840),
      side: const BorderSide(color: Colors.amber, width: 1),
      label: Text(label, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
      onPressed: onTap,
    );
  }
}
