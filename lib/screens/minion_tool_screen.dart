import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../models/srd_summons.dart';
import '../utils/secure_random.dart';
import '../widgets/animate_objects/active_session_card.dart';
import '../widgets/object_card.dart';
import '../widgets/batch_attack_dialog.dart';
import '../widgets/squad_builder.dart';
import '../widgets/spell_reference.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/dialogs/mass_damage_dialog.dart';
import '../widgets/room_banner_widget.dart';

class MinionToolScreen extends StatefulWidget {
  final SummonPreset preset;
  final String? customTitle;
  final int defaultSpellLevel;

  const MinionToolScreen({
    super.key,
    required this.preset,
    this.customTitle,
    this.defaultSpellLevel = 5,
  });

  @override
  State<MinionToolScreen> createState() => _MinionToolScreenState();
}

class _MinionToolScreenState extends State<MinionToolScreen> with SingleTickerProviderStateMixin {
  late SpellSession _session;
  late TabController _tabController;

  // Shared Room state
  String? _activeRoomCode;
  String? _playerName;

  @override
  void initState() {
    super.initState();
    _session = SpellSession(
      activePreset: widget.preset,
      spellLevel: widget.defaultSpellLevel,
    );
    _tabController = TabController(length: 2, vsync: this);

    _populateDefaultMinions();
  }

