#!/usr/bin/env python3
import os
import subprocess
import sys
import tempfile
import shutil

REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

ERAS = {
    "E9": {
        "commit": "dd56da8a9e4b789c13cf8aa910bb9a1dd05d92ce",
        "date": "2026-10-26",
        "notes": "Full current schema with map tokens, map grid, member purses, and recordVersion",
    },
    "E8": {
        "commit": "9afc42d8ae3625262b142578440f54848b195134",
        "date": "2026-10-25",
        "notes": "mapTokens not supported (added in Map slice 1.5)",
    },
    "E7": {
        "commit": "8c5e4314b9a5f101da07d4fed2b08816d736d15e",
        "date": "2026-10-24",
        "notes": "activeMapRegister, mapGridRegister, mapTokens not supported (added in Map slices)",
    },
    "E6": {
        "commit": "4f5aa1740788107f879ef260ac34f82bf326473e",
        "date": "2026-10-23",
        "notes": "activeMapRegister, mapGridRegister, mapTokens not supported (added in Map slices)",
    },
    "E5": {
        "commit": "e458af9d0968309692be843ee6d905c29ff7d941",
        "date": "2026-10-20",
        "notes": "recordVersion not supported (added in Pass 11); activeMapRegister, mapGridRegister, mapTokens not supported (added in Map slices)",
    },
    "E4": {
        "commit": "aae3185fe695c160c5851e8a4bda1bfb9d4097c8",
        "date": "2026-10-14",
        "notes": "memberPurses not supported (added in Pass 7); recordVersion and map fields not supported",
    },
    "E3": {
        "commit": "4e221cc5830710cb2199edbbd27a47623635fea7",
        "date": "2026-10-11",
        "notes": "nameRegister not supported (added in Pass 4.2); memberPurses, recordVersion and map fields not supported",
    },
    "E2": {
        "commit": "355e312ecc33b2bfe52238760f36931837d34c4c",
        "date": "2026-10-10",
        "notes": "partyRoster_crdt and pinnedRules_crdt not supported (added in Pass 4.0); nameRegister, memberPurses, recordVersion, and map fields not supported",
    },
    "E1": {
        "commit": "afeb6de04ec9327e38081d4dd3cb2a216bff9bb8",
        "date": "2026-09-30",
        "notes": "entityLink tombstones not supported (plain list); purse PN-counters not supported (scalar coins); CRDT sets for roster/pinned rules not supported; nameRegister, memberPurses, recordVersion, and map fields not supported",
    },
}

