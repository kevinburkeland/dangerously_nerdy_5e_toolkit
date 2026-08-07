import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';
import '../models/room_roll.dart';
import '../services/dice_room_service.dart';
import '../services/preset_service.dart';
import '../widgets/room_banner_widget.dart';

class DiceRollerScreen extends StatefulWidget {
  const DiceRollerScreen({super.key});

  @override
  State<DiceRollerScreen> createState() => _DiceRollerScreenState();
}

class _DiceRollerScreenState extends State<DiceRollerScreen> {
  List<DiceEntry> _dicePool = [DiceEntry(dieType: DieType.d20, count: 1)];
  int _customSides = 7;
  int _modifier = 0;
  RollMode _rollMode = RollMode.normal;

  DiceRollResult? _latestResult;
  final List<DiceRollResult> _history = [];

  // Shared Room state
  String? _activeRoomCode;
  String? _playerName;
  final DiceRoomService _roomService = DiceRoomService();

  // Custom Presets State
  List<CustomPreset> _userPresets = [];
  final PresetService _presetService = PresetService();

  @override
  void initState() {
    super.initState();
    _loadUserPresets();
  }

  Future<void> _loadUserPresets() async {
    final loaded = await _presetService.loadCustomPresets();
    if (mounted) {
      setState(() {
        _userPresets = loaded;
      });
    }
  }

  DieType get _primaryDie =>
      _dicePool.isNotEmpty ? _dicePool.first.dieType : DieType.d20;
  int get _count => _dicePool.isNotEmpty
      ? _dicePool.fold(0, (acc, val) => acc + val.count)
      : 1;

  void _addDieToPool(DieType dieType, {int customSides = 6}) {
    final existingIndex = _dicePool.indexWhere(
      (e) =>
          e.dieType == dieType &&
          (dieType != DieType.custom || e.customSides == customSides),
    );

    if (existingIndex >= 0) {
      final existing = _dicePool[existingIndex];
      _dicePool[existingIndex] = existing.copyWith(count: existing.count + 1);
    } else {
      _dicePool
          .add(DiceEntry(dieType: dieType, count: 1, customSides: customSides));
    }
  }

  void _onSelectDieChip(DieType die, {int customSides = 6}) {
    setState(() {
      // If pool is just the initial single d20 roll, replace it with the selected die
      if (_dicePool.length == 1 &&
          _dicePool.first.dieType == DieType.d20 &&
          _dicePool.first.count == 1 &&
          die != DieType.d20) {
        _dicePool = [
          DiceEntry(dieType: die, count: 1, customSides: customSides)
        ];
        return;
      }
      _addDieToPool(die, customSides: customSides);
    });
  }

