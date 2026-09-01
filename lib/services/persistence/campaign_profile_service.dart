import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/campaign_profile.dart';
import '../../models/dm_screen_data.dart';
import '../../models/domain/session_graph_models.dart';
import '../app_services.dart';
import '../logging_service.dart';
import '../party/campaign_registry_service.dart';
import 'app_database_service.dart';
import 'character_persistence_service.dart';

/// Centralized service coordinator for multi-campaign profile lifecycles and debounced persistence.
/// Backed by Hive / IndexedDB via [AppDatabaseService], bypassing 5MB localStorage limits.
class CampaignProfileService extends ChangeNotifier {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';

  static final CampaignProfileService _instance = CampaignProfileService._internal();
  factory CampaignProfileService() => _instance;
  CampaignProfileService._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;
  final Map<String, CampaignProfile> _memoryCache = {};
  String? _activeProfileId;
  bool _initialized = false;

  String? get activeProfileId => _activeProfileId;
  CampaignProfile? get activeProfile =>
      _activeProfileId != null ? _memoryCache[_activeProfileId] : null;
  List<CampaignProfile> get allProfiles => _memoryCache.values.toList();

  /// Loads all saved campaign profiles from persistent storage.
  Future<List<CampaignProfile>> loadAllProfiles() async {
    try {
      List<String> indexList = [];
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        final dbIndex = _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
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
          rawJson = _db.get(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id')?.toString();
        }
        if (rawJson == null || rawJson.isEmpty) {
          rawJson = prefs.getString('$profileKeyPrefix$id');
          if (rawJson != null && rawJson.isNotEmpty && _db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
            // One-time migration into database
            await _db.put(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id', rawJson);
          }
        }

        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            final profile = CampaignProfile.fromJson(rawJson);
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
      final savedCharacters = await CharacterPersistenceService().loadCharacters();

      for (final m in memberships) {
        final alreadyExists = profiles.any(
          (p) =>
              p.roomState.roomCode.toUpperCase() == m.roomCode.toUpperCase() ||
              p.id == 'campaign_${m.roomCode}',
        );
        if (!alreadyExists) {
          final prof = CampaignProfile.defaultProfile(
            id: 'campaign_${m.roomCode}',
            name: m.campaignName.trim().isNotEmpty
                ? m.campaignName.trim()
                : 'Campaign ${m.roomCode}',
          ).copyWith(
            partyRoster: savedCharacters,
            roomState: RoomNodeState(
              roomId: 'room_${m.roomCode}',
              roomCode: m.roomCode,
              title: '${m.campaignName} Staging Area',
              description: 'Active DM session staging node.',
            ),
            notesMarkdown: '',
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
    final defaultProfile = CampaignProfile.defaultProfile();
    await saveProfileImmediate(defaultProfile);
    _initialized = true;
    return [defaultProfile];
  }

  /// Gets the currently active campaign profile, initializing if empty.
  Future<CampaignProfile> getActiveProfile() async {
    if (!_initialized || _memoryCache.isEmpty) {
      await loadAllProfiles();
    }

    final prefs = await SharedPreferences.getInstance();
    String? activeId;
    if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
      activeId = _db.get(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey)?.toString();
    }
    _activeProfileId = activeId ?? prefs.getString(activeProfileIdKey) ?? _activeProfileId;

    if (_activeProfileId != null && _memoryCache.containsKey(_activeProfileId)) {
      return _memoryCache[_activeProfileId]!;
    }

    if (_memoryCache.isNotEmpty) {
      final first = _memoryCache.values.first;
      _activeProfileId = first.id;
      await prefs.setString(activeProfileIdKey, first.id);
      return first;
    }

    final freshDefault = CampaignProfile.defaultProfile();
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
    );
    await saveProfileImmediate(newProfile);
    await switchProfile(newProfile.id);
    return newProfile;
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
    final current = await getActiveProfile();
    final updated = updater(current);
    if (immediate) {
      await saveProfileImmediate(updated);
    } else {
      await saveProfile(updated);
    }
  }

  /// Saves and flushes a campaign profile directly to disk without debouncing.
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    final updated = profile.copyWith(lastPlayedAt: DateTime.now());
    _memoryCache[updated.id] = updated;
    await _persistProfileToDisk(updated);
    notifyListeners();
  }

  /// Internal disk persistence implementation
  Future<void> _persistProfileToDisk(CampaignProfile profile) async {
    try {
      final jsonStr = profile.toJson();
      final prefs = await SharedPreferences.getInstance();
      var indexList = prefs.getStringList(profileIndexKey) ?? <String>[];

      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(
          AppDatabaseService.boxCampaignProfiles,
          '$profileKeyPrefix${profile.id}',
          jsonStr,
        );

        final dbIndex = _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
        if (dbIndex is List) {
          indexList = dbIndex.map((e) => e.toString()).toList();
        }
        if (!indexList.contains(profile.id)) {
          indexList.add(profile.id);
          await _db.put(AppDatabaseService.boxCampaignProfiles, profileIndexKey, indexList);
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
        await _db.put(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey, profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activeProfileIdKey, profileId);
      notifyListeners();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to switch active campaign: $profileId');
    }
  }

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId, [String? newName]) async {
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

    final cloned = (source ?? CampaignProfile.defaultProfile()).copyWith(
      id: newId,
      name: targetName,
      createdAt: now,
      lastPlayedAt: now,
      roomState: (source?.roomState ?? CampaignProfile.defaultProfile().roomState).copyWith(
        roomId: 'room_$newId',
        title: '$targetName - Staging Area',
      ),
    );

    await saveProfileImmediate(cloned);
    await switchProfile(cloned.id);
    return cloned;
  }

  /// Deletes a campaign profile by ID from memory and disk.
  Future<void> deleteProfile(String profileId) async {
    try {
      _memoryCache.remove(profileId);
      final prefs = await SharedPreferences.getInstance();
      var indexList = prefs.getStringList(profileIndexKey) ?? <String>[];

      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.delete(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$profileId');

        final dbIndex = _db.get(AppDatabaseService.boxCampaignProfiles, profileIndexKey);
        if (dbIndex is List) {
          indexList = dbIndex.map((e) => e.toString()).toList();
        }
        indexList.remove(profileId);
        await _db.put(AppDatabaseService.boxCampaignProfiles, profileIndexKey, indexList);
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
          final fresh = CampaignProfile.defaultProfile();
          await saveProfileImmediate(fresh);
          await switchProfile(fresh.id);
        }
      } else {
        notifyListeners();
      }
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to delete campaign profile: $profileId');
    }
  }

  /// Clears in-memory cache for isolated testing.
  void clearCacheForTesting() {
    _memoryCache.clear();
    _activeProfileId = null;
    _initialized = false;
  }
}
