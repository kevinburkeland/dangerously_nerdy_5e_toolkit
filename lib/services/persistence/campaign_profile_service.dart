import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/models/session_graph_models.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import '../../infrastructure/repositories/campaign_storage_migration.dart';
import '../../application/blob/blob_store_port.dart';
import '../party/campaign_registry_service.dart';
import '../../models/dm_screen_data.dart';
import '../../models/party/party_event.dart';

/// Thrown when a campaign profile is deleted from the repository but its associated
/// map blob ownership could not be fully released from the blob store.
class MapFilesNotRemovedException implements Exception {
  final String profileId;
  final Object cause;

  const MapFilesNotRemovedException(this.profileId, this.cause);

  @override
  String toString() =>
      'MapFilesNotRemovedException(profileId: $profileId, cause: $cause)';
}

/// Centralized presentation/application facade over [ICampaignRepository].
///
/// Keeps UI compatibility and [ChangeNotifier] reactivity while delegating
/// all record reads, writes, and active selection directly to the DI-registered
/// single-owner [ICampaignRepository].
class CampaignProfileService extends ChangeNotifier {
  static final CampaignProfileService _instance =
      CampaignProfileService._internal();

  factory CampaignProfileService() => _instance;

  /// Creates an isolated instance for multi-peer tests without mutating singleton state.
  static CampaignProfileService newInstance({
    required ICampaignRepository repository,
    required StatefulHlcClock clock,
    required ReplicaId replicaId,
    required CampaignRegistryService registryService,
    required BlobStorePort Function() blobStoreProvider,
  }) {
    final instance = CampaignProfileService._internal();
    instance._repository = repository;
    instance._clock = clock;
    instance._replicaId = replicaId;
    instance._registryService = registryService;
    instance._blobStoreProvider = blobStoreProvider;
    instance._ensureSubscribed(repository);
    return instance;
  }

  CampaignProfileService._internal() {
    CampaignProfile.defaultRulesetEdition = DmRulesEdition.v2024;
    CampaignProfile.defaultPinnedRulesFallback = const {
      'concentration',
      'grapple_shove',
    };
  }

  /// Binds runtime collaborators established during container bootstrap.
  static void configure({
    required ICampaignRepository repository,
    required StatefulHlcClock clock,
    required ReplicaId replicaId,
    required CampaignRegistryService registryService,
    required BlobStorePort Function() blobStoreProvider,
  }) {
    _instance._repository = repository;
    _instance._clock = clock;
    _instance._replicaId = replicaId;
    _instance._registryService = registryService;
    _instance._blobStoreProvider = blobStoreProvider;
    _instance._ensureSubscribed(repository);
  }

  ICampaignRepository? _repository;
  ReplicaId? _replicaId;
  StatefulHlcClock? _clock;
  BlobStorePort Function()? _blobStoreProvider;
  CampaignRegistryService? _registryService;

  StreamSubscription<CampaignProfile?>? _activeProfileSub;
  StreamSubscription<List<CampaignProfile>>? _allProfilesSub;
  Object? _subscribedRepoIdentity;

  void _ensureSubscribed(ICampaignRepository activeRepo) {
    if (_allProfilesSub != null && identical(_subscribedRepoIdentity, activeRepo)) {
      return;
    }
    _activeProfileSub?.cancel();
    _allProfilesSub?.cancel();
    _subscribedRepoIdentity = activeRepo;
    _activeProfileSub = activeRepo.watchActiveProfile().listen((_) {
      notifyListeners();
    });
    _allProfilesSub = activeRepo.watchAllProfiles().listen((_) {
      notifyListeners();
    });
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance._activeProfileSub?.cancel();
    _instance._activeProfileSub = null;
    _instance._allProfilesSub?.cancel();
    _instance._allProfilesSub = null;
    _instance._subscribedRepoIdentity = null;
    _instance._replicaId = null;
    _instance._clock = null;
  }

  @visibleForTesting
  static void fullResetForTesting() {
    resetForTesting();
    _instance._repository = null;
    _instance._blobStoreProvider = null;
    _instance._registryService = null;
  }

  ICampaignRepository _requireRepository() {
    final r = _repository;
    if (r != null) return r;
    throw StateError(
      'CampaignProfileService has no ICampaignRepository bound. '
      'Call initServiceLocator() before using it, or configure it in test setup.',
    );
  }

  StatefulHlcClock _requireClock() {
    final c = _clock;
    if (c != null) return c;
    throw StateError(
      'CampaignProfileService has no StatefulHlcClock bound. '
      'Call initServiceLocator() before using it, or configure it in test setup.',
    );
  }