def generate_test_dart(era: str) -> str:
    info = ERAS[era]
    commit = info["commit"]
    notes = info["notes"]

    # Era specific parameters
    has_map_tokens = era == "E9"
    has_map_grid = era in ("E8", "E9")
    has_member_purses = era in ("E5", "E6", "E7", "E8", "E9")
    has_name_register = era in ("E4", "E5", "E6", "E7", "E8", "E9")
    has_crdt_roster = era in ("E3", "E4", "E5", "E6", "E7", "E8", "E9")
    has_pn_purse = era in ("E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9")
    has_crdt_links = era in ("E4", "E5", "E6", "E7", "E8", "E9")
    uses_repo_identity = era != "E1"
    is_e1 = era == "E1"
    is_e2 = era == "E2"
    is_e3 = era == "E3"
    
    is_before_e6 = era in ("E1", "E2", "E3", "E4", "E5")
    if is_before_e6:
        meta_line = "      Hive.openBox<dynamic>(AppDatabaseService.boxMetadata),\n" if era != "E1" else ""
        db_setup = f"""    Hive.init(tempDir.path);
    await Future.wait([
      Hive.openBox<dynamic>(AppDatabaseService.boxCharacters),
      Hive.openBox<dynamic>(AppDatabaseService.boxCampaignProfiles),
      Hive.openBox<dynamic>(AppDatabaseService.boxHomebrew),
      Hive.openBox<dynamic>(AppDatabaseService.boxHomebrewRaw),
{meta_line}    ]);
    final db = AppDatabaseService.instance;"""
    else:
        db_setup = """    final db = AppDatabaseService.custom(
      hiveInit: () async => Hive.init(tempDir.path),
      hiveBoxOpener: Hive.openBox<dynamic>,
    );
    AppDatabaseService.instance = db;
    await db.init();"""

    edition_expr_a = "const RulesetIdentifier('generic_tabletop')" if is_e1 else "RulesetEdition.v2024"
    edition_str_a = "generic_tabletop" if is_e1 else "v2024"

    # Inventory item constructor: in older versions const InventoryItemInstance, in newer InventoryItemInstance.constant
    inv_ctor = "InventoryItemInstance" if is_e1 else "InventoryItemInstance.constant"
    ref_ctor = "const EntityReference" if is_e1 else "EntityReference.empty"

    if is_e1:
        clock_setup = """    final fixedDateTime = DateTime.utc(2026, 1, 1, 12, 0, 0);
    const ts1 = HybridLogicalClock(physicalTime: 1767268800000, logicalCounter: 0, nodeId: 'e1_writer');
    const ts2 = HybridLogicalClock(physicalTime: 1767268800000, logicalCounter: 1, nodeId: 'e1_writer');
    const ts3 = HybridLogicalClock(physicalTime: 1767268800000, logicalCounter: 2, nodeId: 'e1_writer');
    const ts4 = HybridLogicalClock(physicalTime: 1767268800000, logicalCounter: 3, nodeId: 'e1_writer');
    const ts5 = HybridLogicalClock(physicalTime: 1767268800000, logicalCounter: 4, nodeId: 'e1_writer');"""
        di_setup = "    sl.reset();"
    else:
        clock_setup = f"""    final fixedDateTime = DateTime.utc(2026, 1, 1, 12, 0, 0);
    final replicaId = ReplicaId('{era.lower()}_writer');
    final clock = StatefulHlcClock(
      replicaId: replicaId,
      timeProvider: () => fixedDateTime.millisecondsSinceEpoch,
    );"""
        di_setup = """    sl.reset();
    sl.registerSingleton<ReplicaId>(replicaId);
    sl.registerSingleton<StatefulHlcClock>(clock);"""

    code = f"""// Generator for Era {era} (Commit: {commit})
// Command: flutter test test/fixtures/legacy_storage/{era}/writer_test.dart
// Scenario expression limitations: {notes}

import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/vtt_engine_core.dart'
    hide EntityType, Character, CharacterResourcePool, InventoryItemInstance;
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/di/injection_container.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_campaign_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/repositories/local_character_repository.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/minion_instance.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/party/campaign_membership.dart';
import 'package:dangerously_nerdy_5e_toolkit/providers/settings_provider.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/party/campaign_registry_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_backup_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/dm_backup_service.dart';

dynamic sortJson(dynamic object) {{
  if (object is Map) {{
    final sortedMap = SplayTreeMap<String, dynamic>();
    for (final entry in object.entries) {{
      sortedMap[entry.key.toString()] = sortJson(entry.value);
    }}
    return sortedMap;
  }}
  if (object is List) {{
    return object.map(sortJson).toList();
  }}
  return object;
}}

String canonicalJson(dynamic object) {{
  final sorted = sortJson(object);
  return const JsonEncoder.withIndent('  ').convert(sorted);
}}

void main() {{
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Generate Era {era} Fixture and Facts', () async {{
{clock_setup}

    final tempDir = await Directory.systemTemp.createTemp('{era.lower()}_fixture_gen_');
    SharedPreferences.setMockInitialValues({{}});
    final prefs = await SharedPreferences.getInstance();

{db_setup}

{di_setup}

    final charRepo = LocalCharacterRepository(db: db);
    final campRepo = LocalCampaignRepository(
      db: db,
      characterRepo: charRepo,
      {"replicaId: replicaId, clock: clock," if uses_repo_identity else ""}
    );
    final regService = CampaignRegistryService();
    final settingsProvider = SettingsProvider(autoLoad: false);

    // 1. Build Characters
    const charFighter = Character(
      id: EntityId(slug: 'char_fighter', ruleset: RulesetVersion.v2024),
      name: 'Fighter One',
      speciesRef: {ref_ctor}(
        refType: EntityType.species,
        slug: 'human',
        displayName: 'Human',
      ),
      progression: CharacterProgression(classes: [
        ClassLevelProgression(
          classRef: {ref_ctor}(
            refType: EntityType.classDefinition,
            slug: 'fighter',
            displayName: 'Fighter',
          ),
          level: 1,
          hitDie: 'd10',
          isStartingClass: true,
        ),
      ]),
      baseScores: AbilityScores.standardArray(),
      resources: CharacterResourcePool(
        vitals: EntityVitals(
          currentHp: 8,
          maxHp: 12,
          temporaryHp: 0,
          isDowned: false,
          isDead: false,
        ),
        currentHp: 8,
      ),
      customProperties: const {{'maxHp': 12}},
      inventory: [
        {inv_ctor}(
          instanceId: 'item_chain_mail',
          itemRef: {ref_ctor}(
            refType: EntityType.equipment,
            slug: 'chain_mail',
            displayName: 'Chain Mail',
          ),
          isEquipped: true,
          quantity: 1,
        ),
        {inv_ctor}(
          instanceId: 'item_longsword',
          itemRef: {ref_ctor}(
            refType: EntityType.equipment,
            slug: 'longsword',
            displayName: 'Longsword',
          ),
          isEquipped: false,
          quantity: 1,
        ),
        {inv_ctor}(
          instanceId: 'item_shield',
          itemRef: {ref_ctor}(
            refType: EntityType.equipment,
            slug: 'shield',
            displayName: 'Shield',
          ),
          isEquipped: false,
          quantity: 1,
        ),
      ],
    );

    const charWizardCleric = Character(
      id: EntityId(slug: 'char_wizard_cleric', ruleset: RulesetVersion.v2024),
      name: 'Mage Cleric',
      speciesRef: {ref_ctor}(
        refType: EntityType.species,
        slug: 'elf',
        displayName: 'Elf',
      ),
      progression: CharacterProgression(classes: [
        ClassLevelProgression(
          classRef: {ref_ctor}(
            refType: EntityType.classDefinition,
            slug: 'wizard',
            displayName: 'Wizard',
          ),
          level: 2,
          hitDie: 'd6',
          isStartingClass: true,
        ),
        ClassLevelProgression(
          classRef: {ref_ctor}(
            refType: EntityType.classDefinition,
            slug: 'cleric',
            displayName: 'Cleric',
          ),
          level: 1,
          hitDie: 'd8',
          isStartingClass: false,
        ),
      ]),
      baseScores: AbilityScores.standardArray(),
      resources: CharacterResourcePool(
        vitals: EntityVitals(
          currentHp: 16,
          maxHp: 20,
          temporaryHp: 0,
          isDowned: false,
          isDead: false,
        ),
        currentHp: 16,
      ),
      customProperties: const {{'maxHp': 20}},
      spellsKnown: [
        {ref_ctor}(
          refType: EntityType.spell,
          slug: 'magic_missile',
          displayName: 'Magic Missile',
        ),
        {ref_ctor}(
          refType: EntityType.spell,
          slug: 'cure_wounds',
          displayName: 'Cure Wounds',
        ),
      ],
      spellsPrepared: [
        {ref_ctor}(
          refType: EntityType.spell,
          slug: 'magic_missile',
          displayName: 'Magic Missile',
        ),
        {ref_ctor}(
          refType: EntityType.spell,
          slug: 'cure_wounds',
          displayName: 'Cure Wounds',
        ),
      ],
    );

    // Save characters
    await charRepo.saveRoster([charFighter, charWizardCleric]);
    await charRepo.saveActiveCharacterId('char_wizard_cleric');

    // 2. Build Campaign A
    {"final ts1 = clock.nextTimestamp();\n    final ts2 = clock.nextTimestamp();\n    final ts3 = clock.nextTimestamp();\n    final ts4 = clock.nextTimestamp();\n    final ts5 = clock.nextTimestamp();" if not is_e1 else ""}
"""

    if is_e1 or is_e2 or is_e3:
        code += f"""
    final linkLive = RoomEntityLink(
      entityId: 'item_potion_healing',
      refType: 'equipment',
      displayName: 'Potion of Healing',
    );

    final minion = MinionInstance(
      id: 'minion_1',
      name: 'Animated Dagger',
      size: EntitySize.tiny,
      currentHp: 20,
      maxHp: 20,
    );

    final minionsSet = const CrdtOrSet<dynamic>.empty().addBatch([
      (id: 'minion_1', item: minion, timestamp: ts4),
    ]);

    final roomStateA = RoomNodeState(
      roomId: 'room_LEGACYA',
      roomCode: 'LEGA01',
      title: 'Legacy Room A',
      description: '',
      entityLinks: [linkLive],
      activeMinions: minionsSet,
    );

    final eventA = PartyEvent(
      id: 'event_1',
      roomCode: 'LEGA01',
      type: 'coinDeposit',
      playerName: 'Fighter One',
      details: 'Found 50 gp and 7 sp',
      timestamp: fixedDateTime,
    );
"""
        if is_e1:
            code += f"""
    final purseA = const PartyPurse(gp: 50, sp: 7);
    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      edition: const RulesetIdentifier('generic_tabletop'),
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyCharacterIds: const ['char_fighter', 'char_wizard_cleric'],
      pinnedRuleIds: const {{'cover', 'resting'}},
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      edition: const RulesetIdentifier('v2014'),
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        title: 'Legacy Campaign B',
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
        elif is_e2:
            code += f"""
    final purseA = const PartyPurse.empty()
        .modifyDenomination('gp', 50, replicaId: replicaId)
        .modifyDenomination('sp', 7, replicaId: replicaId);

    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyCharacterIds: const ['char_fighter', 'char_wizard_cleric'],
      pinnedRuleIds: const {{'cover', 'resting'}},
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        title: 'Legacy Campaign B',
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
        else: # E3
            code += f"""
    final purseA = const PartyPurse.empty()
        .modifyDenomination('gp', 50, replicaId: replicaId)
        .modifyDenomination('sp', 7, replicaId: replicaId);

    var rosterSet = const CrdtOrSet<String>.empty()
        .add('char_fighter', 'char_fighter', ts1)
        .add('char_wizard_cleric', 'char_wizard_cleric', ts2);

    var rulesSet = const CrdtOrSet<String>.empty()
        .add('cover', 'cover', ts1)
        .add('resting', 'resting', ts2);

    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyRoster: rosterSet,
      pinnedRules: rulesSet,
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        title: 'Legacy Campaign B',
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
    else: # E3 .. E8
        code += f"""
    final linkLive = RoomEntityLink(
      entityId: 'item_potion_healing',
      refType: 'equipment',
      displayNameRegister: CrdtLwwRegister(
        value: 'Potion of Healing',
        timestamp: ts1,
      ),
      notesRegister: CrdtLwwRegister(
        value: null,
        timestamp: ts1,
      ),
      incarnationTimestamp: ts1,
    );

    final linkRemoved = RoomEntityLink(
      entityId: 'item_potion_invisibility',
      refType: 'equipment',
      displayNameRegister: CrdtLwwRegister(
        value: 'Potion of Invisibility',
        timestamp: ts2,
      ),
      notesRegister: CrdtLwwRegister(
        value: null,
        timestamp: ts2,
      ),
      incarnationTimestamp: ts2,
    );

    var linksSet = const EntityLinkCrdtSet.empty()
        .add(linkLive.entityId, linkLive, ts1)
        .add(linkRemoved.entityId, linkRemoved, ts2)
        .remove(linkRemoved.entityId, ts3);

    final minion = MinionInstance(
      id: 'minion_1',
      name: 'Animated Dagger',
      size: EntitySize.tiny,
      currentHp: 20,
      maxHp: 20,
    );

    final minionsSet = const CrdtOrSet<dynamic>.empty().addBatch([
      (id: 'minion_1', item: minion, timestamp: ts4),
    ]);

    final roomStateA = RoomNodeState(
      roomId: 'room_LEGACYA',
      roomCode: 'LEGA01',
      titleRegister: CrdtLwwRegister(value: 'Legacy Room A', timestamp: ts1),
      descriptionRegister: CrdtLwwRegister(value: '', timestamp: ts1),
      entityLinksCrdt: linksSet,
      activeMinions: minionsSet,
    );

    final rosterSetA = const CrdtOrSet<String>.empty().addBatch([
      (id: 'char_fighter', item: 'char_fighter', timestamp: ts1),
      (id: 'char_wizard_cleric', item: 'char_wizard_cleric', timestamp: ts2),
    ]);

    final pinnedRulesSetA = const CrdtOrSet<String>.empty().addBatch([
      (id: 'cover', item: 'cover', timestamp: ts1),
      (id: 'resting', item: 'resting', timestamp: ts2),
    ]);

    final purseA = const PartyPurse.empty()
        .modifyDenomination('gp', 50, replicaId: replicaId)
        .modifyDenomination('sp', 7, replicaId: replicaId);

    final eventA = PartyEvent(
      id: 'event_1',
      roomCode: 'LEGA01',
      type: 'coinDeposit',
      playerName: 'Fighter One',
      details: 'Found 50 gp and 7 sp',
      timestamp: fixedDateTime,
    );
