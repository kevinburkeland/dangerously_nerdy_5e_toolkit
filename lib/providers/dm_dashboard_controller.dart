import 'dart:async';
import 'package:flutter/foundation.dart';
import '../application/services/combat_encounter_service.dart';
import 'package:vtt_engine_core/rules/i_combat_resolver.dart';
import 'package:vtt_engine_core/ports/i_campaign_repository.dart';
import 'package:vtt_engine_core/ports/i_character_repository.dart';
import 'package:vtt_engine_core/crdt/replica_id.dart';
import 'package:vtt_engine_core/crdt/stateful_hlc_clock.dart';
import 'package:vtt_engine_core/crdt/crdt_lww_register.dart';
import '../models/animated_object.dart';
import '../models/campaign_profile.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/session_graph_models.dart';
import '../models/party/party_purse.dart';
import '../services/persistence/character_persistence_service.dart';
import '../infrastructure/dtos/character_telemetry_dto.dart';
import '../infrastructure/resolvers/character_telemetry_resolver.dart';
import '../infrastructure/di/injection_container.dart';
import '../application/services/room_connection_telemetry.dart';
import '../application/services/room_sync_orchestrator.dart';
import '../services/logging_service.dart';
import '../services/party/party_room_service.dart';

/// State management controller for DM Dashboard.
/// Refactored to depend on abstract Ports ([ICampaignRepository], [ICharacterRepository])
/// and Application Services ([CombatEncounterService]) in alignment with Hexagonal Architecture.
class DmDashboardController extends ChangeNotifier {
  final ICampaignRepository _campaignProfileService;
  final ICharacterRepository<Character> _characterPersistenceService;
  final CombatEncounterService _combatEncounterService;
  final RoomSyncOrchestrator? _roomSyncOrchestrator;
  final ReplicaId _replicaId;
  final StatefulHlcClock _clock;
  StreamSubscription<CampaignProfile?>? _activeProfileSub;

  CampaignProfile? _activeProfile;
  List<CampaignProfile> _allProfiles = [];
  final Map<String, Character> _partyCharactersMap = {};
  final Map<String, CharacterTelemetryDto> _remoteTelemetryMap = {};
  final Map<String, ResolvedCharacterDisplay> _resolvedTelemetryMap = {};
  bool _isLoading = true;
  int _currentRound = 1;

  factory DmDashboardController({
    required ReplicaId replicaId,
    StatefulHlcClock? clock,
    ICampaignRepository? campaignRepository,
    ICharacterRepository<Character>? characterRepository,
    CombatEncounterService? combatEncounterService,
    CharacterPersistenceService? characterPersistenceService,
    RoomSyncOrchestrator? roomSyncOrchestrator,
  }) {
    final effectiveClock = clock ??
        (sl.isRegistered<StatefulHlcClock>()
            ? sl<StatefulHlcClock>()
            : throw StateError(
                'Authoritative StatefulHlcClock is required for DmDashboardController. '
                'Pass clock explicitly or register StatefulHlcClock in DI.',
              ));
    return DmDashboardController._internal(
      replicaId: replicaId,
      clock: effectiveClock,
      campaignRepository: campaignRepository,
      characterRepository: characterRepository,
      combatEncounterService: combatEncounterService,
      characterPersistenceService: characterPersistenceService,
      roomSyncOrchestrator: roomSyncOrchestrator,
    );
  }

