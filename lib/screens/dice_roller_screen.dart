import 'package:flutter/material.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';
import '../models/room_roll.dart';
import '../services/dice_room_service.dart';
import '../services/preset_service.dart';
import '../widgets/dialogs/custom_die_dialog.dart';
import '../widgets/dialogs/preset_import_export_dialogs.dart';
import '../widgets/dialogs/save_preset_dialog.dart';
import '../widgets/dice_roller/dice_pool_builder.dart';
import '../widgets/dice_roller/latest_roll_card.dart';
import '../widgets/dice_roller/roll_history_list.dart';
import '../widgets/dice_roller/roll_presets_section.dart';
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

  Future<void> _showCustomDieDialog() async {
    final sides = await CustomDieDialog.show(context, initialSides: _customSides);
    if (sides != null && mounted) {
      setState(() {
        _customSides = sides;
        _onSelectDieChip(DieType.custom, customSides: sides);
      });
    }
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

      final roomCode = _roomService.activeRoomCode ?? _activeRoomCode;
      final player = _roomService.playerName ?? _playerName;
      if (roomCode != null && player != null) {
        final roomRoll = RoomRoll.fromDiceRollResult(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          roomCode: roomCode,
          playerName: player,
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

  Future<void> _showSavePresetDialog() async {
    final name = await SavePresetDialog.show(context, formulaText: _currentFormulaString);
    if (name != null && name.isNotEmpty && mounted) {
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
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved custom preset "$name"!'),
            backgroundColor: const Color(0xFF28243D),
          ),
        );
      }
    }
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

    if (confirm == true && mounted) {
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

  Future<void> _showExportPresetDialog() async {
    final jsonStr = await _presetService.exportPresetsJson();
    if (mounted) {
      await ExportPresetDialog.show(context, jsonStr);
    }
  }

  Future<void> _showImportPresetDialog() async {
    final text = await ImportPresetDialog.show(context);
    if (text != null && text.isNotEmpty && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final updated = await _presetService.importPresetsJson(text);
        if (mounted) {
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
        }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

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
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text(
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
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
            LatestRollCard(latestResult: _latestResult),

            const SizedBox(height: 20),

            // 2. DIE SELECTOR & POOL BUILDER
            DicePoolBuilder(
              dicePool: _dicePool,
              modifier: _modifier,
              rollMode: _rollMode,
              customSides: _customSides,
              onSelectDie: _onSelectDieChip,
              onShowCustomDieDialog: _showCustomDieDialog,
              onResetPool: _clearPool,
              onUpdateDicePool: (pool) => setState(() => _dicePool = pool),
              onUpdateModifier: (mod) => setState(() => _modifier = mod),
              onUpdateRollMode: (mode) => setState(() => _rollMode = mode),
            ),

            const SizedBox(height: 16),

            // 3. ROLL PRESETS
            RollPresetsSection(
              userPresets: _userPresets,
              onApplyPreset: _applyCustomPreset,
              onDeletePreset: _deleteCustomPreset,
              onSaveCurrentPreset: _showSavePresetDialog,
              onExportPresets: _showExportPresetDialog,
              onImportPresets: _showImportPresetDialog,
            ),

            const SizedBox(height: 20),

            // 4. ROLL BUTTON
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

            // 5. ROLL HISTORY / LIVE ROOM ROLL FEED
            RollHistoryList(
              localHistory: _history,
              activeRoomCode: _activeRoomCode,
              playerName: _playerName,
              roomService: _roomService,
            ),
          ],
        ),
      ),
    ),
  ),
);
}
}
