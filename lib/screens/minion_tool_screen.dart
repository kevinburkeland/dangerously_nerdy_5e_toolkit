import 'package:flutter/material.dart';
import '../models/spell_session.dart';
import '../models/srd_summons/srd_summons_library.dart';
import '../services/haptic_service.dart';
import '../services/minion_session_service.dart';
import '../services/rules/dnd_5e_rules_engine.dart';
import '../utils/secure_random.dart';
import '../widgets/minions/active_session_header.dart';
import '../widgets/dialogs/action_economy_dialog.dart';
import '../widgets/dialogs/batch_attack_dialog.dart';
import '../widgets/dialogs/condition_reference_dialog.dart';
import '../widgets/dialogs/squad_initiative_dialog.dart';
import '../widgets/dialogs/value_input_dialog.dart';
import '../widgets/fx/critical_effect_overlay.dart';
import '../widgets/minions/object_card.dart';
import '../widgets/minions/squad_builder.dart';
import '../widgets/app_logo.dart';
import '../widgets/room_banner_widget.dart';
import '../widgets/spell_reference.dart';

class MinionToolScreen extends StatefulWidget {
  final SummonPreset preset;
  final String? customTitle;
  final int defaultSpellLevel;
  final MinionSessionService? sessionService;
  final SpellSession? session;

  const MinionToolScreen({
    super.key,
    required this.preset,
    this.customTitle,
    this.defaultSpellLevel = 5,
    this.sessionService,
    this.session,
  });

  @override
  State<MinionToolScreen> createState() => _MinionToolScreenState();
}

class _MinionToolScreenState extends State<MinionToolScreen> with SingleTickerProviderStateMixin {
  late final SpellSession _session;
  late final TabController _tabController;
  final CriticalEffectController _critController = CriticalEffectController();

  @override
  void initState() {
    super.initState();
    final service = widget.sessionService ?? MinionSessionService();
    _session = widget.session ??
        service.getOrCreateSession(
          widget.preset,
          defaultSpellLevel: widget.defaultSpellLevel,
        );
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openBatchAttackDialog() {
    HapticService.mediumImpact(context);
    showDialog(
      context: context,
      builder: (ctx) => BatchAttackDialog(
        session: _session,
      ),
    );
  }

  void _openSquadBuilder() {
    HapticService.selectionTick(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SquadBuilderBottomSheet(
        session: _session,
        onSquadUpdated: () {
          _critController.trigger(CritEffectType.spellBurst);
          setState(() {});
        },
      ),
    );
  }

  Future<void> _showMassDamageDialog() async {
    final dmg = await ValueInputDialog.showMassDamage(context);
    if (dmg != null && dmg > 0 && mounted) {
      HapticService.heavyImpact(context);
      _critController.trigger(CritEffectType.critFumble);
      setState(() {
        _session.applyGroupDamage(dmg);
      });
    }
  }

  void _rollSquadInitiative() {
    HapticService.mediumImpact(context);
    int dexMod = 0;
    String minionName = widget.preset.name;
    if (_session.activeObjects.isNotEmpty) {
      final first = _session.activeObjects.first;
      dexMod = first.size.dexScore.dndModifier;
      minionName = first.name;
    }
    final natRoll = secureRandom.nextInt(20) + 1;
    final total = natRoll + dexMod;

    SquadInitiativeDialog.show(
      context,
      total: total,
      natRoll: natRoll,
      dexMod: dexMod,
      minionName: minionName,
      onReroll: _rollSquadInitiative,
    );
  }

  Future<void> _grantGroupTempHp() async {
    HapticService.selectionTick(context);
    final amount = await ValueInputDialog.showGroupTempHp(context);

    if (amount != null && amount > 0 && mounted) {
      HapticService.heavyImpact(context);
      setState(() {
        for (final obj in _session.activeObjects) {
          if (!obj.isDead) {
            obj.grantTempHp(amount);
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Granted +$amount Temp HP to all living minions!'),
        ),
      );
    }
  }

  Future<void> _confirmClearSquad() async {
    HapticService.selectionTick(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Squad'),
        content: const Text('Remove all summoned minions and reset squad points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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
      HapticService.heavyImpact(context);
      setState(() => _session.clearAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final titleText = widget.customTitle ?? widget.preset.name;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDualPane = screenWidth >= 950;
    final theme = Theme.of(context);

    return CriticalEffectOverlay(
      controller: _critController,
      child: Scaffold(
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
              const AppLogo(size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titleText,
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 17),
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
              icon: Icon(Icons.medical_information_outlined, color: theme.colorScheme.secondary),
              tooltip: 'Status Effects & Conditions Guide',
              onPressed: () => ConditionReferenceDialog.show(context),
            ),
            if (!widget.preset.isRandomTable && widget.preset.id != 'figurines_of_wondrous_power')
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _session.spellLevel,
                    dropdownColor: theme.colorScheme.surface,
                    icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                    items: List.generate(9, (index) {
                      int lvl = index + 1;
                      return DropdownMenuItem(
                        value: lvl,
                        child: Text(
                          'Slot Lvl $lvl',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.55),
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
                  Expanded(
                    flex: 11,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: _buildActiveSquadView(),
                    ),
                  ),
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
      ),
    );
  }

  Widget _buildActiveSquadView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: RoomBannerWidget(),
        ),
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
                      onNameChanged: (name) => setState(() => _session.renameObject(obj.id, name)),
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
