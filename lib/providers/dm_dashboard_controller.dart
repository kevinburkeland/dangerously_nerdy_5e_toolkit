import 'package:flutter/foundation.dart';
import '../application/services/combat_encounter_service.dart';
import '../domain/ports/i_campaign_repository.dart';
import '../domain/ports/i_character_repository.dart';
import '../infrastructure/repositories/local_campaign_repository.dart';
import '../infrastructure/repositories/local_character_repository.dart';
import '../models/animated_object.dart';
import '../models/campaign_profile.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/character_models.dart';
import '../models/domain/session_graph_models.dart';
import '../models/party/party_purse.dart';
import '../services/persistence/campaign_profile_service.dart';
import '../services/persistence/character_persistence_service.dart';
import '../data/acl/character_telemetry_dto.dart';
import '../data/acl/character_telemetry_resolver.dart';

/// State management controller for DM Dashboard.
/// Refactored to depend on abstract Ports ([ICampaignRepository], [ICharacterRepository])
/// and Application Services ([CombatEncounterService]) in alignment with Hexagonal Architecture.
class DmDashboardController extends ChangeNotifier {
  final ICampaignRepository _campaignProfileService;
  final ICharacterRepository _characterPersistenceService;
  final CombatEncounterService _combatEncounterService;

  CampaignProfile? _activeProfile;
  List<CampaignProfile> _allProfiles = [];
  final Map<String, Character> _partyCharactersMap = {};
  final Map<String, CharacterTelemetryDto> _remoteTelemetryMap = {};
  final Map<String, ResolvedCharacterDisplay> _resolvedTelemetryMap = {};
  bool _isLoading = true;
  int _currentRound = 1;

  DmDashboardController({
    ICampaignRepository? campaignRepository,
    ICharacterRepository? characterRepository,
    CombatEncounterService? combatEncounterService,
    CampaignProfileService? campaignProfileService,
    CharacterPersistenceService? characterPersistenceService,
  })  : _campaignProfileService =
            campaignRepository ?? campaignProfileService ?? LocalCampaignRepository(),
        _characterPersistenceService =
            characterRepository ?? characterPersistenceService ?? LocalCharacterRepository(),
        _combatEncounterService = combatEncounterService ??
            CombatEncounterService(
              characterRepo: characterRepository ?? characterPersistenceService ?? LocalCharacterRepository(),
              campaignRepo: campaignRepository ?? campaignProfileService ?? LocalCampaignRepository(),
            );

  CombatEncounterService get combatEncounterService => _combatEncounterService;
  ICampaignRepository get campaignRepository => _campaignProfileService;
  ICharacterRepository get characterRepository => _characterPersistenceService;