  ReplicaId _requireReplicaId() {
    final id = _replicaId;
    if (id != null) return id;
    throw StateError(
      'CampaignProfileService has no ReplicaId bound. '
      'Call initServiceLocator() before using it, or configure it in test setup.',
    );
  }

  CampaignRegistryService _requireRegistryService() {
    final reg = _registryService;
    if (reg != null) return reg;
    throw StateError(
      'CampaignProfileService has no CampaignRegistryService bound. '
      'Call initServiceLocator() before using it, or configure it in test setup.',
    );
  }

  BlobStorePort _requireBlobStore() {
    final provider = _blobStoreProvider;
    if (provider != null) return provider();
    throw StateError(
      'CampaignProfileService has no BlobStorePort bound. '
      'Call initServiceLocator() before using it, or configure it in test setup.',
    );
  }

  String? get activeProfileId {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.activeProfileId;
  }

  CampaignProfile? get activeProfile {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.activeProfile;
  }

  ICampaignRepository get repo {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo;
  }

  List<CampaignProfile> get allProfiles {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.allProfiles;
  }

  /// Loads all campaign profiles from the underlying repository,
  /// executing registry adoption for unmapped campaigns, and returns the list.
  Future<List<CampaignProfile>> loadAllProfiles() async {
    final activeRepo = _requireRepository();
    final activeClock = _requireClock();
    final activeReplicaId = _requireReplicaId();
    final activeRegistry = _requireRegistryService();
    _ensureSubscribed(activeRepo);
    return _loadAllProfilesWith(
      activeRepo: activeRepo,
      activeClock: activeClock,
      activeReplicaId: activeReplicaId,
      activeRegistry: activeRegistry,
    );
  }

  Future<List<CampaignProfile>> _loadAllProfilesWith({
    required ICampaignRepository activeRepo,
    required StatefulHlcClock activeClock,
    required ReplicaId activeReplicaId,
    required CampaignRegistryService activeRegistry,
  }) async {
    final nodeId = activeReplicaId.value;
    await activeRepo.loadAllProfiles();
    await CampaignStorageMigration.adoptRegistryMemberships(
      activeRepo,
      clock: activeClock,
      nodeId: nodeId,
      registryService: activeRegistry,
    );
    if (activeRepo.allProfiles.isEmpty) {
      final defaultProfile = CampaignProfile.defaultProfile(
        nodeId: nodeId,
        clock: activeClock,
      );
      await activeRepo.putProfile(defaultProfile);
      await activeRepo.setActiveProfileId(defaultProfile.id);
    }
    return activeRepo.allProfiles;
  }

