import 'package:flutter/material.dart';
import '../models/animated_object.dart';
import '../models/spell_session.dart';
import '../widgets/object_card.dart';
import '../widgets/batch_attack_dialog.dart';
import '../widgets/squad_builder.dart';
import '../widgets/spell_reference.dart';
import '../widgets/room_banner_widget.dart';

class AnimateObjectsScreen extends StatefulWidget {
  const AnimateObjectsScreen({super.key});

  @override
  State<AnimateObjectsScreen> createState() => _AnimateObjectsScreenState();
}

class _AnimateObjectsScreenState extends State<AnimateObjectsScreen> with SingleTickerProviderStateMixin {
  late SpellSession _session;
  late TabController _tabController;

  // Shared Room state
  String? _activeRoomCode;
  String? _playerName;

  @override
  void initState() {
    super.initState();
    _session = SpellSession(spellLevel: 5);
    _tabController = TabController(length: 2, vsync: this);

    // Default preset: 10 Tiny objects (silver coins) for immediate playability
    for (int i = 1; i <= 10; i++) {
      _session.addObject(ObjectSize.tiny, customName: 'Silver Coin #$i');
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
    TextEditingController controller = TextEditingController();
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
            labelText: 'Damage Amount to ALL objects',
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
              int? dmg = int.tryParse(controller.text);
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
    final used = _session.usedPoints;
    final maxPts = _session.maxPoints;
    final pct = (used / maxPts).clamp(0.0, 1.0);
    final canPop = Navigator.canPop(context);

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
            const Text(
              'Animate Objects 5e',
              style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Spell Slot Level Picker Dropdown
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
                items: List.generate(5, (index) {
                  int lvl = 5 + index;
                  int pts = 10 + index * 2;
                  return DropdownMenuItem(
                    value: lvl,
                    child: Text(
                      '${lvl}th Level ($pts pts)',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
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
            Tab(icon: Icon(Icons.menu_book), text: 'Spell Rules'),
          ],
        ),
      ),
      body: TabBarView(
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

              // Point Budget & Quick Action Header
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF191626),
                child: Column(
                  children: [
                    // Budget Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Point Budget: $used / $maxPts points used',
                          style: TextStyle(
                            color: used > maxPts ? Colors.redAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_session.activeObjects.length} Objects',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          used > maxPts ? Colors.redAccent : Colors.amber,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Quick Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: _openBatchAttackDialog,
                            icon: const Icon(Icons.flash_on, size: 20),
                            label: const Text(
                              'BATCH ATTACK',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F2B96),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onPressed: _openSquadBuilder,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                          color: const Color(0xFF242038),
                          onSelected: (val) {
                            setState(() {
                              if (val == 'heal') {
                                _session.healAll();
                              } else if (val == 'damage') {
                                _showMassDamageDialog();
                              } else if (val == 'clear') {
                                _session.clearAll();
                              }
                            });
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'heal',
                              child: Row(
                                children: [
                                  Icon(Icons.health_and_safety, color: Colors.greenAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Heal All Objects', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'damage',
                              child: Row(
                                children: [
                                  Icon(Icons.bolt, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Apply Group AoE Damage', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Clear Squad', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Objects List
              Expanded(
                child: _session.activeObjects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.blur_on, size: 64, color: Colors.white24),
                            const SizedBox(height: 12),
                            const Text(
                              'No animated objects currently active',
                              style: TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                              onPressed: _openSquadBuilder,
                              icon: const Icon(Icons.add, color: Colors.black),
                              label: const Text('Assemble Squad', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          const SpellReferenceWidget(),
        ],
      ),
    );
  }
}