  DmDashboardController._internal({
    required ReplicaId replicaId,
    required StatefulHlcClock clock,
    ICampaignRepository? campaignRepository,
    ICharacterRepository<Character>? characterRepository,
    CombatEncounterService? combatEncounterService,
    CharacterPersistenceService? characterPersistenceService,
    RoomSyncOrchestrator? roomSyncOrchestrator,
  })  : _replicaId = replicaId,
        _clock = clock,
        _campaignProfileService = campaignRepository ??
            (sl.isRegistered<ICampaignRepository>()
                ? sl<ICampaignRepository>()
                : throw StateError(
                    'Authoritative ICampaignRepository is required for DmDashboardController. '
                    'Pass campaignRepository explicitly or register ICampaignRepository in DI.',
                  )),
        _characterPersistenceService = characterRepository ??
            characterPersistenceService ??
            (sl.isRegistered<ICharacterRepository<Character>>()
                ? sl<ICharacterRepository<Character>>()
                : (sl.isRegistered<ICharacterRepository>()
                    ? sl<ICharacterRepository>() as ICharacterRepository<Character>
                    : CharacterPersistenceService())),
        _combatEncounterService = combatEncounterService ??
            (sl.isRegistered<CombatEncounterService>()
                ? sl<CombatEncounterService>()
                : CombatEncounterService(
                    characterRepo: characterRepository ??
                        characterPersistenceService ??
                        (sl.isRegistered<ICharacterRepository>()
                            ? sl<ICharacterRepository>()
                            : CharacterPersistenceService()),
                    campaignRepo: campaignRepository ??
                        (sl.isRegistered<ICampaignRepository>()
                            ? sl<ICampaignRepository>()
                            : throw StateError(
                                'Authoritative ICampaignRepository is required for CombatEncounterService.',
                              )),
                    combatResolver: sl.isRegistered<ICombatResolver>()
                        ? sl<ICombatResolver>()
                        : const Dnd5eCombatResolver(),
                    replicaId: replicaId,
                    clock: clock,
                  )),
        _roomSyncOrchestrator = roomSyncOrchestrator ??
            (sl.isRegistered<RoomSyncOrchestrator>()
                ? sl<RoomSyncOrchestrator>()
                : null) {
    if (_clock.replicaId != _replicaId) {
      throw ArgumentError(
        'DmDashboardController writer identity mismatch: '
        'replicaId ($_replicaId) does not match clock.replicaId (${_clock.replicaId}).',
      );
    }
    _activeProfileSub = _campaignProfileService.watchActiveProfile().listen((profile) {
      if (profile != null) {
        if (_activeProfile == null || _activeProfile!.id == profile.id) {
          _activeProfile = profile;
          notifyListeners();
        }
      }
    });
  }

  @override
  void dispose() {
    _activeProfileSub?.cancel();
    super.dispose();
  }

  ReplicaId get replicaId => _replicaId;
  String get nodeId => _replicaId.value;
  StatefulHlcClock get clock => _clock;

  CombatEncounterService get combatEncounterService => _combatEncounterService;
  ICampaignRepository get campaignRepository => _campaignProfileService;
  ICharacterRepository get characterRepository => _characterPersistenceService;
  RoomSyncOrchestrator? get roomSyncOrchestrator => _roomSyncOrchestrator;
  Stream<RoomConnectionTelemetry>? get telemetryStream =>
      _roomSyncOrchestrator?.watchTelemetry();

  CampaignProfile? get activeProfile {
    if (_activeProfile != null) {
      final repoActive = _campaignProfileService.activeProfile;
      if (repoActive != null && repoActive.id == _activeProfile!.id) {
        return repoActive;
      }
    }
    return _activeProfile ?? _campaignProfileService.activeProfile;
  }
  List<CampaignProfile> get allProfiles => _allProfiles;
  Map<String, Character> get partyCharactersMap =>
      Map.unmodifiable(_partyCharactersMap);
  Map<String, CharacterTelemetryDto> get remoteTelemetryMap =>
      Map.unmodifiable(_remoteTelemetryMap);
  Map<String, ResolvedCharacterDisplay> get resolvedTelemetryMap =>
      Map.unmodifiable(_resolvedTelemetryMap);
  bool get isLoading => _isLoading;
  int get currentRound => _currentRound;

  /// Ingests ephemeral character telemetry from remote party members and resolves display models.
  Future<void> updateRemoteTelemetry(
      Map<String, CharacterTelemetryDto> telemetry) async {
    _remoteTelemetryMap.clear();
    _remoteTelemetryMap.addAll(telemetry);
    for (final entry in telemetry.entries) {
      final resolved = await CharacterTelemetryResolver.resolve(entry.value);
      _resolvedTelemetryMap[entry.key] = resolved;
    }
    notifyListeners();
  }

  /// Updates or resolves telemetry for a single character.
  Future<void> updateSingleRemoteTelemetry(CharacterTelemetryDto dto) async {
    _remoteTelemetryMap[dto.id] = dto;
    final resolved = await CharacterTelemetryResolver.resolve(dto);
    _resolvedTelemetryMap[dto.id] = resolved;
    notifyListeners();
  }

  /// Resolves display data for a character ID, checking remote telemetry first,
  /// then falling back to local character entity conversion.
  Future<ResolvedCharacterDisplay?> getOrResolveCharacterDisplay(
      String characterId) async {
    if (_resolvedTelemetryMap.containsKey(characterId)) {
      return _resolvedTelemetryMap[characterId];
    }
    final localChar = _partyCharactersMap[characterId];
    if (localChar != null) {
      final dto = localChar.toTelemetryDto();
      final resolved = await CharacterTelemetryResolver.resolve(dto);
      _resolvedTelemetryMap[characterId] = resolved;
      return resolved;
    }
    return null;
  }

