import 'dart:math' as math;
import '../../domain/models/campaign_profile.dart';
import '../../domain/models/animated_object.dart';
import '../../domain/ports/i_campaign_repository.dart';
import '../../domain/ports/i_character_repository.dart';
import '../../models/domain/character_models.dart';
import '../../models/domain/session_graph_models.dart';
import '../../services/rules/character_evaluation_engine.dart';

/// Application Service orchestrating combat encounters, HP modifications,
/// minion damage routing, and initiative turn tracking across domain entities and repositories.
class CombatEncounterService {
  final ICharacterRepository characterRepo;
  final ICampaignRepository campaignRepo;

  CombatEncounterService({
    required this.characterRepo,
    required this.campaignRepo,
  });

  // ==========================================
  // Character Vitals & Damage Routing
  // ==========================================

  /// Applies damage to a [Character], absorbing with Temporary HP first (5e RAW),
  /// persists the change via [characterRepo], and returns the updated entity.
  Future<Character> applyCharacterDamage({
    required Character character,
    required int amount,
  }) async {
    if (amount <= 0) return character;

    final curHp = character.resources.currentHp;
    final curTemp = character.resources.tempHp;

    int newHp = curHp;
    int newTemp = curTemp;

    if (curTemp > 0) {
      if (amount <= curTemp) {
        newTemp = curTemp - amount;
      } else {
        final remainingDamage = amount - curTemp;
        newTemp = 0;
        newHp = math.max(0, curHp - remainingDamage);
      }
    } else {
      newHp = math.max(0, curHp - amount);
    }

    final updated = character.copyWith(
      resources: character.resources.copyWith(
        currentHp: newHp,
        tempHp: newTemp,
      ),
    );

    await characterRepo.saveCharacter(updated);
    return updated;
  }

  /// Applies healing to a [Character], clamping to [maxHp],
  /// persists the change via [characterRepo], and returns the updated entity.
  Future<Character> applyCharacterHealing({
    required Character character,
    required int amount,
    int? maxHp,
  }) async {
    if (amount <= 0) return character;

    final curHp = character.resources.currentHp;
    final effectiveMaxHp = maxHp ?? () {
      try {
        return CharacterEvaluationEngine.evaluate(character).maxHp;
      } catch (_) {
        return math.max(10, curHp);
      }
    }();
    final newHp = math.min(effectiveMaxHp, curHp + amount);

    final updated = character.copyWith(
      resources: character.resources.copyWith(
        currentHp: newHp,
      ),
    );

    await characterRepo.saveCharacter(updated);
    return updated;
  }

  /// Modifies a [Character]'s HP by [delta] (positive for healing, negative for damage).
  Future<Character> modifyCharacterHp({
    required Character character,
    required int delta,
    int? maxHp,
  }) async {
    if (delta < 0) {
      return applyCharacterDamage(character: character, amount: delta.abs());
    } else if (delta > 0) {
      return applyCharacterHealing(character: character, amount: delta, maxHp: maxHp);
    }
    return character;
  }

  /// Sets temporary hit points directly on a [Character], persists, and returns the updated entity.
  Future<Character> setCharacterTempHp({
    required Character character,
    required int tempHp,
  }) async {
    final clampedTemp = math.max(0, tempHp);
    final updated = character.copyWith(
      resources: character.resources.copyWith(tempHp: clampedTemp),
    );
    await characterRepo.saveCharacter(updated);
    return updated;
  }

  // ==========================================
  // Minions & Summons in Campaign Profile
  // ==========================================

  /// Modifies an active minion's HP within [CampaignProfile.roomState.activeMinions].
  Future<CampaignProfile> modifyMinionHp({
    required CampaignProfile profile,
    required String minionId,
    required int delta,
  }) async {
    final minions = profile.roomState.activeMinions.map((m) {
      if (m.id != minionId) return m;
      if (delta < 0) {
        m.takeDamage(delta.abs());
      } else {
        m.heal(delta);
      }
      return m;
    }).toList();

    final updatedRoom = profile.roomState.copyWith(activeMinions: minions);
    final updatedProfile = profile.copyWith(roomState: updatedRoom);

    await campaignRepo.saveProfile(updatedProfile);
    return updatedProfile;
  }