  void _showCustomDieDialog() {
    final controller = TextEditingController(text: '$_customSides');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Row(
          children: [
            Icon(Icons.tune, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('Custom Sided Die', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter number of sides (e.g. 7 for d7, 14 for d14, 30 for d30):',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Number of Sides',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black),
            onPressed: () {
              final sides = int.tryParse(controller.text.trim());
              if (sides != null && sides >= 2) {
                setState(() {
                  _customSides = sides;
                  _onSelectDieChip(DieType.custom, customSides: sides);
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Die',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _clearPool() {
    setState(() {
      _dicePool = [DiceEntry(dieType: DieType.d20, count: 1)];
      _rollMode = RollMode.normal;
    });
  }

  void _rollDice() {
    if (_dicePool.isEmpty) {
      _dicePool = [DiceEntry(dieType: DieType.d20, count: 1)];
    }

    setState(() {
      final isSingleD20 = _dicePool.length == 1 &&
          _dicePool.first.dieType == DieType.d20 &&
          _dicePool.first.count == 1;

      final res = DiceRollResult.rollPool(
        diceEntries: _dicePool,
        modifier: _modifier,
        rollMode: isSingleD20 ? _rollMode : RollMode.normal,
      );
      _latestResult = res;
      _history.insert(0, res);

      // Broadcast roll to active shared room if connected
      if (_activeRoomCode != null && _playerName != null) {
        final roomRoll = RoomRoll.fromDiceRollResult(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          roomCode: _activeRoomCode!,
          playerName: _playerName!,
          result: res,
        );
        _roomService.broadcastRoll(roomRoll);
      }
    });
  }

  void _applyCustomPreset(CustomPreset preset) {
    setState(() {
      _dicePool = List<DiceEntry>.from(preset.diceEntries);
      _modifier = preset.modifier;
      _rollMode = preset.rollMode;
    });
    _rollDice();
  }

  void _applyPreset(DieType die, int count, int mod,
      [RollMode mode = RollMode.normal]) {
    setState(() {
      _dicePool = [DiceEntry(dieType: die, count: count)];
      _modifier = mod;
      _rollMode = mode;
    });
    _rollDice();
  }

  void _clearHistory() {
    setState(() {
      _history.clear();
    });
  }

  void _joinRoom(String roomCode, String playerName) {
    setState(() {
      _activeRoomCode = roomCode.trim().toUpperCase();
      _playerName = playerName.trim();
    });
  }

  void _leaveRoom() {
    setState(() {
      _activeRoomCode = null;
    });
  }

  String get _currentFormulaString {
    final dicePart = _dicePool.map((e) => e.formulaString).join(' + ');
    String modStr = '';
    if (_modifier > 0) {
      modStr = ' + $_modifier';
    } else if (_modifier < 0) {
      modStr = ' - ${_modifier.abs()}';
    }
    return '${dicePart.toUpperCase()}$modStr';
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final isSingleD20 = _dicePool.length == 1 &&
        _dicePool.first.dieType == DieType.d20 &&
        _dicePool.first.count == 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 4,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                tooltip: 'Back to Hub',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Row(
          children: [
            Icon(Icons.casino, color: Colors.cyanAccent, size: 26),
            SizedBox(width: 10),
            Text(
              'Dice Roller',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white60),
              tooltip: 'Clear History',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 0. SHARED ROOM BANNER
            RoomBannerWidget(
              activeRoomCode: _activeRoomCode,
              playerName: _playerName,
              onJoinRoom: _joinRoom,
              onLeaveRoom: _leaveRoom,
            ),

            const SizedBox(height: 16),

            // 1. LATEST ROLL RESULT CARD
            _buildLatestResultCard(),

            const SizedBox(height: 20),

            // 2. DIE SELECTOR & POOL BUILDER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Die',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                if (_dicePool.length > 1 ||
                    _dicePool.first.count > 1 ||
                    _dicePool.first.dieType != DieType.d20)
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Icons.refresh,
                        size: 14, color: Colors.cyanAccent),
                    label: const Text('Reset Pool',
                        style:
                            TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                    onPressed: _clearPool,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...DieType.values.where((d) => d != DieType.custom).map((die) {
                  final isInPool = _dicePool.any((e) => e.dieType == die);
                  return ChoiceChip(
                    label: Text(
                      die.label.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isInPool ? Colors.black : Colors.white,
                      ),
                    ),
                    selected: isInPool,
                    selectedColor: Colors.cyanAccent,
                    backgroundColor: const Color(0xFF28243D),
                    onSelected: (selected) {
                      _onSelectDieChip(die);
                    },
                  );
                }),
                ActionChip(
                  avatar:
                      const Icon(Icons.add, size: 16, color: Colors.cyanAccent),
                  label: Text(
                    'CUSTOM (d$_customSides)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                  ),
                  backgroundColor: const Color(0xFF28243D),
                  side: const BorderSide(color: Colors.cyanAccent),
                  onPressed: _showCustomDieDialog,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. ACTIVE DICE POOL & MODIFIER CONTROLS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DICE POOL & MODIFIERS',
                    style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 12),

                  // Dice Pool Entry Items
                  ..._dicePool.asMap().entries.map((entry) {
                    final index = entry.key;
                    final diceEntry = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.cyanAccent
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  diceEntry.dieLabel.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Quantity: ${diceEntry.count}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.cyanAccent),
                                onPressed: () {
                                  setState(() {
                                    if (diceEntry.count > 1) {
                                      _dicePool[index] = diceEntry.copyWith(
                                          count: diceEntry.count - 1);
                                    } else {
                                      if (_dicePool.length > 1) {
                                        _dicePool.removeAt(index);
                                      }
                                    }
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${diceEntry.count}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline,
                                    color: Colors.cyanAccent),
                                onPressed: () {
                                  setState(() {
                                    if (diceEntry.count < 50) {
                                      _dicePool[index] = diceEntry.copyWith(
                                          count: diceEntry.count + 1);
                                    }
                                  });
                                },
                              ),
                              if (_dicePool.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white38, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _dicePool.removeAt(index);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(color: Colors.white10, height: 24),

                  // Modifier Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Modifier',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.orangeAccent),
                            onPressed: () => setState(() => _modifier--),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _modifier >= 0 ? '+$_modifier' : '$_modifier',
                              style: TextStyle(
                                color: _modifier > 0
                                    ? Colors.greenAccent
                                    : _modifier < 0
                                        ? Colors.redAccent
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.orangeAccent),
                            onPressed: () => setState(() => _modifier++),
                          ),
                          if (_modifier != 0)
                            IconButton(
                              icon: const Icon(Icons.refresh,
                                  color: Colors.white38, size: 18),
                              onPressed: () => setState(() => _modifier = 0),
                              tooltip: 'Reset modifier',
                            ),
                        ],
                      ),
                    ],
                  ),

                  // Advantage / Disadvantage for single d20 roll
                  if (isSingleD20) ...[
                    const Divider(color: Colors.white10, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('d20 Advantage',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        SegmentedButton<RollMode>(
                          segments: const [
                            ButtonSegment(
                                value: RollMode.disadvantage,
                                label: Text('Dis')),
                            ButtonSegment(
                                value: RollMode.normal, label: Text('Norm')),
                            ButtonSegment(
                                value: RollMode.advantage, label: Text('Adv')),
                          ],
                          selected: {_rollMode},
                          onSelectionChanged: (newSelection) {
                            setState(() {
                              _rollMode = newSelection.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor:
                                Colors.cyanAccent.withValues(alpha: 0.3),
                            selectedForegroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. ROLL PRESETS (CUSTOM & BUILT-IN)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Presets',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download,
                          size: 18, color: Colors.cyanAccent),
                      tooltip: 'Export Presets (JSON)',
                      onPressed: _showExportPresetDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload,
                          size: 18, color: Colors.cyanAccent),
                      tooltip: 'Import Presets (JSON)',
                      onPressed: _showImportPresetDialog,
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        backgroundColor: Colors.amber.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.bookmark_add,
                          size: 16, color: Colors.amber),
                      label: const Text(
                        'Save Current',
                        style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showSavePresetDialog,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Custom User Presets Section
            const Text(
              'MY SAVED PRESETS',
              style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            if (_userPresets.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _userPresets
                      .map((preset) => _customPresetChip(preset))
                      .toList(),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF28243D),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.bookmark_border, color: Colors.amber, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No custom presets yet. Adjust dice & tap "Save Current" to create one!',
                        style: TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Default Built-in Presets Section
            const Text(
              'QUICK PRESETS',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: PresetService.defaultPresets
                    .map((preset) => _builtInPresetChip(preset))
                    .toList(),
              ),
            ),

            const SizedBox(height: 20),

            // 5. ROLL BUTTON
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _rollDice,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.casino, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'ROLL $_currentFormulaString',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 6. ROLL HISTORY / LIVE ROOM ROLL FEED
            if (_activeRoomCode != null) ...[
              _buildLiveRoomRollFeed(),
            ] else if (_history.isNotEmpty) ...[
              _buildLocalRollHistory(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLiveRoomRollFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Live Feed: $_activeRoomCode',
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
            const Text(
              'Real-Time Sync',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<RoomRoll>>(
          stream: _roomService.streamRoomRolls(_activeRoomCode!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent)),
              );
            }

            final roomRolls = snapshot.data ?? [];

            if (roomRolls.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'No rolls in this room yet. Tap ROLL to broadcast first roll!',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: roomRolls.length,
              itemBuilder: (context, index) {
                final item = roomRolls[index];
                final bool isSelf = item.playerName == _playerName;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelf
                        ? const Color(0xFF23203E)
                        : const Color(0xFF1E1B2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelf
                          ? Colors.cyanAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelf
                                ? Colors.cyanAccent
                                : Colors.purpleAccent,
                            child: Text(
                              item.playerName.isNotEmpty
                                  ? item.playerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.playerName,
                                    style: TextStyle(
                                      color: isSelf
                                          ? Colors.cyanAccent
                                          : Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.formulaString,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rolls: ${item.individualRolls.join(', ')}${item.droppedRolls != null ? ' (dropped ${item.droppedRolls!.join(', ')})' : ''}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: item.isCrit
                              ? Colors.amber.withValues(alpha: 0.2)
                              : item.isFumble
                                  ? Colors.redAccent.withValues(alpha: 0.2)
                                  : Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.isCrit
                                ? Colors.amber
                                : item.isFumble
                                    ? Colors.redAccent
                                    : Colors.white12,
                          ),
                        ),
                        child: Text(
                          '${item.total}',
                          style: TextStyle(
                            color: item.isCrit
                                ? Colors.amber
                                : item.isFumble
                                    ? Colors.redAccent
                                    : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocalRollHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Roll History',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            Text(
              '${_history.length} rolls',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.formulaString,
                        style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rolls: ${item.individualRolls.join(', ')}${item.droppedRolls != null ? ' (dropped ${item.droppedRolls!.join(', ')})' : ''}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isCrit
                          ? Colors.amber.withValues(alpha: 0.2)
                          : item.isFumble
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isCrit
                            ? Colors.amber
                            : item.isFumble
                                ? Colors.redAccent
                                : Colors.white12,
                      ),
                    ),
                    child: Text(
                      '${item.total}',
                      style: TextStyle(
                        color: item.isCrit
                            ? Colors.amber
                            : item.isFumble
                                ? Colors.redAccent
                                : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLatestResultCard() {
    if (_latestResult == null) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino_outlined, size: 48, color: Colors.white24),
            SizedBox(height: 8),
            Text('Tap ROLL to roll the dice!',
                style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }

    final res = _latestResult!;

    Color borderColor = Colors.cyanAccent.withValues(alpha: 0.5);
    Color totalColor = Colors.cyanAccent;
    String badgeText = '';

    if (res.isCrit) {
      borderColor = Colors.amber;
      totalColor = Colors.amber;
      badgeText = 'CRITICAL HIT!';
    } else if (res.isFumble) {
      borderColor = Colors.redAccent;
      totalColor = Colors.redAccent;
      badgeText = 'NATURAL 1!';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  res.formulaString,
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              if (badgeText.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: res.isCrit ? Colors.amber : Colors.redAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Number Display
          Text(
            '${res.total}',
            style: TextStyle(
              color: totalColor,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Breakdown per Die Group
          ...res.groupResults.map((group) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${group.entry.dieLabel.toUpperCase()}: ',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: group.rolls.map((val) {
                      bool isMax =
                          group.entry.dieType == DieType.d20 && val == 20;
                      bool isMin =
                          group.entry.dieType == DieType.d20 && val == 1;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isMax
                              ? Colors.amber.withValues(alpha: 0.3)
                              : isMin
                                  ? Colors.redAccent.withValues(alpha: 0.3)
                                  : Colors.black38,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isMax
                                ? Colors.amber
                                : isMin
                                    ? Colors.redAccent
                                    : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '$val',
                          style: TextStyle(
                            color: isMax
                                ? Colors.amber
                                : isMin
                                    ? Colors.redAccent
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          if (res.droppedRolls != null && res.droppedRolls!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Wrap(
                spacing: 4,
                children: res.droppedRolls!.map((val) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '$val (dropped)',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          if (res.modifier != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Modifier: ${res.modifier > 0 ? "+${res.modifier}" : "${res.modifier}"}',
                style: TextStyle(
                  color:
                      res.modifier > 0 ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSavePresetDialog() {
    final formulaText = _currentFormulaString;
    final nameController = TextEditingController(text: formulaText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Row(
          children: [
            Icon(Icons.bookmark_add, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Save Custom Preset', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Config: $_currentFormulaString',
              style: const TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Preset Name (e.g. Sneak Attack)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.amber)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                final nav = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);

                final newPreset = CustomPreset(
                  id: '${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  diceEntries: _dicePool,
                  modifier: _modifier,
                  rollMode: _rollMode,
                );
                final updated = await _presetService.savePreset(newPreset);
                if (mounted) {
                  setState(() {
                    _userPresets = updated;
                  });
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Saved custom preset "$name"!'),
                      backgroundColor: const Color(0xFF28243D),
                    ),
                  );
                }
              }
            },
            child: const Text('Save Preset',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomPreset(CustomPreset preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title:
            const Text('Delete Preset', style: TextStyle(color: Colors.white)),
        content: Text('Delete preset "${preset.name}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = await _presetService.deletePreset(preset.id);
      if (mounted) {
        setState(() {
          _userPresets = updated;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${preset.name}"')),
        );
      }
    }
  }

  Widget _customPresetChip(CustomPreset preset) {
    return Container(
      margin: const EdgeInsets.only(right: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2744),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _applyCustomPreset(preset),
        child: Padding(
          padding: const EdgeInsets.only(left: 10, right: 6, top: 4, bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                '${preset.name} (${preset.formulaString})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _deleteCustomPreset(preset),
                child: const Padding(
                  padding: EdgeInsets.all(3.0),
                  child: Icon(Icons.close, size: 14, color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExportPresetDialog() async {
    final jsonStr = await _presetService.exportPresetsJson();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('Export Presets JSON', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copy this JSON backup to transfer or save your presets:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr.isNotEmpty ? jsonStr : '[]',
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontFamily: 'monospace',
                      fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard',
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Presets JSON copied to clipboard!'),
                  backgroundColor: Color(0xFF28243D),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showImportPresetDialog() {
    final importController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Row(
          children: [
            Icon(Icons.upload, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('Import Presets JSON', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste custom presets JSON text below:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: importController,
              maxLines: 6,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText:
                    '[{"name": "Fireball", "dieType": "d6", "count": 8, "modifier": 0}]',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton.icon(
            icon: const Icon(Icons.paste, size: 16, color: Colors.cyanAccent),
            label: const Text('Paste Clipboard',
                style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                importController.text = data!.text!;
              }
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black),
            onPressed: () async {
              final text = importController.text.trim();
              if (text.isEmpty) return;

              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final updated = await _presetService.importPresetsJson(text);
                nav.pop();
                if (!mounted) return;
                setState(() {
                  _userPresets = updated;
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Successfully imported ${updated.length} custom presets!'),
                    backgroundColor: const Color(0xFF28243D),
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to import presets: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Import',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _builtInPresetChip(CustomPreset preset) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        backgroundColor: const Color(0xFF28243D),
        side: const BorderSide(color: Colors.white12),
        label: Text('${preset.name} (${preset.formulaString})',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        onPressed: () => _applyCustomPreset(preset),
      ),
    );
  }
}
