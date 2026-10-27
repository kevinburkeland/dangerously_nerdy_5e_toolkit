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
}
