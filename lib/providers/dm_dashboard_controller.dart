import 'package:flutter/foundation.dart';
import '../models/animated_object.dart';
import '../models/campaign_profile.dart';
import '../models/dm_screen_data.dart';
import '../models/domain/character_models.dart';
import '../models/domain/session_graph_models.dart';
import '../models/party/party_purse.dart';
import '../services/persistence/campaign_profile_service.dart';
import '../services/persistence/character_persistence_service.dart';

/// State management controller for DM Dashboard.
/// Implements relational character loading via foreign key pointers (`partyCharacterIds`),
/// isolating high-frequency combat mutations (HP, spell slots) to O(1) character saves
/// without re-serializing heavy campaign metadata like `notesMarkdown`.
class DmDashboardController extends ChangeNotifier {
  final CampaignProfileService _campaignProfileService;
  final CharacterPersistenceService _characterPersistenceService;

  CampaignProfile? _activeProfile;
  List<CampaignProfile> _allProfiles = [];
  final Map<String, Character> _partyCharactersMap = {};
  bool _isLoading = true;
  int _currentRound = 1;

  DmDashboardController({
    CampaignProfileService? campaignProfileService,
    CharacterPersistenceService? characterPersistenceService,
  })  : _campaignProfileService =
            campaignProfileService ?? CampaignProfileService(),
        _characterPersistenceService =
            characterPersistenceService ?? CharacterPersistenceService();

  CampaignProfile? get activeProfile => _activeProfile;
  List<CampaignProfile> get allProfiles => _allProfiles;
  Map<String, Character> get partyCharactersMap =>
      Map.unmodifiable(_partyCharactersMap);
  bool get isLoading => _isLoading;
  int get currentRound => _currentRound;

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

    CampaignProfile active;
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

    _activeProfile = active;
    await _loadPartyCharacters();

    _isLoading = false;
    notifyListeners();
  }

  /// Switches active campaign profile and resolves relational characters.
  Future<void> switchProfile(String profileId) async {
    await _campaignProfileService.switchProfile(profileId);
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

    final curHp = (char.resources.currentHp + delta).clamp(0, 999);
    final updatedPool = char.resources.copyWith(currentHp: curHp);
    final updatedChar = char.copyWith(resources: updatedPool);

    _partyCharactersMap[characterId] = updatedChar;
    notifyListeners();

    // Persist only the single character entity
    await _characterPersistenceService.saveCharacter(updatedChar);
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

    final minions = _activeProfile!.roomState.activeMinions.map((m) {
      if (m.id != minionId) return m;
      if (delta < 0) {
        m.takeDamage(delta.abs());
      } else {
        m.heal(delta);
      }
      return m;
    }).toList();

    final updatedRoom =
        _activeProfile!.roomState.copyWith(activeMinions: minions);
    _activeProfile = _activeProfile!.copyWith(roomState: updatedRoom);
    notifyListeners();

    await _campaignProfileService.saveProfile(_activeProfile!);
  }

  /// Adds a new animated object minion to [RoomNodeState].
  Future<void> addMinion(AnimatedObjectInstance minion) async {
    if (_activeProfile == null) return;

    final minions =
        List<AnimatedObjectInstance>.from(_activeProfile!.roomState.activeMinions)
          ..add(minion);
    final updatedRoom =
        _activeProfile!.roomState.copyWith(activeMinions: minions);
    _activeProfile = _activeProfile!.copyWith(roomState: updatedRoom);
    notifyListeners();

    await _campaignProfileService.saveProfile(_activeProfile!);
  }

  /// Removes an animated object minion from [RoomNodeState].
  Future<void> removeMinion(String minionId) async {
    if (_activeProfile == null) return;

    final minions =
        List<AnimatedObjectInstance>.from(_activeProfile!.roomState.activeMinions)
          ..removeWhere((m) => m.id == minionId);
    final updatedRoom =
        _activeProfile!.roomState.copyWith(activeMinions: minions);
    _activeProfile = _activeProfile!.copyWith(roomState: updatedRoom);
    notifyListeners();

    await _campaignProfileService.saveProfile(_activeProfile!);
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

  /// Modifies coins in the active campaign or party's first character purse.
  Future<void> modifyPurseCoin(String coinKey, int delta) async {
    if (_activeProfile == null) return;

    // If characters exist, update the first character's purse
    if (partyCharacters.isNotEmpty) {
      final first = partyCharacters.first;
      final curPurse = first.purse;
      final newPurse = PartyPurse(
        cp: coinKey == 'cp' ? (curPurse.cp + delta).clamp(0, 999999) : curPurse.cp,
        sp: coinKey == 'sp' ? (curPurse.sp + delta).clamp(0, 999999) : curPurse.sp,
        ep: coinKey == 'ep' ? (curPurse.ep + delta).clamp(0, 999999) : curPurse.ep,
        gp: coinKey == 'gp' ? (curPurse.gp + delta).clamp(0, 999999) : curPurse.gp,
        pp: coinKey == 'pp' ? (curPurse.pp + delta).clamp(0, 999999) : curPurse.pp,
      );
      final updated = first.copyWith(purse: newPurse);
      _partyCharactersMap[first.id.slug] = updated;
      notifyListeners();
      await _characterPersistenceService.saveCharacter(updated);
    } else {
      final curPurse = _activeProfile!.partyPurse;
      final newPurse = PartyPurse(
        cp: coinKey == 'cp' ? (curPurse.cp + delta).clamp(0, 999999) : curPurse.cp,
        sp: coinKey == 'sp' ? (curPurse.sp + delta).clamp(0, 999999) : curPurse.sp,
        ep: coinKey == 'ep' ? (curPurse.ep + delta).clamp(0, 999999) : curPurse.ep,
        gp: coinKey == 'gp' ? (curPurse.gp + delta).clamp(0, 999999) : curPurse.gp,
        pp: coinKey == 'pp' ? (curPurse.pp + delta).clamp(0, 999999) : curPurse.pp,
      );
      _activeProfile = _activeProfile!.copyWith(partyPurse: newPurse);
      notifyListeners();
      await _campaignProfileService.saveProfile(_activeProfile!);
    }
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