"""
        if is_e3:
            code += f"""
    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyRoster: rosterSetA,
      pinnedRules: pinnedRulesSetA,
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        titleRegister: CrdtLwwRegister(value: 'Legacy Campaign B', timestamp: ts1),
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
        elif era == "E4":
            code += f"""
    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign A',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyRoster: rosterSetA,
      partyCharacterIds: const ['char_fighter', 'char_wizard_cleric'],
      pinnedRules: pinnedRulesSetA,
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign B',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        titleRegister: CrdtLwwRegister(value: 'Legacy Campaign B', timestamp: ts1),
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
        elif era in ("E5", "E6", "E7"):
            code += f"""
    final memberPurseFighter = const PartyPurse.empty()
        .modifyDenomination('gp', 12, replicaId: replicaId);

    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign A',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyRoster: rosterSetA,
      partyCharacterIds: const ['char_fighter', 'char_wizard_cleric'],
      pinnedRules: pinnedRulesSetA,
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      partyPurse: purseA,
      memberPurses: {{'char_fighter': memberPurseFighter}},
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign B',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        titleRegister: CrdtLwwRegister(value: 'Legacy Campaign B', timestamp: ts1),
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""
        elif era in ("E8", "E9"):
            tokens_code = """
    final tokenId = 'tok_' + '1' * 32;
    final token = MapToken(
      id: tokenId,
      mapSha256Hex: mapSha,
      kind: MapTokenKind.character,
      refId: 'char_fighter',
      label: 'FTR',
    );
    final mapTokens = const CrdtOrSet<MapToken>.empty().addBatch([
      (id: tokenId, item: token, timestamp: ts5),
    ]);
    final tokenCell = MapTokenCell(col: 1, row: 1);
    final mapTokenCells = const CrdtOrSet<MapTokenCell>.empty().addBatch([
      (id: tokenId, item: tokenCell, timestamp: ts5),
    ]);
""" if era == "E9" else ""
            tokens_field = """
      mapTokens: mapTokens,
      mapTokenCells: mapTokenCells,
""" if era == "E9" else ""
            code += f"""
    final memberPurseFighter = const PartyPurse.empty()
        .modifyDenomination('gp', 12, replicaId: replicaId);

    final mapSha = 'a' * 64;
    final mapRef = BlobRef(
      sha256Hex: mapSha,
      byteSize: 12345,
      width: 800,
      height: 600,
      format: BlobFormat.webp,
    );
    final grid = MapGrid(
      mapSha256Hex: mapSha,
      cellCentiPx: 5000,
      offsetXCentiPx: 0,
      offsetYCentiPx: 0,
      feetPerCell: 5,
      visible: true,
    );
{tokens_code}
    final campaignA = CampaignProfile.raw(
      id: 'campaign_LEGACYA',
      name: 'Legacy Campaign A',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign A',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2024,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: roomStateA,
      partyRoster: rosterSetA,
      partyCharacterIds: const ['char_fighter', 'char_wizard_cleric'],
      pinnedRules: pinnedRulesSetA,
      notesRegister: CrdtLwwRegister(
        value: 'Notes for A',
        timestamp: ts1,
      ),
      activeMapRegister: CrdtLwwRegister(
        value: mapRef,
        timestamp: ts5,
      ),
      mapGridRegister: CrdtLwwRegister(
        value: grid,
        timestamp: ts5,
      ),
{tokens_field}
      partyPurse: purseA,
      memberPurses: {{'char_fighter': memberPurseFighter}},
      changeLog: [eventA],
    );

    final campaignB = CampaignProfile.raw(
      id: 'campaign_LEGACYB',
      name: 'Legacy Campaign B',
      nameRegister: CrdtLwwRegister(
        value: 'Legacy Campaign B',
        timestamp: ts1,
      ),
      edition: RulesetEdition.v2014,
      createdAt: fixedDateTime,
      lastPlayedAt: fixedDateTime,
      roomState: RoomNodeState(
        roomId: 'room_LEGACYB',
        roomCode: 'LEGB02',
        titleRegister: CrdtLwwRegister(value: 'Legacy Campaign B', timestamp: ts1),
      ),
      notesRegister: CrdtLwwRegister(value: '', timestamp: ts1),
    );
"""

    code += f"""
    // Save campaigns
    await campRepo.saveProfileImmediate(campaignA);
    await campRepo.saveProfileImmediate(campaignB);
    await campRepo.setActiveProfileId('campaign_LEGACYA');

    // 4. Registry Membership
    await regService.saveMembership(
      CampaignMembership(
        roomCode: 'LEGC03',
        campaignName: 'Unmapped Adopted Campaign',
        role: CampaignRole.player,
        characterId: 'char_fighter',
        lastPlayed: fixedDateTime,
      ),
    );

    // 5. Settings
    const appSettings = AppSettings(
      themeMode: ThemeMode.dark,
      fantasyAccent: FantasyAccent.celestialAmber,
      hapticLevel: HapticFeedbackLevel.light,
      rulesEdition: DmRulesEdition.v2024,
    );
    await settingsProvider.updateSettings(appSettings);

    // 6. Backups
    final appBackupJson = await AppBackupService().exportFullBackupJson(appSettings);
    final dmProfileJson = DmBackupService().exportProfileJson(campaignA);

    // 7. Dump Storage
    final boxesMap = <String, dynamic>{{}};
    for (final boxName in [
      AppDatabaseService.boxCharacters,
      AppDatabaseService.boxCampaignProfiles,
      AppDatabaseService.boxHomebrew,
      AppDatabaseService.boxHomebrewRaw,
      {"AppDatabaseService.boxMetadata," if era != "E1" else ""}
    ]) {{
      final boxData = <String, dynamic>{{}};
      for (final key in db.getKeys(boxName)) {{
        boxData[key] = db.get(boxName, key);
      }}
      boxesMap[boxName] = boxData;
    }}

    final prefsMap = <String, dynamic>{{}};
    for (final key in prefs.getKeys()) {{
      final dynamic val = prefs.get(key);
      String type = 's';
      if (val is int) {{
        type = 'i';
      }} else if (val is bool) {{
        type = 'b';
      }} else if (val is double) {{
        type = 'd';
      }} else if (val is List<String>) {{
        type = 'sl';
      }} else if (val is List) {{
        type = 'sl';
      }}
      prefsMap[key] = {{
        't': type,
        'v': val,
      }};
    }}

    final storageJsonMap = {{
      'era': '{era}',
      'commit': '{commit}',
      'boxes': boxesMap,
      'prefs': prefsMap,
    }};

    // 8. Read back facts through era's own code
    final loadedProfiles = await campRepo.loadAllProfiles();
    final sortedProfiles = List.of(loadedProfiles)..sort((a, b) => a.id.compareTo(b.id));

    final campaignsList = <Map<String, dynamic>>[];
    for (final p in sortedProfiles) {{
      final activeMinions = {"p.roomState.activeMinions.activeValues.map((m) => m.id.toString()).toList()..sort()" if has_crdt_roster or is_e1 or is_e2 else "[]"};
      final liveEntityLinks = {"p.roomState.entityLinksCrdt.items.values.map((l) => l.value.entityId).toList()..sort()" if has_crdt_links else "p.roomState.entityLinks.map((l) => l.entityId).toList()..sort()"};
      
      final memberPursesMap = SplayTreeMap<String, Map<String, int>>();
      {"for (final entry in p.memberPurses.entries) { memberPursesMap[entry.key] = {'cp': entry.value.getBalance('cp'), 'ep': entry.value.getBalance('ep'), 'gp': entry.value.getBalance('gp'), 'pp': entry.value.getBalance('pp'), 'sp': entry.value.getBalance('sp')}; }" if has_member_purses else ""}

      final partyPurse = {{
        'cp': p.partyPurse.getBalance('cp'),
        'ep': p.partyPurse.getBalance('ep'),
        'gp': p.partyPurse.getBalance('gp'),
        'pp': p.partyPurse.getBalance('pp'),
        'sp': p.partyPurse.getBalance('sp'),
      }};

      final partyRosterIds = {"p.partyRoster.activeValues.toList()..sort()" if has_crdt_roster else "List.of(p.partyCharacterIds)..sort()"};
      final pinnedRuleIds = {"p.pinnedRules.activeValues.toList()..sort()" if has_crdt_roster else "p.pinnedRuleIds.toList()..sort()"};

      campaignsList.add({{
        'activeMapSha256': {"p.activeMapRegister.value?.sha256Hex" if has_map_grid else "null"},
        'activeMinionIds': activeMinions,
        'changeLogCount': p.changeLog.length,
        'edition': p.id == 'campaign_LEGACYA' ? '{edition_str_a}' : 'v2014',
        'grid': {"p.mapGridRegister.value?.toMap()" if has_map_grid else "null"},
        'id': p.id,
        'liveEntityLinkIds': liveEntityLinks,
        'memberPurses': memberPursesMap,
        'name': p.name,
        'notes': p.notesMarkdown,
        'partyPurse': partyPurse,
        'partyRosterIds': partyRosterIds,
        'pinnedRuleIds': pinnedRuleIds,
        'roomCode': p.roomState.roomCode,
        'tokenIds': {"p.mapTokens.activeValues.map((t) => t.id).toList()..sort()" if has_map_tokens else "<String>[]"},
      }});
    }}

    final loadedCharacters = await charRepo.loadCharacters();
    final sortedCharacters = List.of(loadedCharacters)..sort((a, b) => a.id.slug.compareTo(b.id.slug));

    final charactersList = <Map<String, dynamic>>[];
    for (final char in sortedCharacters) {{
      final classes = char.progression.classes
          .map((c) => {{'id': c.classRef.slug, 'level': c.level}})
          .toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

      final equipped = char.inventory
          .where((i) => i.isEquipped)
          .map((i) => i.itemRef.slug)
          .toList()
        ..sort();

      final inventory = char.inventory
          .map((i) => {{'id': i.itemRef.slug, 'quantity': i.quantity}})
          .toList()
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

      final spellsKnown = char.spellsKnown.map((s) => s.slug).toList()..sort();
      final spellsPrepared = char.spellsPrepared.map((s) => s.slug).toList()..sort();

      charactersList.add({{
        'classes': classes,
        'currentHp': char.resources.currentHp,
        'equippedItemIds': equipped,
        'id': char.id.slug,
        'inventory': inventory,
        'knownSpellIds': spellsKnown,
        'maxHp': char.evaluatedMaxHp,
        'name': char.name,
        'preparedSpellIds': spellsPrepared,
      }});
    }}

    final memberships = await regService.loadMemberships();
    final sortedMemberships = List.of(memberships)..sort((a, b) => a.roomCode.compareTo(b.roomCode));

    final registryList = sortedMemberships
        .map((m) => {{
              'characterId': m.characterId,
              'role': m.role.name,
              'roomCode': m.roomCode,
            }})
        .toList();

    final settings = SettingsProvider.hydrateFromPrefs(prefs);
    final settingsMap = {{
      'accent': settings.fantasyAccent.name,
      'haptic': settings.hapticLevel.name,
      'rulesEdition': settings.rulesEdition.name,
      'theme': settings.themeMode.name,
    }};

    final facts = {{
      'activeCampaignId': campRepo.activeProfileId,
      'activeCharacterId': await charRepo.loadActiveCharacterId(),
      'campaigns': campaignsList,
      'characters': charactersList,
      'registryMemberships': registryList,
      'settings': settingsMap,
    }};

    // Write outputs to target directory
    final outDir = Directory('{REPO_DIR}/test/fixtures/legacy_storage/{era}');
    await outDir.create(recursive: true);

    await File('${{outDir.path}}/storage.json').writeAsString(
      canonicalJson(storageJsonMap),
    );
    await File('${{outDir.path}}/app_backup.json').writeAsString(appBackupJson);
    await File('${{outDir.path}}/dm_profile.json').writeAsString(dmProfileJson);
    await File('${{outDir.path}}/facts.json').writeAsString(
      canonicalJson(facts),
    );

    // Clean up temp
    {"await Hive.close();" if is_before_e6 else "await db.close();"}
    await tempDir.delete(recursive: true);
  }});
}}
"""
    return code

