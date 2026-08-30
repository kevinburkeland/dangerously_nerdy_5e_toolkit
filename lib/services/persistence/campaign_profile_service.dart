import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/campaign_profile.dart';
import '../../models/domain/session_graph_models.dart';
import '../app_services.dart';
import '../logging_service.dart';
import '../party/campaign_registry_service.dart';
import 'character_persistence_service.dart';

/// Centralized service coordinator for multi-campaign profile lifecycles and debounced persistence.
class CampaignProfileService extends ChangeNotifier {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';

  static final CampaignProfileService _instance = CampaignProfileService._internal();
  factory CampaignProfileService() => _instance;
  CampaignProfileService._internal();

  final Map<String, CampaignProfile> _memoryCache = {};
  String? _activeProfileId;
  bool _initialized = false;

  String? get activeProfileId => _activeProfileId;

  /// Loads all saved campaign profiles from persistent storage.
  Future<List<CampaignProfile>> loadAllProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexList = prefs.getStringList(profileIndexKey) ?? <String>[];
      final profiles = <CampaignProfile>[];

      for (final id in indexList) {
        if (_memoryCache.containsKey(id)) {
          profiles.add(_memoryCache[id]!);
          continue;
        }

        final rawJson = prefs.getString('$profileKeyPrefix$id');
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
          (p) => p.roomState.roomCode.toUpperCase() == m.roomCode.toUpperCase() ||
                 p.id == 'campaign_${m.roomCode}',
        );
        if (!alreadyExists) {
          final prof = CampaignProfile.defaultProfile(
            id: 'campaign_${m.roomCode}',
            name: m.campaignName.trim().isNotEmpty ? m.campaignName.trim() : 'Campaign ${m.roomCode}',
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
      LoggingService().logNonFatal(e, st, reason: 'Failed to load campaign profiles index');
    }

    // If still no profiles exist, create a clean default profile
    final defaultProf = CampaignProfile.defaultProfile(
      name: 'My Campaign',
    );
    await saveProfileImmediate(defaultProf);
    await switchProfile(defaultProf.id);
    _initialized = true;
    return [defaultProf];
  }

  /// Returns the currently active campaign profile. Generates a default profile if none exists.
  Future<CampaignProfile> getActiveProfile() async {
    if (!_initialized || _memoryCache.isEmpty) {
      await loadAllProfiles();
    }

    final prefs = await SharedPreferences.getInstance();
    _activeProfileId = prefs.getString(activeProfileIdKey) ?? _activeProfileId;

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
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = profile.toJson();
      await prefs.setString('$profileKeyPrefix${profile.id}', jsonStr);

      final indexList = List<String>.from(prefs.getStringList(profileIndexKey) ?? <String>[]);
      if (!indexList.contains(profile.id)) {
        indexList.add(profile.id);
        await prefs.setStringList(profileIndexKey, indexList);
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
      final prefs = await SharedPreferences.getInstance();
      _activeProfileId = profileId;
      await prefs.setString(activeProfileIdKey, profileId);
      notifyListeners();
    } catch (e, st) {
      LoggingService().logNonFatal(e, st, reason: 'Failed to switch active campaign: $profileId');
    }
  }

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId, String newName) async {
    CampaignProfile? source = _memoryCache[profileId];
    if (source == null) {
      final all = await loadAllProfiles();
      source = all.where((p) => p.id == profileId).firstOrNull;
    }

    final now = DateTime.now();
    final newId = 'campaign_${now.millisecondsSinceEpoch}';
    final targetName = newName.trim().isNotEmpty
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
      await prefs.remove('$profileKeyPrefix$profileId');

      final indexList = List<String>.from(prefs.getStringList(profileIndexKey) ?? <String>[]);
      indexList.remove(profileId);
      await prefs.setStringList(profileIndexKey, indexList);

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