  void _populateDefaultMinions() {
    _session.clearAll();
    final id = widget.preset.id;

    if (id == 'animate_objects') {
      for (int i = 1; i <= 10; i++) {
        _session.addObject(ObjectSize.tiny, customName: 'Silver Coin #$i');
      }
    } else if (id == 'bag_of_tricks') {
      _session.rollBagOfTricks();
    } else if (id == 'horn_of_valhalla') {
      _session.rollHornOfValhalla('silver');
    } else if (widget.preset.statBlocks.isNotEmpty) {
      final defaultStat = widget.preset.statBlocks.first;
      int count = 1;

      if (id == 'conjure_animals') {
        count = 8; // 8 Beasts of CR 1/4 (e.g. 8 Wolves) at 3rd level
      } else if (id == 'create_undead') {
        count = 3; // 3 Ghouls at 6th level
      } else if (id == 'animate_dead') {
        count = 1; // 1 Skeleton / Zombie at 3rd level
      } else if (id == 'conjure_minor_elementals') {
        count = 4; // 4 Elementals of CR 1/2 (e.g. 4 Mephits) at 4th level
      } else if (id == 'giant_insect') {
        count = 10; // Up to 10 Centipedes at 4th level
      } else if (id == 'conjure_elemental' || id == 'figurines_of_wondrous_power') {
        count = 1;
      }

      for (int i = 0; i < count; i++) {
        _session.addMinionFromStatBlock(defaultStat);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  void _openBatchAttackDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => BatchAttackDialog(
        session: _session,
        activeRoomCode: _activeRoomCode,
        playerName: _playerName,
      ),
    );
  }

  void _openSquadBuilder() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SquadBuilderBottomSheet(
        session: _session,
        onSquadUpdated: () => setState(() {}),
      ),
    );
  }

  Future<void> _showMassDamageDialog() async {
    final dmg = await MassDamageDialog.show(context);
    if (dmg != null && dmg > 0 && mounted) {
      HapticFeedback.heavyImpact();
      setState(() {
        _session.applyGroupDamage(dmg);
      });
    }
  }

  void _rollSquadInitiative() {
    HapticFeedback.mediumImpact();
    int dexMod = 0;
    String minionName = widget.preset.name;
    if (_session.activeObjects.isNotEmpty) {
      final first = _session.activeObjects.first;
      dexMod = ((first.size.dexScore - 10) / 2).floor();
      minionName = first.name;
    }
    final natRoll = SecureRng.instance.nextInt(20) + 1;
    final total = natRoll + dexMod;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.casino, color: Colors.amber, size: 24),
            SizedBox(width: 8),
            Text('Squad Initiative Roll', style: TextStyle(color: Colors.amber, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'd20 ($natRoll) ${dexMod >= 0 ? "+$dexMod" : "$dexMod"} DEX modifier',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Rolled for $minionName squad',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            icon: const Icon(Icons.refresh, color: Colors.black, size: 16),
            label: const Text('Re-roll', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              _rollSquadInitiative();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _grantGroupTempHp() async {
    final controller = TextEditingController(text: '5');
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.cyanAccent, size: 22),
            SizedBox(width: 8),
            Text('Grant Group Temp HP', style: TextStyle(color: Colors.cyanAccent, fontSize: 18)),
          ],
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Temporary HP Amount',
            labelStyle: TextStyle(color: Colors.cyanAccent),
            prefixIcon: Icon(Icons.shield, color: Colors.cyanAccent),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent, width: 2)),
          ),
          onSubmitted: (val) => Navigator.pop(ctx, int.tryParse(val)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Grant Temp HP', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (amount != null && amount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        for (final obj in _session.activeObjects) {
          if (!obj.isDead) {
            obj.grantTempHp(amount);
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Granted +$amount Temp HP to all ${_session.activeObjects.where((o) => !o.isDead).length} living minions!'),
          backgroundColor: const Color(0xFF242038),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmClearSquad() async {
    if (_session.activeObjects.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Active Squad?', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'This will remove all ${_session.activeObjects.length} active minions from your active session. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Squad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      setState(() => _session.clearAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final titleText = widget.customTitle ?? widget.preset.name;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDualPane = screenWidth >= 950;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 4,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.amber),
                tooltip: 'Back to Hub',
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amber),
            tooltip: 'Combat Action Economy Guide',
            onPressed: () => ActionEconomyDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.medical_information_outlined, color: Colors.cyanAccent),
            tooltip: 'Status Effects & Conditions Guide',
            onPressed: () => ConditionReferenceDialog.show(context),
          ),
          // Spell Slot Level Picker Dropdown (for spell presets)
          if (!widget.preset.isRandomTable && widget.preset.id != 'figurines_of_wondrous_power')
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _session.spellLevel,
                  dropdownColor: const Color(0xFF242038),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                  items: List.generate(9, (index) {
                    int lvl = index + 1;
                    return DropdownMenuItem(
                      value: lvl,
                      child: Text(
                        'Slot Lvl $lvl',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _session.spellLevel = val;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
        bottom: isDualPane
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.shield_outlined), text: 'Active Squad'),
                  Tab(icon: Icon(Icons.menu_book), text: 'Minion Rulebook'),
                ],
              ),
      ),
      body: isDualPane
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT PANE: SQUAD TRACKER (55% Width)
                Expanded(
                  flex: 11,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ),
                    child: _buildActiveSquadView(),
                  ),
                ),
                // RIGHT PANE: RULEBOOK & CREATURE PROFILES (45% Width)
                Expanded(
                  flex: 9,
                  child: SpellReferenceWidget(initialPreset: _session.activePreset),
                ),
              ],
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveSquadView(),
                    SpellReferenceWidget(initialPreset: _session.activePreset),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActiveSquadView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: RoomBannerWidget(
            activeRoomCode: _activeRoomCode,
            playerName: _playerName,
            onJoinRoom: _joinRoom,
            onLeaveRoom: _leaveRoom,
          ),
        ),

        // Point Budget & Quick Action Header Widget
        ActiveSessionHeader(
          session: _session,
          onBatchAttack: _openBatchAttackDialog,
          onOpenSquadBuilder: _openSquadBuilder,
          onRollInitiative: _rollSquadInitiative,
          onGrantGroupTempHp: _grantGroupTempHp,
          onHealAll: () => setState(() => _session.healAll()),
          onShowMassDamageDialog: _showMassDamageDialog,
          onClearSquad: _confirmClearSquad,
        ),

        // Objects / Minions List
        Expanded(
          child: _session.activeObjects.isEmpty
              ? _buildEmptySquadState()
              : ListView.builder(
                  itemCount: _session.activeObjects.length,
                  itemBuilder: (context, index) {
                    final obj = _session.activeObjects[index];
                    return ObjectCard(
                      key: ValueKey(obj.id),
                      object: obj,
                      onDelete: () => setState(() => _session.removeObject(obj.id)),
                      onHpChanged: (delta) {
                        setState(() {
                          if (delta < 0) {
                            obj.takeDamage(-delta);
                          } else {
                            obj.heal(delta);
                          }
                        });
                      },
                      onHpDataSet: (newHp, newTemp) {
                        setState(() {
                          obj.currentHp = newHp;
                          obj.tempHp = newTemp;
                        });
                      },
                      onNameChanged: (name) => setState(() => obj.name = name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptySquadState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.blur_on, size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            'No active minions in ${_session.activePreset.name}',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: _openSquadBuilder,
            icon: const Icon(Icons.add, color: Colors.black),
            label: const Text(
              'Assemble Squad',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