def run_era(era: str, custom_dest: str = None):
    info = ERAS[era]
    commit = info["commit"]
    print(f"=== Generating {era} at commit {commit} ===")

    dest_dir = custom_dest or os.path.join(REPO_DIR, "test/fixtures/legacy_storage", era)
    os.makedirs(dest_dir, exist_ok=True)

    tmp_wt = tempfile.mkdtemp(prefix=f"legacy_{era}_")
    try:
        subprocess.check_call(["git", "worktree", "add", "--detach", tmp_wt, commit], cwd=REPO_DIR)
        print(f"Worktree created at {tmp_wt}")
        subprocess.check_call(["flutter", "pub", "get"], cwd=tmp_wt)

        test_content = generate_test_dart(era)
        if custom_dest:
            test_content = test_content.replace(
                f"final outDir = Directory('{REPO_DIR}/test/fixtures/legacy_storage/{era}');",
                f"final outDir = Directory('{custom_dest}');"
            )
        test_path = os.path.join(tmp_wt, "test", "writer_test.dart")
        with open(test_path, "w") as f:
            f.write(test_content)

        subprocess.check_call(["flutter", "test", "test/writer_test.dart"], cwd=tmp_wt)

        # Copy generator source to destination as .txt
        with open(os.path.join(dest_dir, "writer_test.dart.txt"), "w") as f:
            f.write(test_content)

        print(f"Era {era} generated successfully!")
    finally:
        subprocess.call(["git", "worktree", "remove", "--force", tmp_wt], cwd=REPO_DIR)
        shutil.rmtree(tmp_wt, ignore_errors=True)

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else None
    dest = sys.argv[2] if len(sys.argv) > 2 else None
    if target:
        run_era(target, dest)
    else:
        for era in ["E9", "E8", "E7", "E6", "E5", "E4", "E3", "E2", "E1"]:
            run_era(era)
