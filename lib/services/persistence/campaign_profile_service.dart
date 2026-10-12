import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_or_set.dart';
import 'package:vtt_engine_core/crdt/hybrid_logical_clock.dart';

import '../../infrastructure/di/injection_container.dart';
import '../../infrastructure/dtos/campaign_profile_dto.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/session_graph_models.dart';
import '../../models/party/party_event.dart';
import '../app_services.dart';
import '../logging_service.dart';
import '../party/campaign_registry_service.dart';
import 'app_database_service.dart';
import 'character_persistence_service.dart';

/// Centralized service coordinator for multi-campaign profile lifecycles and debounced persistence.
/// Implements [ICampaignRepository] for domain port compatibility.
class CampaignProfileService extends ChangeNotifier
    implements ICampaignRepository {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';

  static final CampaignProfileService _instance =
      CampaignProfileService._internal();
  factory CampaignProfileService({ReplicaId? replicaId, StatefulHlcClock? clock}) {
    if (replicaId != null) {
      _instance._replicaId = replicaId;
    }
    if (clock != null) {
      _instance._clock = clock;
    }
    return _instance;
  }
  CampaignProfileService._internal({ReplicaId? replicaId, StatefulHlcClock? clock})
      : _replicaId = replicaId,
        _clock = clock {
    CampaignProfile.defaultRulesetEdition = DmRulesEdition.v2024;
    CampaignProfile.defaultPinnedRulesFallback = const {
      'concentration',
      'grapple_shove',
    };
  }

  ReplicaId? _replicaId;
  StatefulHlcClock? _clock;

  @visibleForTesting
  static void resetForTesting() {
    _instance._replicaId = null;
    _instance._clock = null;
    _instance._memoryCache.clear();
    _instance._activeProfileId = null;
    _instance._initialized = false;
  }
  String get _effectiveNodeId {
    if (_clock != null) return _clock!.replicaId.value;
    if (sl.isRegistered<StatefulHlcClock>()) {
      return sl<StatefulHlcClock>().replicaId.value;
    }
    if (_replicaId != null) return _replicaId!.value;
    throw StateError(
      'CampaignProfileService requires an authoritative ReplicaId. '
      'Ensure initServiceLocator() has completed or inject ReplicaId explicitly.',
    );
  }

  StatefulHlcClock get _effectiveClock {
    if (_clock != null) return _clock!;
    if (sl.isRegistered<StatefulHlcClock>()) {
      return sl<StatefulHlcClock>();
    }
    throw StateError(
      'CampaignProfileService requires an authoritative StatefulHlcClock. '
      'Ensure initServiceLocator() has completed or inject StatefulHlcClock explicitly.',
    );
  }

  final AppDatabaseService _db = AppDatabaseService.instance;
  final Map<String, CampaignProfile> _memoryCache = {};
  String? _activeProfileId;
  bool _initialized = false;

  final StreamController<CampaignProfile?> _activeProfileController =
      StreamController<CampaignProfile?>.broadcast(sync: true);
  final StreamController<List<CampaignProfile>> _allProfilesController =
      StreamController<List<CampaignProfile>>.broadcast(sync: true);

  @override
  Stream<CampaignProfile?> watchActiveProfile() =>
      _activeProfileController.stream;

  @override
  Stream<List<CampaignProfile>> watchAllProfiles() =>
      _allProfilesController.stream;

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_activeProfileController.isClosed) {
      _activeProfileController.add(activeProfile);
    }
    if (!_allProfilesController.isClosed) {
      _allProfilesController.add(allProfiles);
    }
  }

  @override
  String? get activeProfileId => _activeProfileId;
  @override
  CampaignProfile? get activeProfile =>
      _activeProfileId != null ? _memoryCache[_activeProfileId] : null;
  @override
  List<CampaignProfile> get allProfiles => _memoryCache.values.toList();

  /// Loads all saved campaign profiles from persistent storage.
  @override
  Future<List<CampaignProfile>> loadAllProfiles() async {
    try {
      List<String> indexList = [];
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        final dbIndex =
            _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
        if (dbIndex is List) {
          indexList = dbIndex.map((e) => e.toString()).toList();
        }
      }

      final prefs = await SharedPreferences.getInstance();
      if (indexList.isEmpty) {
        indexList = prefs.getStringList(profileIndexKey) ?? <String>[];
      }

      final profiles = <CampaignProfile>[];
      _memoryCache.clear();

      for (final id in indexList) {
        String? rawJson;
        if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
          rawJson = _db
              .get(AppDatabaseService.boxCampaignProfiles,
                  '$profileKeyPrefix$id')
              ?.toString();
        }
        if (rawJson == null || rawJson.isEmpty) {
          rawJson = prefs.getString('$profileKeyPrefix$id');
          if (rawJson != null &&
              rawJson.isNotEmpty &&
              _db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
            // One-time migration into database
            await _db.put(AppDatabaseService.boxCampaignProfiles,
                '$profileKeyPrefix$id', rawJson);
          }
        }

        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            final rawMap = json.decode(rawJson) as Map<String, dynamic>;
            final profile = CampaignProfileDto.fromMap(rawMap).toDomain();
            final legacyChars =
                CampaignProfileDto.extractLegacyCharacters(rawMap);
            if (legacyChars.isNotEmpty) {
              await CharacterPersistenceService().saveCharacters(legacyChars);
              await _persistProfileToDisk(profile);
            }
            _memoryCache[id] = profile;
            profiles.add(profile);
          } catch (e, st) {
            LoggingService().logNonFatal(
              e,
              st,
              reason: 'Corrupted campaign profile skipped: $id',
            );
          }
        }
      }

      // Sync with CampaignRegistryService: Ensure every registered campaign has a corresponding DM profile
      final registry = CampaignRegistryService();
      final memberships = await registry.loadMemberships();
      final savedCharacters =
          await CharacterPersistenceService().loadCharacters();

      for (final m in memberships) {
        final alreadyExists = profiles.any(
          (p) =>
              p.roomState.roomCode.toUpperCase() == m.roomCode.toUpperCase() ||
              p.id == 'campaign_${m.roomCode}',
        );
        if (!alreadyExists) {
          final entries =
              <({String id, String item, HybridLogicalClock timestamp})>[];
          for (final char in savedCharacters) {
            entries.add((
              id: char.id.slug,
              item: char.id.slug,
              timestamp: _effectiveClock.nextTimestamp(),
            ));
          }
          final partyRoster = entries.isNotEmpty
              ? const CrdtOrSet<String>.empty().addBatch(entries)
              : const CrdtOrSet<String>.empty();

          final prof = CampaignProfile(
            id: 'campaign_${m.roomCode}',
            name: m.campaignName.trim().isNotEmpty
                ? m.campaignName.trim()
                : 'Campaign ${m.roomCode}',
            nodeId: _effectiveNodeId,
            createdAt: DateTime.now().toUtc(),
            lastPlayedAt: DateTime.now().toUtc(),
            partyRoster: partyRoster,
            roomState: RoomNodeState(
              roomId: 'room_${m.roomCode}',
              roomCode: m.roomCode,
              title: '${m.campaignName} Staging Area',
              description: 'Active DM session staging node.',
            ),
          );
          await saveProfileImmediate(prof);
          profiles.add(prof);
        }
      }

      if (profiles.isNotEmpty) {
        _initialized = true;
        return profiles;
      }
    } catch (e, st) {
      LoggingService().logFatal(
        e,
        st,
        reason: 'Failed to load campaign profiles from storage',
      );
    }

    // Default Fallback
    final defaultProfile =
        CampaignProfile.defaultProfile(nodeId: _effectiveNodeId, clock: _effectiveClock);
    await saveProfileImmediate(defaultProfile);
    _initialized = true;
    return [defaultProfile];
  }

  /// Retrieves a campaign profile by ID from cache or persistent storage.
  @override
  Future<CampaignProfile?> getProfile(String id) async {
    if (_memoryCache.containsKey(id)) return _memoryCache[id];
    final all = await loadAllProfiles();
    return all.where((p) => p.id == id).firstOrNull;
  }

  /// Gets the currently active campaign profile, initializing if empty.
  @override
  Future<CampaignProfile> getActiveProfile() async {
    if (!_initialized || _memoryCache.isEmpty) {
      await loadAllProfiles();
    }

    final prefs = await SharedPreferences.getInstance();
    String? activeId;
    if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
      activeId = _db
          .get(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey)
          ?.toString();
    }
    _activeProfileId =
        activeId ?? prefs.getString(activeProfileIdKey) ?? _activeProfileId;

    if (_activeProfileId != null &&
        _memoryCache.containsKey(_activeProfileId)) {
      return _memoryCache[_activeProfileId]!;
    }

    if (_memoryCache.isNotEmpty) {
      final first = _memoryCache.values.first;
      _activeProfileId = first.id;
      await prefs.setString(activeProfileIdKey, first.id);
      return first;
    }

    final freshDefault =
        CampaignProfile.defaultProfile(nodeId: _effectiveNodeId, clock: _effectiveClock);
    await saveProfileImmediate(freshDefault);
    await switchProfile(freshDefault.id);
    return freshDefault;
  }

  /// Creates and activates a fresh campaign profile.
  Future<CampaignProfile> createProfile({
    required String name,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) async {
    final newProfile = CampaignProfile.defaultProfile(
      name: name,
      edition: edition,
      nodeId: _effectiveNodeId,
      clock: _effectiveClock,
    );
    await saveProfileImmediate(newProfile);
    await switchProfile(newProfile.id);
    return newProfile;
  }

  final Map<String, Future<void>> _updateQueues = {};

  @override
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final prev = _updateQueues[id] ?? Future<void>.value();
    final completer = Completer<CampaignProfile>();
    late final Future<void> currentFuture;

    currentFuture = () async {
      try {
        await prev;
      } catch (_) {}

      try {
        var current = _memoryCache[id];
        if (current == null) {
          await loadAllProfiles();
          current = _memoryCache[id];
        }
        if (current == null) {
          throw StateError('Campaign profile with id "$id" not found');
        }
        final next = transform(current).copyWith(lastPlayedAt: DateTime.now());
        _memoryCache[id] = next;
        AppServices.instance.debouncedStorage.cancelTask('campaign_save_$id');
        await _persistProfileToDisk(next);
        notifyListeners();
        completer.complete(next);
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        if (identical(_updateQueues[id], currentFuture)) {
          _updateQueues.remove(id);
        }
      }
    }();

    _updateQueues[id] = currentFuture;
    return completer.future;
  }

  @override
  Future<void> putProfile(CampaignProfile profile) async {
    final prev = _updateQueues[profile.id] ?? Future<void>.value();
    final completer = Completer<void>();
    late final Future<void> currentFuture;

    currentFuture = () async {
      try {
        await prev;
      } catch (_) {}

      try {
        final updated = profile.copyWith(lastPlayedAt: DateTime.now());
        _memoryCache[updated.id] = updated;
        AppServices.instance.debouncedStorage
            .cancelTask('campaign_save_${updated.id}');
        await _persistProfileToDisk(updated);
        notifyListeners();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      } finally {
        if (identical(_updateQueues[profile.id], currentFuture)) {
          _updateQueues.remove(profile.id);
        }
      }
    }();

    _updateQueues[profile.id] = currentFuture;
    return completer.future;
  }

  /// Saves a campaign profile with debounced asynchronous persistence.
  Future<void> saveProfile(CampaignProfile profile) async {
    final updated = profile.copyWith(lastPlayedAt: DateTime.now());
    _memoryCache[updated.id] = updated;
    notifyListeners();

    final taskKey = 'campaign_save_${updated.id}';
    AppServices.instance.debouncedStorage.scheduleWrite(
      taskKey,
      () => _persistProfileToDisk(updated),
      duration: const Duration(milliseconds: 300),
    );
  }

  /// Alias for debounced profile saving.
  void saveProfileDebounced(CampaignProfile profile) {
    saveProfile(profile);
  }

  /// Atomically updates the active profile in memory and initiates persistence.
  Future<void> updateActiveProfile(
    CampaignProfile Function(CampaignProfile current) updater, {
    bool immediate = false,
  }) async {
    if (_activeProfileId == null) {
      await loadAllProfiles();
    }
    if (_activeProfileId != null) {
      await updateProfile(_activeProfileId!, updater);
    }
  }

  /// Saves and flushes a campaign profile directly to disk without debouncing.
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await putProfile(profile);
  }

  /// Internal disk persistence implementation
  Future<void> _persistProfileToDisk(CampaignProfile profile) async {
    try {
      final jsonStr = CampaignProfileDto.fromDomain(profile).toJson();
      final prefs = await SharedPreferences.getInstance();
      var indexList = prefs.getStringList(profileIndexKey) ?? <String>[];

      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(
          AppDatabaseService.boxCampaignProfiles,
          '$profileKeyPrefix${profile.id}',
          jsonStr,
        );

        final dbIndex =
            _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
        if (dbIndex is List) {
          indexList = dbIndex.map((e) => e.toString()).toList();
        }
        if (!indexList.contains(profile.id)) {
          indexList.add(profile.id);
          await _db.put(AppDatabaseService.boxCampaignProfiles, profileIndexKey,
              indexList);
        }
      } else {
        if (!indexList.contains(profile.id)) {
          indexList.add(profile.id);
        }
      }

      // Sync to SharedPreferences
      try {
        await prefs.setString('$profileKeyPrefix${profile.id}', jsonStr);
        await prefs.setStringList(profileIndexKey, indexList);
      } catch (_) {
        // Suppress quota exceeded in SharedPreferences
      }
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to persist campaign profile: ${profile.id}',
      );
    }
  }

  /// Switches active profile pointer and triggers reactivity.
  Future<void> switchProfile(String profileId) async {
    try {
      _activeProfileId = profileId;
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(AppDatabaseService.boxCampaignProfiles,
            activeProfileIdKey, profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activeProfileIdKey, profileId);
      notifyListeners();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to switch active campaign: $profileId');
    }
  }

  /// Sets the active campaign profile ID and persists the selection.
  @override
  Future<void> setActiveProfileId(String id) => switchProfile(id);

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId,
      [String? newName]) async {
    CampaignProfile? source = _memoryCache[profileId];
    if (source == null) {
      final all = await loadAllProfiles();
      source = all.where((p) => p.id == profileId).firstOrNull;
    }

    final now = DateTime.now();
    final newId = 'campaign_${now.millisecondsSinceEpoch}';
    final targetName = (newName != null && newName.trim().isNotEmpty)
        ? newName.trim()
        : '${source?.name ?? "Campaign"} (Copy)';

    final timestamp = sl.isRegistered<StatefulHlcClock>()
        ? sl<StatefulHlcClock>().nextTimestamp()
        : throw StateError(
            'Authoritative StatefulHlcClock is required for CampaignProfileService.cloneProfile. '
            'Register StatefulHlcClock in DI.',
          );

    final cloned =
        (source ?? CampaignProfile.defaultProfile(nodeId: _effectiveNodeId, clock: _effectiveClock))
            .copyWith(
      id: newId,
      name: targetName,
      nameTimestamp: timestamp,
      createdAt: now,
      lastPlayedAt: now,
      roomState: (source?.roomState ??
              CampaignProfile.defaultProfile(nodeId: _effectiveNodeId, clock: _effectiveClock)
                  .roomState)
          .copyWith(
        roomId: 'room_$newId',
        title: '$targetName - Staging Area',
        titleTimestamp: timestamp,
      ),
    );

    await saveProfileImmediate(cloned);
    await switchProfile(cloned.id);
    return cloned;
  }

  /// Deletes a campaign profile by ID from memory and disk.
  @override
  Future<void> deleteProfile(String profileId) async {
    try {
      _memoryCache.remove(profileId);
      final prefs = await SharedPreferences.getInstance();
      var indexList = prefs.getStringList(profileIndexKey) ?? <String>[];

      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.delete(AppDatabaseService.boxCampaignProfiles,
            '$profileKeyPrefix$profileId');

        final dbIndex =
            _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
        if (dbIndex is List) {
          indexList = dbIndex.map((e) => e.toString()).toList();
        }
        indexList.remove(profileId);
        await _db.put(
            AppDatabaseService.boxCampaignProfiles, profileIndexKey, indexList);
      } else {
        indexList.remove(profileId);
      }

      try {
        await prefs.remove('$profileKeyPrefix$profileId');
        await prefs.setStringList(profileIndexKey, indexList);
      } catch (_) {}

      if (_activeProfileId == profileId) {
        if (indexList.isNotEmpty) {
          await switchProfile(indexList.first);
        } else {
          final fresh =
              CampaignProfile.defaultProfile(nodeId: _effectiveNodeId, clock: _effectiveClock);
          await saveProfileImmediate(fresh);
          await switchProfile(fresh.id);
        }
      } else {
        notifyListeners();
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st,
          reason: 'Failed to delete campaign profile: $profileId');
    }
  }

  /// Records an event to any campaign profile containing [characterId] or matching [roomCode].
  Future<void> logCampaignEvent({
    required String characterId,
    required String characterName,
    required String type,
    required String details,
    String? roomCode,
  }) async {
    final event = PartyEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      roomCode: roomCode ?? '',
      type: type,
      playerName: characterName,
      details: details,
      timestamp: DateTime.now(),
    );

    for (final profile in _memoryCache.values.toList()) {
      final matchesChar = profile.partyCharacterIds.contains(characterId);
      final matchesRoom = roomCode != null &&
          roomCode.isNotEmpty &&
          profile.roomState.roomCode.toUpperCase() == roomCode.toUpperCase();

      if (matchesChar || matchesRoom) {
        final updatedLog = [event, ...profile.changeLog];
        final updatedProfile = profile.copyWith(changeLog: updatedLog);
        _memoryCache[profile.id] = updatedProfile;
        await _persistProfileToDisk(updatedProfile);
        notifyListeners();
      }
    }
  }

  /// Clears in-memory cache for isolated testing.
  void clearCacheForTesting() {
    _memoryCache.clear();
    _activeProfileId = null;
    _initialized = false;
  }
}
