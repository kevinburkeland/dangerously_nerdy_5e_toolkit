import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../models/srd_summons.dart';
import '../widgets/animate_objects/active_session_card.dart';
import '../widgets/object_card.dart';
import '../widgets/batch_attack_dialog.dart';
import '../widgets/squad_builder.dart';
import '../widgets/spell_reference.dart';
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
      int count = 4;
      if (id == 'conjure_elemental') count = 1;
      if (id == 'figurines_of_wondrous_power') count = 1;
      if (id == 'giant_insect') count = 2;

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

  void _showMassDamageDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF242038),
        title: const Text('Apply Group Damage (e.g. AoE spell)', style: TextStyle(color: Colors.redAccent)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Damage Amount to ALL minions',
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final dmg = int.tryParse(controller.text);
              if (dmg != null && dmg > 0) {
                setState(() {
                  _session.applyGroupDamage(dmg);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply Damage', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final titleText = widget.customTitle ?? widget.preset.name;

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
        bottom: TabBar(
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: ACTIVE SQUAD TRACKER
              Column(
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
                    onHealAll: () => setState(() => _session.healAll()),
                    onShowMassDamageDialog: _showMassDamageDialog,
                    onClearSquad: () => setState(() => _session.clearAll()),
                  ),

                  // Objects / Minions List
                  Expanded(
                    child: _session.activeObjects.isEmpty
                        ? Center(
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
                          )
                        : ListView.builder(
                            itemCount: _session.activeObjects.length,
                            itemBuilder: (context, index) {
                              final obj = _session.activeObjects[index];
                              return ObjectCard(
                                key: ValueKey(obj.id),
                                object: obj,
                                onDelete: () => setState(() => _session.removeObject(obj.id)),
                                onHpChanged: (delta) => setState(() => obj.currentHp = (obj.currentHp + delta).clamp(0, obj.maxHp)),
                                onNameChanged: (name) => setState(() => obj.name = name),
                              );
                            },
                          ),
                  ),
                ],
              ),

              // TAB 2: SPELL REFERENCE
              SpellReferenceWidget(initialPreset: widget.preset),
            ],
          ),
        ),
      ),
    );
  }
}
