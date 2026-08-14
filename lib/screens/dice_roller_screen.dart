import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_preset.dart';
import '../models/dice_roll.dart';
import '../models/room_roll.dart';
import '../providers/settings_provider.dart';
import '../services/base_room_service.dart';
import '../services/dice_room_service.dart';
import '../services/haptic_service.dart';
import '../services/preset_service.dart';
import '../services/preset_service_interface.dart';
import '../utils/secure_random.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/dialogs/custom_die_dialog.dart';
import '../widgets/dialogs/preset_import_export_dialogs.dart';
import '../widgets/dialogs/save_preset_dialog.dart';
import '../widgets/dice_roller/animated_dice_roller.dart';
import '../widgets/dice_roller/dice_pool_builder.dart';
import '../widgets/dice_roller/latest_roll_card.dart';
import '../widgets/dice_roller/roll_history_list.dart';
import '../widgets/dice_roller/roll_presets_section.dart';
import '../widgets/fx/critical_effect_overlay.dart';
import '../widgets/room_banner_widget.dart';

class DiceRollerScreen extends StatefulWidget {
  final IPresetService? presetService;
  final BaseRoomService? roomService;

  const DiceRollerScreen({
    super.key,
    this.presetService,
    this.roomService,
  });

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

  // FX & Animation Controllers
  final CriticalEffectController _critController = CriticalEffectController();
  DiceRollResult? _animatingResult;
  bool _showAnimatedRoll = false;

  // Shared Room state
  String? _activeRoomCode;
  String? _playerName;
  late final BaseRoomService _roomService;

  // Custom Presets State
  List<CustomPreset> _userPresets = [];
  late final IPresetService _presetService;

  @override
  void initState() {
    super.initState();
    _roomService = widget.roomService ?? DiceRoomService();
    _presetService = widget.presetService ?? PresetService();
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
    HapticService.selectionTick(context);
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
    HapticService.selectionTick(context);
    final sides = await CustomDieDialog.show(context, initialSides: _customSides);
    if (sides != null && sides >= 2 && sides <= 1000) {
      setState(() {
        _customSides = sides;
        _onSelectDieChip(DieType.custom, customSides: sides);
      });
    }
  }

  void _clearPool() {
    HapticService.selectionTick(context);
    setState(() {
      _dicePool = [DiceEntry(dieType: DieType.d20, count: 1)];
      _rollMode = RollMode.normal;
    });
  }

  DateTime? _lastRollTime;

  void _rollDice() {
    final now = DateTime.now();
    if (_lastRollTime != null && now.difference(_lastRollTime!).inMilliseconds < 150) {
      return; // Debounce rapid button mashing (<150ms cooldown)
    }
    _lastRollTime = now;

    if (_dicePool.isEmpty) {
      _dicePool = [DiceEntry(dieType: DieType.d20, count: 1)];
    }

    final isSingleD20 = _dicePool.length == 1 &&
        _dicePool.first.dieType == DieType.d20 &&
        _dicePool.first.count == 1;

    final res = DiceRollResult.rollPool(
      diceEntries: _dicePool,
      modifier: _modifier,
      rollMode: isSingleD20 ? _rollMode : RollMode.normal,
    );

    final settings = SettingsScope.of(context).settings;

    setState(() {
      _latestResult = res;
      _history.insert(0, res);
      if (_history.length > 50) {
        _history.removeLast();
      }

      if (settings.enable3dDiceOverlays && !settings.performanceMode) {
        _animatingResult = res;
        _showAnimatedRoll = true;
      }
    });

    if (res.isCrit) {
      _critController.trigger(CritEffectType.critSuccess);
    } else if (res.isFumble) {
      _critController.trigger(CritEffectType.critFumble);
    } else {
      HapticService.lightImpact(context);
    }

    // Send roll to room if connected
    final currentRoomCode = _activeRoomCode;
    final currentPlayerName = _playerName;
    if (currentRoomCode != null && currentPlayerName != null) {
      final roomRoll = RoomRoll.fromDiceRollResult(
        id: '${DateTime.now().microsecondsSinceEpoch}_${SecureRng.instance.nextInt(1000000)}',
        roomCode: currentRoomCode,
        playerName: currentPlayerName,
        result: res,
      );
      _roomService.broadcastRoll(roomRoll);
    }
  }

