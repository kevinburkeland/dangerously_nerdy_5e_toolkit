import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/persistence/app_database_service.dart';
import 'legacy_fixture_support.dart';

/// Builders for derived legacy fixtures (shapes no commit in history ever wrote).
/// Each derivation takes a written fixture and applies deterministic structural shifts.
class LegacyFixtureDerivations {
  /// DP (SharedPreferences era):
  /// Covers inventory rows B2, B3, B4, B6.
  /// Moves E1's campaign index, campaign records, active id, and character roster
  /// from the Hive boxes into SharedPreferences under the same keys, leaving Hive boxes empty.
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDP({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final prefs = storage['prefs'] as Map<String, dynamic>;

    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>? ??
            {};
    final charBox =
        boxes[AppDatabaseService.boxCharacters] as Map<String, dynamic>? ?? {};

    // 1. Move campaign index to prefs
    final campIndex = campBox['dn5e_campaign_profile_index'];
    if (campIndex is List) {
      prefs['dn5e_campaign_profile_index'] = {
        't': 'sl',
        'v': campIndex.map((e) => e.toString()).toList(),
      };
    }

    // 2. Move campaign records to prefs
    for (final entry in campBox.entries) {
      if (entry.key.startsWith('dn5e_campaign_profile_') &&
          entry.key != 'dn5e_campaign_profile_index') {
        prefs[entry.key] = {
          't': 's',
          'v': entry.value.toString(),
        };
      }
    }

    // 3. Move active campaign ID to prefs
    final activeCampId = campBox['dn5e_campaign_active_id'];
    if (activeCampId != null) {
      prefs['dn5e_campaign_active_id'] = {
        't': 's',
        'v': activeCampId.toString(),
      };
    }

    // 4. Move character roster to prefs as JSON string
    final roster = charBox['saved_characters_roster_v1'];
    if (roster != null) {
      prefs['saved_characters_roster_v1'] = {
        't': 's',
        'v': roster is String ? roster : json.encode(roster),
      };
    }

    // 5. Move active character ID to prefs
    final activeCharId = charBox['saved_active_character_id_v1'];
    if (activeCharId != null) {
      prefs['saved_active_character_id_v1'] = {
        't': 's',
        'v': activeCharId.toString(),
      };
    }

    // Clear the Hive boxes
    boxes[AppDatabaseService.boxCampaignProfiles] = <String, dynamic>{};
    boxes[AppDatabaseService.boxCharacters] = <String, dynamic>{};

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DE (embedded characters):
  /// Covers inventory rows B8, B15.
  /// Embeds Character 1 and Character 2 maps into Campaign A's partyRoster
  /// and empties the character roster box.
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDE({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;
    final charBox =
        boxes[AppDatabaseService.boxCharacters] as Map<String, dynamic>;

    final rawRoster = charBox['saved_characters_roster_v1'];
    final List<dynamic> characterMaps;
    if (rawRoster is List) {
      characterMaps = List<dynamic>.from(rawRoster);
    } else if (rawRoster is String) {
      characterMaps = json.decode(rawRoster) as List<dynamic>;
    } else {
      characterMaps = [];
    }

    // Embed characters in campaign A
    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;

    campAMap['partyRoster'] = characterMaps;
    campAMap.remove('partyCharacterIds');
    campAMap.remove('partyRoster_crdt');
    campBox[campAKey] = json.encode(campAMap);

    // Empty character roster box
    charBox['saved_characters_roster_v1'] = <dynamic>[];

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DM (root minions):
  /// Covers inventory row B16.
  /// Moves minion from Campaign A's roomState.activeMinions to root activeMinions list.
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDM({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;
    final roomState =
        Map<String, dynamic>.from(campAMap['roomState'] as Map? ?? {});

    final dynamic minions =
        roomState['activeMinions'] ?? roomState['activeMinions_crdt'];
    final minionList = <dynamic>[];

    if (minions is List) {
      minionList.addAll(minions);
    } else if (minions is Map) {
      final items = minions['items'];
      if (items is Map) {
        for (final v in items.values) {
          if (v is Map && v['value'] != null) {
            minionList.add(v['value']);
          } else {
            minionList.add(v);
          }
        }
      }
    }

    roomState.remove('activeMinions');
    roomState.remove('activeMinions_crdt');
    campAMap['roomState'] = roomState;
    campAMap['activeMinions'] = minionList;

    campBox[campAKey] = json.encode(campAMap);

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DS (v1 settings):
  /// Covers inventory row B24.
  /// Rewrites v2 string settings keys as legacy v1 integer enum indices.
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDS({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final prefs = storage['prefs'] as Map<String, dynamic>;

    int themeIndex = 2; // dark
    int accentIndex = 1; // ember / amber
    int hapticIndex = 1; // light
    int editionIndex = 0; // v2024

    final v2Theme = prefs.remove('setting_theme_mode_v2');
    if (v2Theme != null && v2Theme['v'] != null) {
      final idx = ThemeMode.values
          .indexWhere((e) => e.name == v2Theme['v'].toString());
      if (idx >= 0) themeIndex = idx;
    }

    final v2Accent = prefs.remove('setting_fantasy_accent_v2');
    if (v2Accent != null && v2Accent['v'] != null) {
      final idx = FantasyAccent.values
          .indexWhere((e) => e.name == v2Accent['v'].toString());
      if (idx >= 0) accentIndex = idx;
    }

    final v2Haptic = prefs.remove('setting_haptic_level_v2');
    if (v2Haptic != null && v2Haptic['v'] != null) {
      final idx = HapticFeedbackLevel.values
          .indexWhere((e) => e.name == v2Haptic['v'].toString());
      if (idx >= 0) hapticIndex = idx;
    }

    final v2Edition = prefs.remove('setting_rules_edition_v2');
    if (v2Edition != null && v2Edition['v'] != null) {
      final idx = DmRulesEdition.values
          .indexWhere((e) => e.name == v2Edition['v'].toString());
      if (idx >= 0) editionIndex = idx;
    }

    prefs['setting_theme_mode'] = {'t': 'i', 'v': themeIndex};
    prefs['setting_fantasy_accent'] = {'t': 'i', 'v': accentIndex};
    prefs['setting_haptic_level'] = {'t': 'i', 'v': hapticIndex};
    prefs['setting_rules_edition'] = {'t': 'i', 'v': editionIndex};
    prefs['app_storage_schema_version'] = {'t': 'i', 'v': 1};

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DR (records the app must keep, not load):
  /// Covers inventory row B5.
  /// Rewrites E6's campaign A with recordVersion: 2, and adds one record whose value is not valid JSON.
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDR({
    required Map<String, dynamic> e6Storage,
    required Map<String, dynamic> e6Facts,
  }) {
    final storage = json.decode(json.encode(e6Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;

    campAMap['recordVersion'] = 2;
    campBox[campAKey] = json.encode(campAMap);

    // Corrupted record
    const corruptId = 'corrupt_record_raw';
    const corruptKey = 'dn5e_campaign_profile_$corruptId';
    campBox[corruptKey] = '{not_valid_json: true, malformed;';

    final indexList =
        (campBox['dn5e_campaign_profile_index'] as List? ?? []).toList();
    if (!indexList.contains(corruptId)) {
      indexList.add(corruptId);
    }
    campBox['dn5e_campaign_profile_index'] = indexList;

    // Facts for DR: Campaign A is excluded from loaded facts, Campaign B remains
    final facts = json.decode(json.encode(e6Facts)) as Map<String, dynamic>;
    final campaigns = facts['campaigns'] as List<dynamic>;
    campaigns.removeWhere((c) => (c as Map)['id'] == 'campaign_LEGACYA');

    // activeCampaignId falls back to campaign_LEGACYB
    facts['activeCampaignId'] = 'campaign_LEGACYB';

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(facts) as Map<String, dynamic>,
    );
  }

  /// DB7 (character roster stored as raw JSON String in boxCharacters):
  /// Covers inventory row B7 (`lib/infrastructure/repositories/local_character_repository.dart`:
  /// `LocalCharacterRepository.loadCharacters` line 30 and `_loadRawPersistedRoster` line 97).
  /// No writer in repository history ever wrote a String to `boxCharacters` (`fd74268` already wrote a `List`).
  /// Command: `git log -S "saved_characters_roster_v1" --oneline -- lib/`
  /// Output:
  ///   `fd74268 feat(app): relaunch 5e-toolkit with modularized domain core and clean legal compliance`
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDB7({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final charBox =
        boxes[AppDatabaseService.boxCharacters] as Map<String, dynamic>;

    final roster = charBox['saved_characters_roster_v1'];
    if (roster is List) {
      charBox['saved_characters_roster_v1'] = json.encode(roster);
    }

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DT (missing createdAt and lastPlayedAt on Campaign A):
  /// Covers inventory rows B11 and B12 (`lib/infrastructure/dtos/campaign_profile_dto.dart`:
  /// `CampaignProfileDto.fromMap` lines 398-400 and 413-415).
  /// Characterization default: missing `createdAt` defaults to `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String()` (line 399)
  /// and missing `lastPlayedAt` defaults to `createdAtStr` (line 414).
  /// No writer in repository history ever omitted `createdAt` or `lastPlayedAt`.
  /// Command: `git log -S "createdAt" --oneline -- lib/infrastructure/dtos/campaign_profile_dto.dart`
  /// Output:
  ///   `7d803b2 feat(party): Pass 10 placeholder production paths, Source Bar M, and doc updates`
  ///   `df02baa feat(party-state): implement Pass 7.1 party ledger synchronization and invariants`
  ///   `a7fba17 feat(party-state): implement Pass 7 unified party state ownership`
  ///   `80f1eab feat(storage): consolidate campaign records to single owner ICampaignRepository (Pass 5.1)`
  ///   `9f06137 feat(sync): eliminate lost updates via serialized updateProfile and value-based echo suppression (Pass 5.0)`
  ///   `73a118c feat: promote party roster to authoritative re-addable CrdtOrSet and finalize Pass 4.1.2`
  ///   `1592394 feat: enforce new-CRDT boundaries, authoritative deserialization, and tombstone wiring (Pass 4.1.1)`
  ///   `fd74268 feat(app): relaunch 5e-toolkit with modularized domain core and clean legal compliance`
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDT({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;

    campAMap.remove('createdAt');
    campAMap.remove('lastPlayedAt');
    campBox[campAKey] = json.encode(campAMap);

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DPR (legacy pinnedRules map fallback for pinnedRules_crdt):
  /// Covers inventory row B17 (`lib/infrastructure/dtos/campaign_profile_dto.dart`:
  /// `CampaignProfileDto.fromMap` lines 538-553).
  /// Characterization: reads `map['pinnedRules']` via `CrdtOrSet<String>.fromMap` (line 545) when `pinnedRules_crdt` is absent.
  /// No writer in repository history ever wrote a `pinnedRules` map key (writers wrote `pinnedRuleIds` and `pinnedRules_crdt`).
  /// Command: `git log -S "'pinnedRules'" --oneline -- lib/`
  /// Output:
  ///   `4f5aa17 Pass 11: Final hardening fixes`
  ///   `7d803b2 feat(party): Pass 10 placeholder production paths, Source Bar M, and doc updates`
  ///   `5007537 feat(cold-iron): pass 9.1 placeholder laws, modifier source bar, catch audit, and cleanup`
  ///   `e458af9 fix(persistence): enforce import timestamp boundaries and schema validation (R4)`
  ///   `df02baa feat(party-state): implement Pass 7.1 party ledger synchronization and invariants`
  ///   `67d5d93 fix(sync): resolve trust boundary regression and strengthen concurrency law tests (Pass 5.0.1)`
  ///   `9f06137 feat(sync): eliminate lost updates via serialized updateProfile and value-based echo suppression (Pass 5.0)`
  ///   `8eea91e feat(crdt): preserve authoritative presence for empty sets and remove dead roster semantics (Pass 4.1.2.1)`
  ///   `73a118c feat: promote party roster to authoritative re-addable CrdtOrSet and finalize Pass 4.1.2`
  ///   `1592394 feat: enforce new-CRDT boundaries, authoritative deserialization, and tombstone wiring (Pass 4.1.1)`
  ///   `e3fc0ad feat: complete aggregate value identity and replicated deletion semantics (Pass 4.1)`
  ///   `2960757 feat(crdt): enforce atomic HLC drift validation and aggregate trust boundary (Pass 3.2.1)`
  ///   `fd74268 feat(app): relaunch 5e-toolkit with modularized domain core and clean legal compliance`
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDPR({
    required Map<String, dynamic> e3Storage,
    required Map<String, dynamic> e3Facts,
  }) {
    final storage = json.decode(json.encode(e3Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;

    final crdtRules = campAMap.remove('pinnedRules_crdt');
    campAMap['pinnedRules'] = crdtRules;
    campAMap.remove('pinnedRuleIds');
    campBox[campAKey] = json.encode(campAMap);

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e3Facts) as Map<String, dynamic>,
    );
  }

  /// DMC (legacy integer customAccentColor on minion without marker):
  /// Covers inventory row B23 (`lib/infrastructure/dtos/minion_instance_dto.dart`:
  /// `MinionInstanceDto.fromMap` lines 158-160).
  /// Characterization default: `rawMarker ?? (legacyColor != null ? 'alpha' : 'standard')` (line 160).
  /// No writer in repository history ever wrote `customAccentColor` without `marker` (`fd74268` already wrote `marker` and only wrote `customAccentColor` if non-null).
  /// Command: `git log -S "customAccentColor" --oneline -- lib/`
  /// Output:
  ///   `fd74268 feat(app): relaunch 5e-toolkit with modularized domain core and clean legal compliance`
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDMC({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;
    final roomState =
        Map<String, dynamic>.from(campAMap['roomState'] as Map? ?? {});

    final activeMinions = roomState['activeMinions'] as List?;
    if (activeMinions != null && activeMinions.isNotEmpty) {
      final firstMinion = Map<String, dynamic>.from(activeMinions[0] as Map);
      firstMinion.remove('marker');
      firstMinion['customAccentColor'] = 0xFFAA0000;
      activeMinions[0] = firstMinion;
    }

    final activeMinionsCrdt = roomState['activeMinions_crdt'] as Map?;
    if (activeMinionsCrdt != null) {
      final items = activeMinionsCrdt['items'] as Map?;
      final entry = items?['minion_1'] as Map?;
      final val = entry?['v'] as Map?;
      if (val != null) {
        val.remove('marker');
        val['customAccentColor'] = 0xFFAA0000;
      }
    }

    campAMap['roomState'] = roomState;
    campBox[campAKey] = json.encode(campAMap);

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }

  /// DB1 and DB2 (schemaVersion 1 and 2 app_backup envelopes):
  /// Covers inventory row B25 (`lib/services/persistence/app_backup_service.dart`:
  /// `AppBackupService.importFullBackupJson` line 323 `backup.schemaVersion > currentSchemaVersion`).
  /// Built from the envelope structure in `git show fd74268:lib/services/persistence/app_backup_service.dart`
  /// (`AppBackupPayload.toMap` lines 60-78), where `currentSchemaVersion` was already `3` at `fd74268`.
  /// Command: `git log -S "currentSchemaVersion" --oneline -- lib/services/persistence/app_backup_service.dart`
  /// Output:
  ///   `fd74268 feat(app): relaunch 5e-toolkit with modularized domain core and clean legal compliance`
  static Map<String, dynamic> deriveBackupSchemaVersion({
    required Map<String, dynamic> e1AppBackup,
    required int schemaVersion,
  }) {
    final backup =
        json.decode(json.encode(e1AppBackup)) as Map<String, dynamic>;
    backup['schemaVersion'] = schemaVersion;
    return LegacyFixtureSupport.sortJson(backup) as Map<String, dynamic>;
  }

  /// DPP (scalar-only partyPurse without counter maps):
  /// Covers inventory row B27 (`vtt-engine-core/lib/models/party_purse.dart`:
  /// `PartyPurse.fromMap` lines 357-378).
  /// No writer in repository history ever wrote a scalar-only `PartyPurse` (`e5ecce3` in `vtt-engine-core`
  /// already wrote `gpCounter`, `spCounter`, and `denominationCounters`).
  /// Command: `git log -S "denominationCounters" --oneline -- lib/` (in `vtt-engine-core`)
  /// Output:
  ///   `79224b7 feat(crdt): close Pass 3.1.1 fail-loud deserialization and authoritative counter precedence`
  ///   `1cd337c feat(crdt): close Pass 3.1 timestamp authority and deterministic reconstruction`
  ///   `e5ecce3 feat(core): initial release of pure Dart tabletop engine and CRDT synchronization primitives`
  static ({Map<String, dynamic> storage, Map<String, dynamic> facts}) deriveDPP({
    required Map<String, dynamic> e1Storage,
    required Map<String, dynamic> e1Facts,
  }) {
    final storage = json.decode(json.encode(e1Storage)) as Map<String, dynamic>;
    final boxes = storage['boxes'] as Map<String, dynamic>;
    final campBox =
        boxes[AppDatabaseService.boxCampaignProfiles] as Map<String, dynamic>;

    const campAKey = 'dn5e_campaign_profile_campaign_LEGACYA';
    final rawCampA = campBox[campAKey]?.toString() ?? '{}';
    final campAMap = json.decode(rawCampA) as Map<String, dynamic>;
    final purse =
        Map<String, dynamic>.from(campAMap['partyPurse'] as Map? ?? {});

    purse.remove('denominationCounters');
    purse.remove('customCounters');
    purse.removeWhere((k, _) => k.toLowerCase().endsWith('counter'));
    campAMap['partyPurse'] = purse;
    campBox[campAKey] = json.encode(campAMap);

    return (
      storage: LegacyFixtureSupport.sortJson(storage) as Map<String, dynamic>,
      facts: LegacyFixtureSupport.sortJson(e1Facts) as Map<String, dynamic>,
    );
  }
}
