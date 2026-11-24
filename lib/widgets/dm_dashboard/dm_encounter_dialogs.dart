import 'package:material_ui/material_ui.dart';

import '../../models/animated_object.dart';
import '../../models/campaign_profile.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/session_graph_models.dart';
import '../../providers/dm_dashboard_controller.dart';
import '../../services/persistence/character_persistence_service.dart';
import '../../theme/domain_ui_extensions.dart';

Future<void> showDmAddCombatantDialog({
  required BuildContext context,
  required CampaignProfile? activeProfile,
  required void Function(List<EncounterParticipant> list) onUpdateEncounter,
}) async {
    final nameCtrl = TextEditingController(text: 'Goblin Scout');
    final hpCtrl = TextEditingController(text: '15');
    final acCtrl = TextEditingController(text: '13');
    final initCtrl = TextEditingController(text: '12');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Combatant to Encounter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Name / Label', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hpCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Max HP', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: acCtrl,
                      decoration: const InputDecoration(
                          labelText: 'AC', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: initCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Initiative',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final hp = int.tryParse(hpCtrl.text.trim()) ?? 10;
                final ac = int.tryParse(acCtrl.text.trim()) ?? 10;
                final init = int.tryParse(initCtrl.text.trim()) ?? 10;

                final now = DateTime.now().millisecondsSinceEpoch;
                final newCombatant = EncounterParticipant(
                  participantId: 'p_$now',
                  entityLink: RoomEntityLink(
                    refType: SessionRefType.monster,
                    entityId: 'monster_$now',
                    displayName: name,
                  ),
                  initiativeScore: init,
                  currentHp: hp,
                  maxHp: hp,
                  defense: ac,
                  isActiveTurn:
                      activeProfile?.roomState.activeEncounterList.isEmpty ??
                          true,
                );

                final list = List<EncounterParticipant>.from(
                    activeProfile?.roomState.activeEncounterList ?? [])
                  ..add(newCombatant);
                // Sort by initiative descending
                list.sort(
                    (a, b) => (b.initiativeScore ?? 0).compareTo(a.initiativeScore ?? 0));

                Navigator.pop(ctx);
                onUpdateEncounter(list);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }


Future<void> showDmAddPartyMemberDialog({
  required BuildContext context,
  required CampaignProfile? activeProfile,
  required DmDashboardController controller,
}) async {
    final existingRoster = await CharacterPersistenceService().loadCharacters();
    final linkedIds = activeProfile?.partyCharacterIds ?? const [];
    final unlinkedCharacters =
        existingRoster.where((c) => !linkedIds.contains(c.id.slug)).toList();

    if (!context.mounted) return;

    final nameCtrl = TextEditingController(text: 'Valeros the Fighter');
    final levelCtrl = TextEditingController(text: '3');
    final acCtrl = TextEditingController(text: '16');
    final hpCtrl = TextEditingController(text: '28');
    final wisCtrl = TextEditingController(text: '12');
    Character? selectedExisting =
        unlinkedCharacters.isNotEmpty ? unlinkedCharacters.first : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return DefaultTabController(
              length: unlinkedCharacters.isNotEmpty ? 2 : 1,
              child: AlertDialog(
                title: const Text('Add Character to Party Roster'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unlinkedCharacters.isNotEmpty)
                        const TabBar(
                          tabs: [
                            Tab(
                                icon: Icon(Icons.person_add_alt_1),
                                text: 'Existing'),
                            Tab(icon: Icon(Icons.flash_on), text: 'Quick Hero'),
                          ],
                        ),
                      SizedBox(
                        height: 280,
                        child: TabBarView(
                          children: [
                            if (unlinkedCharacters.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Select a saved character from your library to link to this campaign:',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<Character>(
                                    initialValue: selectedExisting,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Saved Character',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: unlinkedCharacters.map((c) {
                                      return DropdownMenuItem<Character>(
                                        value: c,
                                        child: Text(
                                          '${c.name} (Lvl ${c.totalLevel} ${c.classesSummary})',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setDialogState(
                                          () => selectedExisting = val);
                                    },
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.link),
                                      label:
                                          const Text('Link Selected Character'),
                                      onPressed: selectedExisting == null
                                          ? null
                                          : () async {
                                              await controller
                                                  .addCharacterToParty(
                                                      selectedExisting!);
                                              if (ctx.mounted)
                                                Navigator.pop(ctx);
                                            },
                                    ),
                                  ),
                                ],
                              ),
                            SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Character Name',
                                        border: OutlineInputBorder()),
                                    autofocus: unlinkedCharacters.isEmpty,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: levelCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Level',
                                              border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: acCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'AC',
                                              border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: hpCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'Max HP',
                                              border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: wisCtrl,
                                          decoration: const InputDecoration(
                                              labelText: 'WIS Score',
                                              border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create & Link Hero'),
                                      onPressed: () async {
                                        final name =
                                            nameCtrl.text.trim().isNotEmpty
                                                ? nameCtrl.text.trim()
                                                : 'Adventurer';
                                        final lvl = int.tryParse(
                                                levelCtrl.text.trim()) ??
                                            1;
                                        final hp =
                                            int.tryParse(hpCtrl.text.trim()) ??
                                                20;
                                        final ac =
                                            int.tryParse(acCtrl.text.trim()) ??
                                                15;
                                        final wis =
                                            int.tryParse(wisCtrl.text.trim()) ??
                                                10;
                                        final now = DateTime.now()
                                            .millisecondsSinceEpoch;

                                        final char = Character(
                                          id: EntityId(
                                              slug: 'hero_$now',
                                              ruleset: RulesetVersion.v2024),
                                          name: name,
                                          speciesRef: const EntityReference.empty(
                                              slug: 'human',
                                              refType: EntityType.species,
                                              displayName: 'Human'),
                                          progression: CharacterProgression(
                                            classes: [
                                              ClassLevelProgression(
                                                classRef: const EntityReference.empty(
                                                  slug: 'fighter',
                                                  refType: EntityType
                                                      .classDefinition,
                                                  displayName: 'Fighter',
                                                ),
                                                level: lvl,
                                                hitDie: 'd10',
                                              ),
                                            ],
                                          ),
                                          customProperties: {
                                            'armorClass': ac,
                                            'maxHp': hp,
                                          },
                                          baseScores: AbilityScores(
                                            strength: 16,
                                            dexterity: 14,
                                            constitution: 14,
                                            intelligence: 10,
                                            wisdom: wis,
                                            charisma: 8,
                                          ),
                                          resources: CharacterResourcePool(
                                            currentHp: hp,
                                            spellSlots: SpellSlotPool(
                                              maxSlots: lvl >= 3
                                                  ? const {1: 4, 2: 2}
                                                  : const {},
                                              currentSlots: lvl >= 3
                                                  ? const {1: 4, 2: 2}
                                                  : const {},
                                            ),
                                          ),
                                        );

                                        await controller
                                            .addCharacterToParty(char);
                                        if (ctx.mounted) {
                                          Navigator.pop(ctx);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Minions & Animated Objects Handlers ---


Future<void> showDmAddMinionDialog({
  required BuildContext context,
  required DmDashboardController controller,
}) async {
    ObjectSize selectedSize = ObjectSize.medium;
    final nameCtrl = TextEditingController(text: 'Animated Table');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: const Text('Summon / Animate Object'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Minion Name', border: OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  const Text('Size Classification:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ObjectSize.values.map((s) {
                      return ChoiceChip(
                        label: Text('${s.displayName} (HP ${s.maxHp})'),
                        selected: selectedSize == s,
                        selectedColor: s.accentColor.withValues(alpha: 0.3),
                        onSelected: (_) => setDlgState(() => selectedSize = s),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final now = DateTime.now().millisecondsSinceEpoch;
                    final minion = AnimatedObjectInstance(
                      id: 'minion_$now',
                      name: name,
                      size: selectedSize,
                      currentHp: selectedSize.maxHp,
                      maxHp: selectedSize.maxHp,
                    );

                    controller.addMinion(minion);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Summon'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Party Purse Adjustments ---