  /// Ordered party characters corresponding to active profile's [partyCharacterIds].
  List<Character> get partyCharacters {
    if (_activeProfile == null) return const [];
    return _activeProfile!.partyCharacterIds
        .map((id) => _partyCharactersMap[id])
        .whereType<Character>()
        .toList();
  }

  /// Active combat minions and summons isolated in [RoomNodeState].
  List<AnimatedObjectInstance> get activeMinions =>
      _activeProfile?.roomState.activeMinions.activeValues.whereType<AnimatedObjectInstance>().toList() ?? const [];

  void setRound(int round) {
    _currentRound = round;
    notifyListeners();
  }

  /// Initial load of campaign profiles and relational party characters.
  Future<void> loadData({String? initialCampaignId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _allProfiles = await _campaignProfileService.loadAllProfiles();
    } catch (e, st) {
      LoggingService().logNonFatal(
        e,
        st,
        reason: 'Failed to load campaign profiles in DmDashboardController.loadData',
      );
      _allProfiles = [];
    }

    CampaignProfile? active;
    if (initialCampaignId != null) {
      final req = initialCampaignId.trim().toUpperCase();
      active = _allProfiles.where((p) {
            final pid = p.id.toUpperCase();
            final rcode = p.roomState.roomCode.toUpperCase();
            return pid == req || pid == 'CAMPAIGN_$req' || rcode == req;
          }).firstOrNull;
      if (active == null) {
        try {
          active = await _campaignProfileService.getActiveProfile();
        } catch (_) {}
      }
    } else {
      try {
        active = await _campaignProfileService.getActiveProfile();
      } catch (_) {}
    }

    _activeProfile = active ??
        (_allProfiles.isNotEmpty
            ? _allProfiles.first
            : CampaignProfile.defaultProfile(nodeId: _replicaId.value, clock: _clock));
    if (_activeProfile != null &&
        _activeProfile!.notesRegister.timestamp.physicalTime > 0) {
      _clock.observeTrustedHistory(_activeProfile!.notesRegister.timestamp);
    }
    await _loadPartyCharacters();

    _isLoading = false;
    notifyListeners();
  }

  /// Switches active campaign profile and resolves relational characters.
  Future<void> switchProfile(String profileId) async {
    await _campaignProfileService.setActiveProfileId(profileId);
    _activeProfile = await _campaignProfileService.getActiveProfile();
    _allProfiles = _campaignProfileService.allProfiles;
    await _loadPartyCharacters();
    notifyListeners();
  }

  /// Internal helper querying relational characters from [CharacterPersistenceService].
  Future<void> _loadPartyCharacters() async {
    _partyCharactersMap.clear();
    if (_activeProfile == null || _activeProfile!.partyCharacterIds.isEmpty) {
      return;
    }
    final chars = await _characterPersistenceService
        .getCharactersByIds(_activeProfile!.partyCharacterIds);
    for (final c in chars) {
      _partyCharactersMap[c.id.slug] = c;
    }
  }

  // --- Relational Character State Mutations (O(1), CampaignProfile is NOT re-serialized) ---

  /// Modifies a character's HP and persists ONLY to [CharacterPersistenceService].
  /// Does NOT trigger re-serialization or disk writes of [CampaignProfile].
  Future<void> modifyCharacterHp(String characterId, int delta) async {
    final char = _partyCharactersMap[characterId];
    if (char == null) return;

    final updatedChar = await _combatEncounterService.modifyCharacterHp(
      character: char,
      delta: delta,
    );

    _partyCharactersMap[characterId] = updatedChar;
    _resolvedTelemetryMap.remove(characterId);
    notifyListeners();

    if (_activeProfile != null) {
      try {
        await PartyRoomService().updateCharacterTelemetry(
          roomCode: _activeProfile!.id,
          character: updatedChar,
        );
      } catch (_) {}
    }
  }

