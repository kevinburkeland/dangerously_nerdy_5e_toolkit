import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/models/campaign_profile.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';

import '../../infrastructure/di/injection_container.dart';
import '../../infrastructure/repositories/campaign_storage_migration.dart';
import '../party/campaign_registry_service.dart';
import '../../models/dm_screen_data.dart';
import '../../models/party/party_event.dart';

/// Centralized presentation/application facade over [ICampaignRepository].
///
/// Keeps UI compatibility and [ChangeNotifier] reactivity while delegating
/// all record reads, writes, and active selection directly to the DI-registered
/// single-owner [ICampaignRepository].
class CampaignProfileService extends ChangeNotifier {
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
    _ensureSubscribed();
  }

  ReplicaId? _replicaId;
  StatefulHlcClock? _clock;

  StreamSubscription<CampaignProfile?>? _activeProfileSub;
  StreamSubscription<List<CampaignProfile>>? _allProfilesSub;

  void _ensureSubscribed() {
    if (_allProfilesSub != null) return;
    if (sl.isRegistered<ICampaignRepository>()) {
      final repo = sl<ICampaignRepository>();
      _activeProfileSub = repo.watchActiveProfile().listen((_) {
        notifyListeners();
      });
      _allProfilesSub = repo.watchAllProfiles().listen((_) {
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

  ICampaignRepository? _allSubscribedRepo;

  void _checkRepoSubscription() {
    if (!sl.isRegistered<ICampaignRepository>()) return;
    final currentRepo = sl<ICampaignRepository>();
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
    if (sl.isRegistered<StatefulHlcClock>()) {
      return sl<StatefulHlcClock>().replicaId.value;
    }
    if (_replicaId != null) return _replicaId!.value;
    if (sl.isRegistered<ReplicaId>()) {
      return sl<ReplicaId>().value;
    }
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

  String? get activeProfileId {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().activeProfileId;
  }

  CampaignProfile? get activeProfile {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().activeProfile;
  }

  List<CampaignProfile> get allProfiles {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().allProfiles;
  }

  /// Loads all campaign profiles from the underlying repository,
  /// executing registry adoption for unmapped campaigns, and returns the list.
  Future<List<CampaignProfile>> loadAllProfiles() async {
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    await repo.loadAllProfiles();
    final regService = sl.isRegistered<CampaignRegistryService>()
        ? sl<CampaignRegistryService>()
        : null;
    await CampaignStorageMigration.adoptRegistryMemberships(
      repo,
      clock: _effectiveClock,
      nodeId: _effectiveNodeId,
      registryService: regService,
    );
    if (repo.allProfiles.isEmpty) {
      final defaultProfile = CampaignProfile.defaultProfile(
        nodeId: _effectiveNodeId,
        clock: _effectiveClock,
      );
      await repo.putProfile(defaultProfile);
      await repo.setActiveProfileId(defaultProfile.id);
    }
    return repo.allProfiles;
  }

  /// Retrieves a campaign profile by ID through the repository port.
  Future<CampaignProfile?> getProfile(String id) async {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().getProfile(id);
  }

  /// Gets the currently active campaign profile through the repository port.
  Future<CampaignProfile?> getActiveProfile() async {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().getActiveProfile();
  }

  /// Creates and activates a fresh campaign profile via [ICampaignRepository.putProfile].
  Future<CampaignProfile> createProfile({
    required String name,
    DmRulesEdition edition = DmRulesEdition.v2024,
  }) async {
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    final newProfile = CampaignProfile.defaultProfile(
      name: name,
      edition: edition,
      nodeId: _effectiveNodeId,
      clock: _effectiveClock,
    );
    await repo.putProfile(newProfile);
    await repo.setActiveProfileId(newProfile.id);
    return newProfile;
  }

  /// Updates a campaign profile by ID using the serialized [ICampaignRepository.updateProfile].
  Future<CampaignProfile> updateProfile(
    String id,
    CampaignProfile Function(CampaignProfile current) transform,
  ) async {
    _checkRepoSubscription();
    return sl<ICampaignRepository>().updateProfile(id, transform);
  }

  /// Saves a campaign profile directly to the repository via [ICampaignRepository.putProfile].
  Future<void> putProfile(CampaignProfile profile) async {
    _checkRepoSubscription();
    await sl<ICampaignRepository>().putProfile(profile);
  }

  /// Updates the active campaign profile via serialized [ICampaignRepository.updateProfile].
  Future<void> updateActiveProfile(
    CampaignProfile Function(CampaignProfile current) updater,
  ) async {
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    var activeId = repo.activeProfileId;
    if (activeId == null) {
      await loadAllProfiles();
      activeId = repo.activeProfileId;
    }
    if (activeId != null) {
      await repo.updateProfile(activeId, updater);
    }
  }

  /// Immediate save delegating to [putProfile].
  Future<void> saveProfileImmediate(CampaignProfile profile) async {
    await putProfile(profile);
  }

  /// Switches active profile pointer on the repository.
  Future<void> switchProfile(String profileId) async {
    _checkRepoSubscription();
    await sl<ICampaignRepository>().setActiveProfileId(profileId);
  }

  /// Sets the active campaign profile ID on the repository.
  Future<void> setActiveProfileId(String id) => switchProfile(id);

  /// Clones an existing campaign profile with an isolated ID and custom title.
  Future<CampaignProfile> cloneProfile(String profileId, [String? newName]) async {
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    CampaignProfile? source = repo.allProfiles.where((p) => p.id == profileId).firstOrNull;
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
      roomState: source.roomState.copyWith(
        roomId: 'room_$newId',
        title: '$targetName - Staging Area',
        titleTimestamp: timestamp,
      ),
    );

    await repo.putProfile(cloned);
    await repo.setActiveProfileId(cloned.id);
    return cloned;
  }

  /// Deletes a campaign profile by ID via the repository port.
  ///
  /// If the deleted profile was active, switches to another profile or creates
  /// a fresh default profile if no campaigns remain.
  Future<void> deleteProfile(String profileId) async {
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    await repo.deleteProfile(profileId);
    if (repo.allProfiles.isEmpty) {
      final fresh = CampaignProfile.defaultProfile(
        nodeId: _effectiveNodeId,
        clock: _effectiveClock,
      );
      await repo.putProfile(fresh);
      await repo.setActiveProfileId(fresh.id);
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
    if (!sl.isRegistered<ICampaignRepository>()) return;
    _checkRepoSubscription();
    final repo = sl<ICampaignRepository>();
    final profiles = repo.allProfiles;

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
    resetForTesting();
  }
}