  void _applyCustomPreset(CustomPreset preset) {
    HapticService.selectionTick(context);
    setState(() {
      _dicePool = preset.diceEntries.map((e) => e.copyWith()).toList();
      _modifier = preset.modifier;
      _rollMode = preset.rollMode;
    });
  }

  void _clearHistory() {
    HapticService.selectionTick(context);
    setState(() {
      _history.clear();
      _latestResult = null;
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
    HapticService.selectionTick(context);
    final name = await SavePresetDialog.show(context, formulaText: _currentFormulaString);
    if (name != null && name.isNotEmpty && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${SecureRng.instance.nextInt(1000000)}';
      final newPreset = CustomPreset(
        id: uniqueId,
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
          ),
        );
      }
    }
  }

  Future<void> _deleteCustomPreset(CustomPreset preset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Preset'),
        content: Text('Delete preset "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final updated = await _presetService.deletePreset(preset.id);
      if (mounted) {
        setState(() {
          _userPresets = updated;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Deleted "${preset.name}"')),
        );
      }
    }
  }

  Future<void> _showExportPresetDialog() async {
    HapticService.selectionTick(context);
    final jsonStr = await _presetService.exportPresetsJson();
    if (mounted) {
      await ExportPresetDialog.show(context, jsonStr);
    }
  }

  Future<void> _showImportPresetDialog() async {
    HapticService.selectionTick(context);
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
              content: Text('Successfully imported ${updated.length} custom presets!'),
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to import presets. Please verify the JSON payload format.'),
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
    final settingsProvider = SettingsScope.of(context);
    final settings = settingsProvider.settings;
    final theme = Theme.of(context);

    return CriticalEffectOverlay(
      controller: _critController,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              elevation: 2,
              leading: canPop
                  ? IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              actions: [
                // Quick Toggle for Animated 3D/Rolling Dice Overlay
                IconButton(
                  icon: Icon(
                    settings.enable3dDiceOverlays ? Icons.auto_awesome_motion : Icons.auto_awesome_motion_outlined,
                    color: settings.enable3dDiceOverlays ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  tooltip: settings.enable3dDiceOverlays ? 'Animated Dice: Enabled' : 'Animated Dice: Disabled',
                  onPressed: () {
                    HapticService.selectionTick(context);
                    settingsProvider.set3dDiceOverlays(!settings.enable3dDiceOverlays);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.flash_on, color: Colors.amber),
                  tooltip: 'Combat Action Economy Guide',
                  onPressed: () => ActionEconomyDialog.show(context),
                ),
                IconButton(
                  icon: Icon(Icons.medical_information_outlined, color: theme.colorScheme.secondary),
                  tooltip: 'Status Effects & Conditions Guide',
                  onPressed: () => ConditionReferenceDialog.show(context),
                ),
                if (_history.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
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

                      // 4. ROLL HISTORY / LIVE ROOM ROLL FEED
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
            // PERSISTENT BOTTOM THUMB BAR
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Align(
                  heightFactor: 1.0,
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Row(
                      children: [
                        // Quick Advantage / Disadvantage toggle
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildThumbModeButton(Icons.shield_outlined, RollMode.normal, 'Normal', theme: theme),
                              _buildThumbModeButton(Icons.arrow_upward, RollMode.advantage, 'Advantage', color: Colors.greenAccent, theme: theme),
                              _buildThumbModeButton(Icons.arrow_downward, RollMode.disadvantage, 'Disadvantage', color: Colors.redAccent, theme: theme),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Ergonomic Primary Roll Button
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              onPressed: _rollDice,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.casino, size: 24),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'ROLL $_currentFormulaString',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Animated 3D/tumbling rolling dice overlay
          if (_showAnimatedRoll && _animatingResult != null)
            Positioned.fill(
              child: AnimatedDiceRollOverlay(
                result: _animatingResult!,
                onDismiss: () {
                  setState(() {
                    _showAnimatedRoll = false;
                    _animatingResult = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbModeButton(IconData icon, RollMode mode, String tooltip, {Color? color, required ThemeData theme}) {
    final isSelected = _rollMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticService.selectionTick(context);
        setState(() => _rollMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? theme.colorScheme.primary).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? (color ?? theme.colorScheme.primary) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