  /// Adds an animated object summon/minion to [CampaignProfile.roomState.activeMinions].
  Future<CampaignProfile> addMinion({
    required CampaignProfile profile,
    required AnimatedObjectInstance minion,
  }) async {
    final minions = List<AnimatedObjectInstance>.from(profile.roomState.activeMinions)..add(minion);
    final updatedRoom = profile.roomState.copyWith(activeMinions: minions);
    final updatedProfile = profile.copyWith(roomState: updatedRoom);

    await campaignRepo.saveProfile(updatedProfile);
    return updatedProfile;
  }

  /// Removes an animated object summon/minion from [CampaignProfile.roomState.activeMinions].
  Future<CampaignProfile> removeMinion({
    required CampaignProfile profile,
    required String minionId,
  }) async {
    final minions = List<AnimatedObjectInstance>.from(profile.roomState.activeMinions)
      ..removeWhere((m) => m.id == minionId);
    final updatedRoom = profile.roomState.copyWith(activeMinions: minions);
    final updatedProfile = profile.copyWith(roomState: updatedRoom);

    await campaignRepo.saveProfile(updatedProfile);
    return updatedProfile;
  }

  // ==========================================
  // Turn Tracker & Encounter Mechanics
  // ==========================================

  /// Advances the initiative turn to the next active participant.
  List<EncounterParticipant> nextTurn(
    List<EncounterParticipant> participants, {
    void Function(int nextRound)? onNewRound,
    int currentRound = 1,
  }) {
    if (participants.isEmpty) return participants;

    final activeIndex = participants.indexWhere((p) => p.isActiveTurn);
    final nextIndex = (activeIndex + 1) % participants.length;

    if (nextIndex == 0 && activeIndex != -1) {
      onNewRound?.call(currentRound + 1);
    }

    return participants.asMap().entries.map((entry) {
      return entry.value.copyWith(isActiveTurn: entry.key == nextIndex);
    }).toList();
  }

  /// Moves the initiative turn back to the previous participant.
  List<EncounterParticipant> prevTurn(List<EncounterParticipant> participants) {
    if (participants.isEmpty) return participants;

    final activeIndex = participants.indexWhere((p) => p.isActiveTurn);
    final prevIndex = activeIndex <= 0 ? participants.length - 1 : activeIndex - 1;

    return participants.asMap().entries.map((entry) {
      return entry.value.copyWith(isActiveTurn: entry.key == prevIndex);
    }).toList();
  }

  /// Applies damage or healing to a specific [EncounterParticipant] in the active encounter.
  List<EncounterParticipant> applyParticipantDamageOrHeal({
    required List<EncounterParticipant> participants,
    required String participantId,
    required int delta,
  }) {
    return participants.map((p) {
      if (p.participantId != participantId) return p;

      if (delta < 0) {
        int dmg = delta.abs();
        int curTemp = p.tempHp;
        int curHp = p.currentHp;

        if (curTemp > 0) {
          if (dmg <= curTemp) {
            curTemp -= dmg;
            dmg = 0;
          } else {
            dmg -= curTemp;
            curTemp = 0;
          }
        }

        curHp = (curHp - dmg).clamp(0, p.maxHp);
        final isDefeated = curHp <= 0;
        return p.copyWith(
          currentHp: curHp,
          tempHp: curTemp,
          isDefeated: isDefeated,
        );
      } else {
        final curHp = (p.currentHp + delta).clamp(0, p.maxHp);
        return p.copyWith(
          currentHp: curHp,
          isDefeated: curHp <= 0,
        );
      }
    }).toList();
  }

  /// Toggles an active condition (e.g. 'poisoned', 'prone') on an encounter participant.
  List<EncounterParticipant> toggleParticipantCondition({
    required List<EncounterParticipant> participants,
    required String participantId,
    required String conditionName,
  }) {
    return participants.map((p) {
      if (p.participantId != participantId) return p;
      final conditions = List<String>.from(p.activeConditions);
      if (conditions.contains(conditionName)) {
        conditions.remove(conditionName);
      } else {
        conditions.add(conditionName);
      }
      return p.copyWith(activeConditions: conditions);
    }).toList();
  }

  /// Updates encounter participants in a campaign profile and persists the change.
  Future<CampaignProfile> updateEncounterParticipants({
    required CampaignProfile profile,
    required List<EncounterParticipant> encounter,
  }) async {
    final updatedRoom = profile.roomState.copyWith(activeEncounter: encounter);
    final updatedProfile = profile.copyWith(roomState: updatedRoom);
    await campaignRepo.saveProfileImmediate(updatedProfile);
    return updatedProfile;
  }
}
