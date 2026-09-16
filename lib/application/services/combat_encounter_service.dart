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

    final updatedHp = character.resources.hitPoints.takeDamage(amount);
    final updated = character.copyWith(
      resources: character.resources.copyWith(
        hitPoints: updatedHp,
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
    bool isRevival = false,
  }) async {
    if (amount <= 0) return character;

    final effectiveMaxHp = maxHp ?? () {
      try {
        return CharacterEvaluationEngine.evaluate(character).maxHp;
      } catch (_) {
        return math.max(10, character.resources.currentHp);
      }
    }();

    final isDead = character.resources.deathSaveFailures >= 3;
    if (isDead && !isRevival) return character;

    final updatedHp = character.resources.hitPoints
        .copyWith(maxHp: effectiveMaxHp, isDead: isDead)
        .heal(amount, allowRevive: isRevival);

    final updated = character.copyWith(
      resources: character.resources.copyWith(
        hitPoints: updatedHp,
        deathSaveSuccesses: updatedHp.currentHp > 0 ? 0 : character.resources.deathSaveSuccesses,
        deathSaveFailures: updatedHp.currentHp > 0 ? 0 : character.resources.deathSaveFailures,
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
    final updatedHp = character.resources.hitPoints.setTempHp(tempHp);
    final updated = character.copyWith(
      resources: character.resources.copyWith(hitPoints: updatedHp),
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
      return delta < 0 ? m.applyDamage(delta.abs()) : m.applyHealing(delta);
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

  /// Advances turn pointer forward in active encounter participant list.
  List<EncounterParticipant> nextTurn(
    List<EncounterParticipant> participants, {
    required int currentRound,
    void Function(int newRound)? onNewRound,
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

  /// Reverses turn pointer backwards in active encounter participant list.
  List<EncounterParticipant> prevTurn(List<EncounterParticipant> participants) {
    if (participants.isEmpty) return participants;

    final activeIndex = participants.indexWhere((p) => p.isActiveTurn);
    final prevIndex = activeIndex <= 0 ? participants.length - 1 : activeIndex - 1;

    return participants.asMap().entries.map((entry) {
      return entry.value.copyWith(isActiveTurn: entry.key == prevIndex);
    }).toList();
  }

  /// Applies damage or healing to a specific [EncounterParticipant] in the active encounter.
  ///
  /// Under 5e RAW:
  /// - Dropping to 0 HP marks a participant as defeated/downed ([isDefeated] = true).
  /// - Massive damage that exceeds [maxHp] marks the participant as permanently dead ([isDead] = true).
  /// - Standard healing to a downed participant at 0 HP revives them ([isDefeated] = false).
  /// - A permanently dead participant cannot be healed unless [allowRevive] is explicitly true.
  List<EncounterParticipant> applyParticipantDamageOrHeal({
    required List<EncounterParticipant> participants,
    required String participantId,
    required int delta,
    bool allowRevive = false,
  }) {
    return participants.map((p) {
      if (p.participantId != participantId) return p;

      if (delta < 0) {
        final updatedHp = p.hitPoints.takeDamage(delta.abs());
        return p.copyWith(
          hitPoints: updatedHp,
          isDefeated: updatedHp.isDowned || updatedHp.isDead,
          isDead: updatedHp.isDead,
        );
      } else {
        if (p.hitPoints.isDead && !allowRevive) return p;

        final updatedHp = p.hitPoints.heal(delta, allowRevive: allowRevive);
        return p.copyWith(
          hitPoints: updatedHp,
          isDefeated: updatedHp.isDowned || updatedHp.isDead,
          isDead: updatedHp.isDead,
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