  /// Toggles a character's spell slot and persists ONLY to [CharacterPersistenceService].
  /// Does NOT trigger re-serialization or disk writes of [CampaignProfile].
  Future<void> toggleSpellSlot(String characterId, int level) async {
    final char = _partyCharactersMap[characterId];
    if (char == null) return;

    final maxSlots = char.resources.spellSlots.maxSlots[level] ?? 0;
    if (maxSlots <= 0) return;

    final current = char.resources.spellSlots.currentSlots[level] ?? maxSlots;
    final next = current <= 0 ? maxSlots : current - 1;

    final updatedCur =
        Map<int, int>.from(char.resources.spellSlots.currentSlots);
    updatedCur[level] = next;

    final updatedPool = char.resources.copyWith(
      spellSlots: char.resources.spellSlots.copyWith(currentSlots: updatedCur),
    );
    final updatedChar = char.copyWith(resources: updatedPool);

    _partyCharactersMap[characterId] = updatedChar;
    _resolvedTelemetryMap.remove(characterId);
    notifyListeners();

    await _characterPersistenceService.saveCharacter(updatedChar);

    if (_activeProfile != null) {
      try {
        await PartyRoomService().updateCharacterTelemetry(
          roomCode: _activeProfile!.id,
          character: updatedChar,
        );
      } catch (_) {}
    }
  }