  CampaignProfile? get activeProfile => _activeProfile;
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
  Future<void> updateRemoteTelemetry(Map<String, CharacterTelemetryDto> telemetry) async {
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
  Future<ResolvedCharacterDisplay?> getOrResolveCharacterDisplay(String characterId) async {
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
      _activeProfile?.roomState.activeMinions ?? const [];

  void setRound(int round) {
    _currentRound = round;
    notifyListeners();
  }

  /// Initial load of campaign profiles and relational party characters.
  Future<void> loadData({String? initialCampaignId}) async {
    _isLoading = true;
    notifyListeners();

    _allProfiles = await _campaignProfileService.loadAllProfiles();

    CampaignProfile? active;
    if (initialCampaignId != null) {
      final req = initialCampaignId.trim().toUpperCase();
      active = _allProfiles.where((p) {
            final pid = p.id.toUpperCase();
            final rcode = p.roomState.roomCode.toUpperCase();
            return pid == req || pid == 'CAMPAIGN_$req' || rcode == req;
          }).firstOrNull ??
          await _campaignProfileService.getActiveProfile();
    } else {
      active = await _campaignProfileService.getActiveProfile();
    }

    _activeProfile = active ?? (_allProfiles.isNotEmpty ? _allProfiles.first : CampaignProfile.defaultProfile());
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
    notifyListeners();
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
    notifyListeners();

    await _characterPersistenceService.saveCharacter(updatedChar);
  }

  /// Adds a new or existing character to the active campaign's party roster pointer list.
  Future<void> addCharacterToParty(Character character) async {
    if (_activeProfile == null) return;

    await _characterPersistenceService.saveCharacter(character);
    _partyCharactersMap[character.id.slug] = character;

    if (!_activeProfile!.partyCharacterIds.contains(character.id.slug)) {
      final updatedIds = List<String>.from(_activeProfile!.partyCharacterIds)
        ..add(character.id.slug);
      _activeProfile = _activeProfile!.copyWith(partyCharacterIds: updatedIds);
      await _campaignProfileService.saveProfileImmediate(_activeProfile!);
    }
    notifyListeners();
  }

  /// Reloads a single character from persistence (e.g. after being edited in CharacterSheetView)
  /// and updates the in-memory party map and UI.
  Future<void> reloadCharacter(String characterId) async {
    final updated = await _characterPersistenceService.getCharacter(characterId);
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

  /// Removes a character pointer from the active campaign's party roster.
  Future<void> removeCharacterFromParty(String characterId) async {
    if (_activeProfile == null) return;

    final updatedIds = List<String>.from(_activeProfile!.partyCharacterIds)
      ..remove(characterId);
    _activeProfile = _activeProfile!.copyWith(partyCharacterIds: updatedIds);
    _partyCharactersMap.remove(characterId);
    await _campaignProfileService.saveProfileImmediate(_activeProfile!);
    notifyListeners();
  }

  // --- Combat Minions & Summons in RoomNodeState ---

  /// Modifies an active minion's HP in [RoomNodeState].
  Future<void> modifyMinionHp(String minionId, int delta) async {
    if (_activeProfile == null) return;

    _activeProfile = await _combatEncounterService.modifyMinionHp(
      profile: _activeProfile!,
      minionId: minionId,
      delta: delta,
    );
    notifyListeners();
  }

  /// Adds a new animated object minion to [RoomNodeState].
  Future<void> addMinion(AnimatedObjectInstance minion) async {
    if (_activeProfile == null) return;

    _activeProfile = await _combatEncounterService.addMinion(
      profile: _activeProfile!,
      minion: minion,
    );
    notifyListeners();
  }

  /// Removes an animated object minion from [RoomNodeState].
  Future<void> removeMinion(String minionId) async {
    if (_activeProfile == null) return;

    _activeProfile = await _combatEncounterService.removeMinion(
      profile: _activeProfile!,
      minionId: minionId,
    );
    notifyListeners();
  }

  // --- Campaign Profile Operations ---

  /// Saves active profile notes and metadata.
  Future<void> updateNotes(String notesMarkdown, {bool immediate = false}) async {
    if (_activeProfile == null) return;
    _activeProfile = _activeProfile!.copyWith(
      notesMarkdown: notesMarkdown,
      lastPlayedAt: DateTime.now(),
    );
    if (immediate) {
      await _campaignProfileService.saveProfileImmediate(_activeProfile!);
    } else {
      await _campaignProfileService.saveProfile(_activeProfile!);
    }
  }

  /// Changes rules edition for active profile.
  Future<void> changeEdition(DmRulesEdition newEdition) async {
    if (_activeProfile == null || _activeProfile!.edition == newEdition) return;
    _activeProfile = _activeProfile!.copyWith(edition: newEdition);
    notifyListeners();
    await _campaignProfileService.saveProfileImmediate(_activeProfile!);
  }

  /// Toggles a pinned reference rule ID.
  Future<void> togglePinnedRule(String ruleId) async {
    if (_activeProfile == null) return;
    final set = Set<String>.from(_activeProfile!.pinnedRuleIds);
    if (set.contains(ruleId)) {
      set.remove(ruleId);
    } else {
      set.add(ruleId);
    }
    _activeProfile = _activeProfile!.copyWith(pinnedRuleIds: set);
    notifyListeners();
    await _campaignProfileService.saveProfile(_activeProfile!);
  }

  /// Shared party treasury / reserve purse for the active campaign.
  PartyPurse get partyPurse => _activeProfile?.partyPurse ?? const PartyPurse();

  /// Combined wealth across the campaign shared party purse and all linked character personal purses.
  PartyPurse get totalPartyWealth {
    var total = partyPurse;
    for (final char in partyCharacters) {
      total = total.add(char.purse);
    }
    return total;
  }

  /// Modifies coins in the active campaign's shared party treasury.
  Future<void> modifyPartyPurseCoin(String coinKey, int delta) async {
    if (_activeProfile == null) return;
    final curPurse = _activeProfile!.partyPurse;
    final newPurse = PartyPurse(
      cp: coinKey == 'cp' ? (curPurse.cp + delta).clamp(0, 9999999) : curPurse.cp,
      sp: coinKey == 'sp' ? (curPurse.sp + delta).clamp(0, 9999999) : curPurse.sp,
      ep: coinKey == 'ep' ? (curPurse.ep + delta).clamp(0, 9999999) : curPurse.ep,
      gp: coinKey == 'gp' ? (curPurse.gp + delta).clamp(0, 9999999) : curPurse.gp,
      pp: coinKey == 'pp' ? (curPurse.pp + delta).clamp(0, 9999999) : curPurse.pp,
    );
    _activeProfile = _activeProfile!.copyWith(partyPurse: newPurse);
    notifyListeners();
    await _campaignProfileService.saveProfileImmediate(_activeProfile!);
  }

  /// Backward-compatible alias for [modifyPartyPurseCoin].
  Future<void> modifyPurseCoin(String coinKey, int delta) =>
      modifyPartyPurseCoin(coinKey, delta);

  /// Modifies coins in a specific linked character's personal coin purse.
  Future<void> modifyCharacterPurseCoin(String characterId, String coinKey, int delta) async {
    final char = _partyCharactersMap[characterId];
    if (char == null) return;

    final curPurse = char.purse;
    final newPurse = PartyPurse(
      cp: coinKey == 'cp' ? (curPurse.cp + delta).clamp(0, 9999999) : curPurse.cp,
      sp: coinKey == 'sp' ? (curPurse.sp + delta).clamp(0, 9999999) : curPurse.sp,
      ep: coinKey == 'ep' ? (curPurse.ep + delta).clamp(0, 9999999) : curPurse.ep,
      gp: coinKey == 'gp' ? (curPurse.gp + delta).clamp(0, 9999999) : curPurse.gp,
      pp: coinKey == 'pp' ? (curPurse.pp + delta).clamp(0, 9999999) : curPurse.pp,
    );
    final updated = char.copyWith(purse: newPurse);
    _partyCharactersMap[characterId] = updated;
    notifyListeners();
    await _characterPersistenceService.saveCharacter(updated);
  }

  /// Sets or updates a linked character's personal coin purse directly.
  Future<void> updateCharacterPurse(String characterId, PartyPurse newPurse) async {
    final char = _partyCharactersMap[characterId];
    if (char == null) return;

    final updated = char.copyWith(purse: newPurse);
    _partyCharactersMap[characterId] = updated;
    notifyListeners();
    await _characterPersistenceService.saveCharacter(updated);
  }

  /// Updates room state (encounter participants, descriptions, links).
  Future<void> updateRoomState(RoomNodeState roomState, {bool immediate = false}) async {
    if (_activeProfile == null) return;
    _activeProfile = _activeProfile!.copyWith(roomState: roomState);
    notifyListeners();
    if (immediate) {
      await _campaignProfileService.saveProfileImmediate(_activeProfile!);
    } else {
      await _campaignProfileService.saveProfile(_activeProfile!);
    }
  }
}
