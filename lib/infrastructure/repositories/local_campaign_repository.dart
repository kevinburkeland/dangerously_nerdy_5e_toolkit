import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/campaign_profile.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../domain/ports/i_character_repository.dart';
import '../../models/domain/session_graph_models.dart';
import '../../services/app_services.dart';
import '../../services/logging_service.dart';
import '../../services/party/campaign_registry_service.dart';
import '../../services/persistence/app_database_service.dart';
import '../dtos/campaign_profile_dto.dart';
import 'local_character_repository.dart';

/// Concrete infrastructure adapter implementing [ICampaignRepository]
/// with in-memory caching, debounced persistence, and Hive/IndexedDB ([AppDatabaseService]) storage.
class LocalCampaignRepository extends ChangeNotifier implements ICampaignRepository {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';

  static final LocalCampaignRepository _instance = LocalCampaignRepository._internal();
  factory LocalCampaignRepository() => _instance;
  LocalCampaignRepository._internal();

  final AppDatabaseService _db = AppDatabaseService.instance;
  final ICharacterRepository _characterRepo = LocalCharacterRepository();
  final Map<String, CampaignProfile> _memoryCache = {};
  String? _activeProfileId;
  bool _initialized = false;

  @override
  String? get activeProfileId => _activeProfileId;

  @override
  CampaignProfile? get activeProfile =>
      _activeProfileId != null ? _memoryCache[_activeProfileId] : null;

  @override
  List<CampaignProfile> get allProfiles => _memoryCache.values.toList();

  @override
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
            await _db.put(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id', rawJson);
          }
        }

        if (rawJson != null && rawJson.isNotEmpty) {
          try {
            final dto = CampaignProfileDto.fromJson(rawJson);
            final profile = dto.toDomain();
            if (profile.migratedCharacters.isNotEmpty) {
              await _characterRepo.saveCharacters(profile.migratedCharacters);
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

      // Sync with CampaignRegistryService
      final registry = CampaignRegistryService();
      final memberships = await registry.loadMemberships();
      final savedCharacters = await _characterRepo.loadCharacters();

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
                ? m.campaignName
                : 'Room ${m.roomCode}',
          ).copyWith(
            roomState: RoomNodeState(
              roomId: 'room_${m.roomCode}',
              roomCode: m.roomCode.toUpperCase(),
              title: '${m.campaignName.isNotEmpty ? m.campaignName : "Room"} Staging',
              description: 'Active DM session staging node.',
            ),
          );

          final matchedChar = savedCharacters.cast<dynamic>().firstWhere(
                (c) => c.id.slug == m.characterId || c.name == m.characterId,
                orElse: () => null,
              );

          CampaignProfile populated = prof;
          if (matchedChar != null && !prof.partyCharacterIds.contains(matchedChar.id.slug)) {
            populated = prof.copyWith(
              partyCharacterIds: [matchedChar.id.slug as String],
            );
          }

          _memoryCache[populated.id] = populated;
          profiles.add(populated);
          await _persistProfileToDisk(populated);
        }
      }

      // Load active profile ID
      String? activeId;
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        activeId = _db.get(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey)?.toString();
      }
      activeId ??= prefs.getString(activeProfileIdKey);

      if (activeId != null && _memoryCache.containsKey(activeId)) {
        _activeProfileId = activeId;
      } else if (profiles.isNotEmpty) {
        _activeProfileId = profiles.first.id;
      } else {
        final def = CampaignProfile.defaultProfile();
        _memoryCache[def.id] = def;
        profiles.add(def);
        _activeProfileId = def.id;
        await _persistProfileToDisk(def);
      }

      await _persistIndex();
      _initialized = true;
      notifyListeners();
      return profiles;
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to load campaign profiles.',
      );
      return [];
    }
  }

  @override
  Future<CampaignProfile?> getProfile(String id) async {
    if (!_initialized) await loadAllProfiles();
    return _memoryCache[id];
  }

  @override
  Future<CampaignProfile?> getActiveProfile() async {
    if (!_initialized) await loadAllProfiles();
    return activeProfile;
  }

  @override
  Future<void> saveProfile(CampaignProfile profile) async {
    _memoryCache[profile.id] = profile;
    notifyListeners();

    AppServices.instance.debouncedStorage.scheduleWrite(
      'save_campaign_profile_${profile.id}',
      () => _persistProfileToDisk(profile),
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await AppServices.instance.debouncedStorage.flushKey('save_campaign_profile_${profile.id}');
    _memoryCache[profile.id] = profile;
    await _persistProfileToDisk(profile);
    notifyListeners();
  }

  @override
  Future<void> deleteProfile(String id) async {
    if (!_initialized) await loadAllProfiles();
    _memoryCache.remove(id);

    try {
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.delete(AppDatabaseService.boxCampaignProfiles, '$profileKeyPrefix$id');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$profileKeyPrefix$id');
    } catch (_) {}

    await _persistIndex();

    if (_activeProfileId == id) {
      _activeProfileId = _memoryCache.keys.isNotEmpty ? _memoryCache.keys.first : null;
      if (_activeProfileId != null) {
        await setActiveProfileId(_activeProfileId!);
      }
    }
    notifyListeners();
  }

  @override
  Future<void> setActiveProfileId(String id) async {
    _activeProfileId = id;
    try {
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(AppDatabaseService.boxCampaignProfiles, activeProfileIdKey, id);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(activeProfileIdKey, id);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persistProfileToDisk(CampaignProfile profile) async {
    try {
      final dto = CampaignProfileDto.fromDomain(profile);
      final jsonStr = dto.toJson();
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(
          AppDatabaseService.boxCampaignProfiles,
          '$profileKeyPrefix${profile.id}',
          jsonStr,
        );
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$profileKeyPrefix${profile.id}', jsonStr);
      } catch (_) {}
    } catch (e) {
      LoggingService().logWarning('Failed to persist campaign profile: $e', e);
    }
  }

  Future<void> _persistIndex() async {
    try {
      final idList = _memoryCache.keys.toList();
      if (_db.isBoxOpen(AppDatabaseService.boxCampaignProfiles)) {
        await _db.put(
          AppDatabaseService.boxCampaignProfiles,
          profileIndexKey,
          idList,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(profileIndexKey, idList);
    } catch (e) {
      LoggingService().logWarning('Failed to persist campaign index: $e', e);
    }
  }
}
