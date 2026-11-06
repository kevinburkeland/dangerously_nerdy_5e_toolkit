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

  factory CampaignProfileService({
    ReplicaId? replicaId,
    StatefulHlcClock? clock,
    ICampaignRepository? repo,
    BlobStorePort? blobStore,
    BlobStorePort Function()? blobStoreProvider,
    CampaignRegistryService? registryService,
  }) {
    final dummy = registryService ?? CampaignRegistryService();
    if (repo != null) {
      return CampaignProfileService._internal(
        replicaId: replicaId,
        clock: clock,
        repoOverride: repo,
        blobStore: blobStore,
        blobStoreProvider: blobStoreProvider,
        registryService: registryService,
      );
    }
    if (replicaId != null) {
      _instance._replicaId = replicaId;
    }
    if (clock != null) {
      _instance._clock = clock;
    }
    if (blobStore != null) {
      _instance._blobStore = blobStore;
    }
    if (blobStoreProvider != null) {
      _instance._blobStoreProvider = blobStoreProvider;
    }
    if (registryService != null) {
      _instance._registryService = registryService;
    }
    return _instance;
  }

  /// Creates an isolated instance for multi-peer tests without mutating singleton state.
  static CampaignProfileService newInstance({
    ReplicaId? replicaId,
    StatefulHlcClock? clock,
    required ICampaignRepository repo,
    BlobStorePort? blobStore,
    BlobStorePort Function()? blobStoreProvider,
    CampaignRegistryService? registryService,
  }) {
    return CampaignProfileService._internal(
      replicaId: replicaId,
      clock: clock,
      repoOverride: repo,
      blobStore: blobStore,
      blobStoreProvider: blobStoreProvider,
      registryService: registryService,
    );
  }

  CampaignProfileService._internal({
    ReplicaId? replicaId,
    StatefulHlcClock? clock,
    ICampaignRepository? repoOverride,
    BlobStorePort? blobStore,
    BlobStorePort Function()? blobStoreProvider,
    CampaignRegistryService? registryService,
  })  : _replicaId = replicaId,
        _clock = clock,
        _repoOverride = repoOverride,
        _blobStore = blobStore,
        _blobStoreProvider = blobStoreProvider,
        _registryService = registryService {
    CampaignProfile.defaultRulesetEdition = DmRulesEdition.v2024;
    CampaignProfile.defaultPinnedRulesFallback = const {
      'concentration',
      'grapple_shove',
    };
    _ensureSubscribed();
  }

  /// Binds runtime collaborators established during container bootstrap.
  static void configure({
    required ICampaignRepository repository,
    required StatefulHlcClock clock,
    required ReplicaId replicaId,
    BlobStorePort? blobStore,
    BlobStorePort Function()? blobStoreProvider,
    CampaignRegistryService? registryService,
  }) {
    _instance._repoOverride = repository;
    _instance._clock = clock;
    _instance._replicaId = replicaId;
    _instance._blobStore = blobStore;
    _instance._blobStoreProvider = blobStoreProvider;
    _instance._registryService = registryService;
    _instance._ensureSubscribed();
  }

  static void bindRepository(ICampaignRepository repo) {
    _instance._repoOverride = repo;
    _instance._ensureSubscribed();
  }

  static void bindClock(StatefulHlcClock clock) {
    _instance._clock = clock;
  }

  static void bindReplicaId(ReplicaId replicaId) {
    _instance._replicaId = replicaId;
  }

  static void bindBlobStore(BlobStorePort blobStore) {
    _instance._blobStore = blobStore;
  }

  ICampaignRepository? _repoOverride;
  ReplicaId? _replicaId;
  StatefulHlcClock? _clock;
  BlobStorePort? _blobStore;
  BlobStorePort Function()? _blobStoreProvider;
  CampaignRegistryService? _registryService;

  StreamSubscription<CampaignProfile?>? _activeProfileSub;
  StreamSubscription<List<CampaignProfile>>? _allProfilesSub;

  void _ensureSubscribed() {
    if (_allProfilesSub != null) return;
    final r = _repoOverride;
    if (r != null) {
      _allSubscribedRepo = r;
      _activeProfileSub = r.watchActiveProfile().listen((_) {
        notifyListeners();
      });
      _allProfilesSub = r.watchAllProfiles().listen((_) {
        notifyListeners();
      });
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _instance._activeProfileSub?.cancel();
    _instance._activeProfileSub = null;
    _instance._allProfilesSub?.cancel();
    _instance._allProfilesSub = null;
    _instance._allSubscribedRepo = null;
    _instance._replicaId = null;
    _instance._clock = null;
  }

  static void fullResetForTesting() {
    resetForTesting();
    _instance._repoOverride = null;
    _instance._blobStore = null;
    _instance._blobStoreProvider = null;
    _instance._registryService = null;
  }

  ICampaignRepository? _allSubscribedRepo;

  void _checkRepoSubscription() {
    final currentRepo = _repoOverride;
    if (currentRepo == null) return;
    if (_allSubscribedRepo != currentRepo) {
      _activeProfileSub?.cancel();
      _allProfilesSub?.cancel();
      _allSubscribedRepo = currentRepo;
      _activeProfileSub = currentRepo.watchActiveProfile().listen((_) => notifyListeners());
      _allProfilesSub = currentRepo.watchAllProfiles().listen((_) => notifyListeners());
    }
  }

  String get _effectiveNodeId {
    if (_clock != null) return _clock!.replicaId.value;
    if (_replicaId != null) return _replicaId!.value;
    throw StateError(
      'CampaignProfileService requires an authoritative ReplicaId. '
      'Ensure initServiceLocator() has completed or inject ReplicaId explicitly.',
    );
  }

  StatefulHlcClock get _effectiveClock {
    if (_clock != null) return _clock!;
    throw StateError(
      'CampaignProfileService requires an authoritative StatefulHlcClock. '
      'Ensure initServiceLocator() has completed or inject StatefulHlcClock explicitly.',
    );
  }

  String? get activeProfileId {
    _checkRepoSubscription();
    return repo.activeProfileId;
  }

  CampaignProfile? get activeProfile {
    _checkRepoSubscription();
    return repo.activeProfile;
  }

  ICampaignRepository get repo {
    final r = _repoOverride;
    if (r != null) return r;
    throw StateError(
      'CampaignProfileService requires an authoritative ICampaignRepository. '
      'Ensure initServiceLocator() has completed or inject repo explicitly.',
    );
  }

  List<CampaignProfile> get allProfiles {
    _checkRepoSubscription();
    return repo.allProfiles;
  }

  /// Loads all campaign profiles from the underlying repository,
  /// executing registry adoption for unmapped campaigns, and returns the list.
  Future<List<CampaignProfile>> loadAllProfiles() async {
    final activeRepo = repo;
    await activeRepo.loadAllProfiles();
    await CampaignStorageMigration.adoptRegistryMemberships(
      activeRepo,
      clock: _effectiveClock,
      nodeId: _effectiveNodeId,
      registryService: _registryService,
    );
    if (activeRepo.allProfiles.isEmpty) {
      final defaultProfile = CampaignProfile.defaultProfile(
        nodeId: _effectiveNodeId,
        clock: _effectiveClock,
      );
      await activeRepo.putProfile(defaultProfile);
      await activeRepo.setActiveProfileId(defaultProfile.id);
    }
    return activeRepo.allProfiles;
  }

  /// Retrieves a campaign profile by ID through the repository port.
  Future<CampaignProfile?> getProfile(String id) async {
    return repo.getProfile(id);
  }

  /// Gets the currently active campaign profile through the repository port.
  Future<CampaignProfile?> getActiveProfile() async {
    return repo.getActiveProfile();
  }

  /// Creates and activates a fresh campaign profile via [ICampaignRepository.putProfile].
  Future<CampaignProfile> createProfile({
    required String name,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) async {
    final activeRepo = repo;
    final newProfile = CampaignProfile.defaultProfile(
      name: name,
      edition: edition,
      nodeId: _effectiveNodeId,
      clock: _effectiveClock,
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
    return repo.updateProfile(id, transform);
  }

  /// Saves a campaign profile directly to the repository via [ICampaignRepository.putProfile].
  Future<void> putProfile(CampaignProfile profile) async {
    await repo.putProfile(profile);
  }

  /// Updates the active campaign profile via serialized [ICampaignRepository.updateProfile].
  Future<void> updateActiveProfile(
    CampaignProfile Function(CampaignProfile current) updater,
  ) async {
    final activeRepo = repo;
    var activeId = activeRepo.activeProfileId;
    if (activeId == null) {
      await loadAllProfiles();
      activeId = activeRepo.activeProfileId;
    }
    if (activeId != null) {
      await activeRepo.updateProfile(activeId, updater);
    }
  }

  /// Immediate save delegating to [putProfile].
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await putProfile(profile);
  }

  /// Switches active profile pointer on the repository.
  Future<void> switchProfile(String profileId) async {
    await repo.setActiveProfileId(profileId);
  }

  /// Sets the active campaign profile ID on the repository.
  Future<void> setActiveProfileId(String id) => switchProfile(id);

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId, [String? newName]) async {
    _checkRepoSubscription();
    final activeRepo = repo;
    CampaignProfile? source = activeRepo.allProfiles.where((p) => p.id == profileId).firstOrNull;
    if (source == null) {
      final all = await loadAllProfiles();
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

    final timestamp = _effectiveClock.nextTimestamp();

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
    _checkRepoSubscription();
    final activeRepo = repo;
    await activeRepo.deleteProfile(profileId);
    if (activeRepo.allProfiles.isEmpty) {
      final fresh = CampaignProfile.defaultProfile(
        nodeId: _effectiveNodeId,
        clock: _effectiveClock,
      );
      await activeRepo.putProfile(fresh);
      await activeRepo.setActiveProfileId(fresh.id);
    }
    try {
      final store = _blobStore ?? _blobStoreProvider?.call();
      if (store != null) {
        await store.releaseCampaign(profileId);
      }
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
    final activeRepo = _repoOverride;
    if (activeRepo == null) return;
    _checkRepoSubscription();
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
        await repo.updateProfile(profile.id, (current) {
          final updatedLog = [event, ...current.changeLog];
          return current.copyWith(changeLog: updatedLog);
        });
      }
    }
  }

  /// Clears in-memory subscriptions for isolated testing.
  void clearCacheForTesting() {
    _instance._activeProfileSub?.cancel();
    _instance._activeProfileSub = null;
    _instance._allProfilesSub?.cancel();
    _instance._allProfilesSub = null;
    _instance._allSubscribedRepo = null;
    _instance._ensureSubscribed();
  }
}