  /// Adds a new or existing character to the active campaign's party roster pointer list.
  Future<void> addCharacterToParty(Character character) async {
    final targetId = activeProfile?.id;
    if (targetId == null) return;

    await _characterPersistenceService.saveCharacter(character);

    final nowHlc = _clock.nextTimestamp();
    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      if (current.partyCharacterIds.contains(character.id.slug)) {
        return current;
      }
      final updatedRoster = current.partyRoster.add(
        character.id.slug,
        character.id.slug,
        nowHlc,
      );
      return current.copyWith(partyRoster: updatedRoster);
    });
    _partyCharactersMap[character.id.slug] = character;
    _activeProfile = updated;
    notifyListeners();
  }

  /// Reloads a single character from persistence (e.g. after being edited in CharacterSheetView)
  /// and updates the in-memory party map and UI.
  Future<void> reloadCharacter(String characterId) async {
    final updated =
        await _characterPersistenceService.getCharacter(characterId);
    if (updated != null) {
      _partyCharactersMap[characterId] = updated;
      notifyListeners();
    }
  }

  /// Directly updates a character in memory and persists it to [CharacterPersistenceService].
  Future<void> updateCharacter(Character character) async {
    await _characterPersistenceService.saveCharacter(character);
    _partyCharactersMap[character.id.slug] = character;
    notifyListeners();
  }

  /// Removes a character pointer from the active campaign's party roster,
  /// authoring a typed [PartyEvent] with the character's canonical entity ID.
  Future<void> removeCharacterFromParty(String characterId) async {
    final targetId = activeProfile?.id;
    if (targetId == null) return;

    final nowHlc = _clock.nextTimestamp();
    final charName = _partyCharactersMap[characterId]?.name ?? characterId;
    final removalEvent = PartyEvent(
      id: 'evt_remove_${characterId}_${DateTime.now().toUtc().millisecondsSinceEpoch}',
      roomCode: activeProfile!.roomState.roomCode,
      type: 'characterRemove',
      playerName: charName,
      details: 'Removed from party roster',
      timestamp: DateTime.now().toUtc(),
      entityId: characterId,
    );

    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      final updatedRoster = current.partyRoster.remove(
        characterId,
        nowHlc,
      );
      final updatedChangeLog = [...current.changeLog, removalEvent];
      return current.copyWith(
        partyRoster: updatedRoster,
        changeLog: updatedChangeLog,
      );
    });
    _partyCharactersMap.remove(characterId);
    _activeProfile = updated;
    notifyListeners();
  }

  // --- Combat Minions & Summons in RoomNodeState ---

  /// Modifies an active minion's HP in [RoomNodeState].
  Future<void> modifyMinionHp(String minionId, int delta) async {
    final target = activeProfile;
    if (target == null) return;

    _activeProfile = await _combatEncounterService.modifyMinionHp(
      profile: target,
      minionId: minionId,
      delta: delta,
    );
    notifyListeners();
  }

  /// Adds a new animated object minion to [RoomNodeState].
  Future<void> addMinion(AnimatedObjectInstance minion) async {
    final target = activeProfile;
    if (target == null) return;

    _activeProfile = await _combatEncounterService.addMinion(
      profile: target,
      minion: minion,
    );
    notifyListeners();
  }

  /// Removes an animated object minion from [RoomNodeState].
  Future<void> removeMinion(String minionId) async {
    final target = activeProfile;
    if (target == null) return;

    _activeProfile = await _combatEncounterService.removeMinion(
      profile: target,
      minionId: minionId,
    );
    notifyListeners();
  }

  /// Updates active encounter participants in [RoomNodeState] via [CombatEncounterService].
  Future<void> updateEncounter(List<EncounterParticipant> encounter) async {
    final target = activeProfile;
    if (target == null) return;
    _activeProfile = await _combatEncounterService.updateEncounterParticipants(
      profile: target,
      encounter: encounter,
    );
    notifyListeners();
  }

  // --- Campaign Profile Operations ---

  /// Saves active profile notes and metadata.
  Future<void> updateNotes(String notesMarkdown,
      {bool immediate = false}) async {
    final targetId = activeProfile?.id;
    if (targetId == null) return;
    final ts = _clock.nextTimestamp();
    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      return current.copyWith(
        notesRegister: CrdtLwwRegister<String>(
          value: notesMarkdown,
          timestamp: ts,
        ),
        lastPlayedAt: DateTime.now(),
      );
    });
    _activeProfile = updated;
    notifyListeners();
  }

  /// Changes rules edition for active profile.
  Future<void> changeEdition(DmRulesEdition newEdition) async {
    final targetId = activeProfile?.id;
    if (targetId == null) return;
    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      if (current.edition == newEdition) return current;
      return current.copyWith(edition: newEdition);
    });
    _activeProfile = updated;
    notifyListeners();
  }

  /// Toggles a pinned reference rule ID.
  Future<void> togglePinnedRule(String ruleId) async {
    final targetId = activeProfile?.id;
    if (targetId == null) return;
    final nowHlc = _clock.nextTimestamp();
    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      final currentRules = current.pinnedRules;
      final updatedRules = currentRules.activeValues.contains(ruleId)
          ? currentRules.remove(ruleId, nowHlc)
          : currentRules.add(ruleId, ruleId, nowHlc);
      return current.copyWith(pinnedRules: updatedRules);
    });
    _activeProfile = updated;
    notifyListeners();
  }

  /// Shared party treasury / reserve purse for the active campaign.
  PartyPurse get partyPurse => activeProfile?.partyPurse ?? const PartyPurse.empty();

  /// Combined wealth across the campaign shared party purse and all linked character personal purses.
  PartyPurse get totalPartyWealth {
    var total = partyPurse;
    for (final char in partyCharacters) {
      total = total.add(char.purse, replicaId: _replicaId);
    }
    return total;
  }

  /// Modifies coins in the active campaign's shared party treasury.
  Future<void> modifyPartyPurseCoin(String coinKey, int delta) async {
    final targetId = activeProfile?.id;
    if (targetId == null || delta == 0) return;
    final updated = await _campaignProfileService.updateProfile(targetId, (current) {
      final curPurse = current.partyPurse;
      final newPurse = curPurse.modifyCoin(coinKey, delta, replicaId: _replicaId);
      return current.copyWith(partyPurse: newPurse);
    });
    _activeProfile = updated;
    notifyListeners();
  }

  /// Backward-compatible alias for [modifyPartyPurseCoin].
  Future<void> modifyPurseCoin(String coinKey, int delta) =>
      modifyPartyPurseCoin(coinKey, delta);

  /// Modifies coins in a specific linked character's personal coin purse.
  Future<void> modifyCharacterPurseCoin(
      String characterId, String coinKey, int delta) async {
    final char = _partyCharactersMap[characterId];
    if (char == null || delta == 0) return;

    final curPurse = char.purse;
    final newPurse = curPurse.modifyCoin(coinKey, delta, replicaId: _replicaId);
    final updated = char.copyWith(purse: newPurse);
    _partyCharactersMap[characterId] = updated;
    _resolvedTelemetryMap.remove(characterId);
    notifyListeners();
    await _characterPersistenceService.saveCharacter(updated);

    if (activeProfile != null) {
      try {
        await PartyRoomService().updateMemberPurse(
          roomCode: activeProfile!.id,
          characterName: updated.name,
          newPurse: updated.purse,
          performedBy: 'DM',
        );
      } catch (_) {}
    }
  }

  /// Sets or updates a linked character's personal coin purse directly.
  Future<void> updateCharacterPurse(
      String characterId, PartyPurse newPurse) async {
    final char = _partyCharactersMap[characterId];
    if (char == null) return;

    final updated = char.copyWith(purse: newPurse);
    _partyCharactersMap[characterId] = updated;
    _resolvedTelemetryMap.remove(characterId);
    notifyListeners();
    await _characterPersistenceService.saveCharacter(updated);

    if (activeProfile != null) {
      try {
        await PartyRoomService().updateMemberPurse(
          roomCode: activeProfile!.id,
          characterName: updated.name,
          newPurse: updated.purse,
          performedBy: 'DM',
        );
      } catch (_) {}
    }
  }
}