  /// Retrieves a campaign profile by ID through the repository port.
  Future<CampaignProfile?> getProfile(String id) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.getProfile(id);
  }

  /// Gets the currently active campaign profile through the repository port.
  Future<CampaignProfile?> getActiveProfile() async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.getActiveProfile();
  }

  /// Creates and activates a fresh campaign profile via [ICampaignRepository.putProfile].
  Future<CampaignProfile> createProfile({
    required String name,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) async {
    final activeRepo = _requireRepository();
    final activeClock = _requireClock();
    final activeReplicaId = _requireReplicaId();
    _ensureSubscribed(activeRepo);
    final newProfile = CampaignProfile.defaultProfile(
      name: name,
      edition: edition,
      nodeId: activeReplicaId.value,
      clock: activeClock,
    );
    await activeRepo.putProfile(newProfile);
    await activeRepo.setActiveProfileId(newProfile.id);
    return newProfile;
  }

  /// Updates a campaign profile by ID using the serialized [ICampaignRepository.updateProfile].
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    return activeRepo.updateProfile(id, transform);
  }

  /// Saves a campaign profile directly to the repository via [ICampaignRepository.putProfile].
  Future<void> putProfile(CampaignProfile profile) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    await activeRepo.putProfile(profile);
  }

  /// Updates the active campaign profile via serialized [ICampaignRepository.updateProfile].
  Future<void> updateActiveProfile(
    CampaignProfile Function(CampaignProfile current) updater,
  ) async {
    final activeRepo = _requireRepository();
    final activeClock = _requireClock();
    final activeReplicaId = _requireReplicaId();
    final activeRegistry = _requireRegistryService();
    _ensureSubscribed(activeRepo);
    var activeId = activeRepo.activeProfileId;
    if (activeId == null) {
      await _loadAllProfilesWith(
        activeRepo: activeRepo,
        activeClock: activeClock,
        activeReplicaId: activeReplicaId,
        activeRegistry: activeRegistry,
      );
      activeId = activeRepo.activeProfileId;
    }
    if (activeId != null) {
      await activeRepo.updateProfile(activeId, updater);
    }
  }

  /// Immediate save delegating to [putProfile].
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    await activeRepo.putProfile(profile);
  }

  /// Switches active profile pointer on the repository.
  Future<void> switchProfile(String profileId) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    await activeRepo.setActiveProfileId(profileId);
  }

  /// Sets the active campaign profile ID on the repository.
  Future<void> setActiveProfileId(String id) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    await activeRepo.setActiveProfileId(id);
  }

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId, [String? newName]) async {
    final activeRepo = _requireRepository();
    final activeClock = _requireClock();
    final activeReplicaId = _requireReplicaId();
    final activeRegistry = _requireRegistryService();
    _ensureSubscribed(activeRepo);
    CampaignProfile? source =
        activeRepo.allProfiles.where((p) => p.id == profileId).firstOrNull;
    if (source == null) {
      final all = await _loadAllProfilesWith(
        activeRepo: activeRepo,
        activeClock: activeClock,
        activeReplicaId: activeReplicaId,
        activeRegistry: activeRegistry,
      );
      source = all.where((p) => p.id == profileId).firstOrNull;
    }

    if (source == null) {
      throw StateError('Cannot clone campaign profile "$profileId": profile not found');
    }

    final now = DateTime.now();
    final newId = 'campaign_${now.millisecondsSinceEpoch}';
    final targetName = (newName != null && newName.trim().isNotEmpty)
        ? newName.trim()
        : '${source.name} (Copy)';

    final timestamp = activeClock.nextTimestamp();

    final cloned = source.copyWith(
      id: newId,
      name: targetName,
      nameTimestamp: timestamp,
      createdAt: now,
      lastPlayedAt: now,
      roomState: const RoomNodeState.empty(),
    );

    await activeRepo.putProfile(cloned);
    await activeRepo.setActiveProfileId(cloned.id);
    return cloned;
  }

  /// Deletes a campaign profile by ID via the repository port.
  ///
  /// If the deleted profile was active, switches to another profile or creates
  /// a fresh default profile if no campaigns remain.
  Future<void> deleteProfile(String profileId) async {
    final activeRepo = _requireRepository();
    final activeClock = _requireClock();
    final activeReplicaId = _requireReplicaId();
    final store = _requireBlobStore();
    _ensureSubscribed(activeRepo);
    await activeRepo.deleteProfile(profileId);
    if (activeRepo.allProfiles.isEmpty) {
      final fresh = CampaignProfile.defaultProfile(
        nodeId: activeReplicaId.value,
        clock: activeClock,
      );
      await activeRepo.putProfile(fresh);
      await activeRepo.setActiveProfileId(fresh.id);
    }
    try {
      await store.releaseCampaign(profileId);
    } catch (cause) {
      throw MapFilesNotRemovedException(profileId, cause);
    }
  }

  /// Records an event to each campaign profile containing [characterId] or matching [roomCode].
  ///
  /// Reads the current records directly from the single-owner repository and updates each
  /// matching campaign with a serialized [ICampaignRepository.updateProfile].
  Future<void> logCampaignEvent({
    required String characterId,
    required String characterName,
    required String type,
    required String details,
    String? roomCode,
  }) async {
    final activeRepo = _requireRepository();
    _ensureSubscribed(activeRepo);
    final profiles = activeRepo.allProfiles;

    final event = PartyEvent(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      roomCode: roomCode ?? '',
      type: type,
      playerName: characterName,
      details: details,
      timestamp: DateTime.now(),
    );

    for (final profile in profiles) {
      final matchesChar = profile.partyCharacterIds.contains(characterId);
      final matchesRoom = roomCode != null &&
          roomCode.isNotEmpty &&
          profile.roomState.roomCode.toUpperCase() == roomCode.toUpperCase();

      if (matchesChar || matchesRoom) {
        await activeRepo.updateProfile(profile.id, (current) {
          final updatedLog = [event, ...current.changeLog];
          return current.copyWith(changeLog: updatedLog);
        });
      }
    }
  }

  /// Clears in-memory subscriptions for isolated testing.
  @visibleForTesting
  void clearCacheForTesting() {
    _activeProfileSub?.cancel();
    _activeProfileSub = null;
    _allProfilesSub?.cancel();
    _allProfilesSub = null;
    _subscribedRepoIdentity = null;
  }
}
