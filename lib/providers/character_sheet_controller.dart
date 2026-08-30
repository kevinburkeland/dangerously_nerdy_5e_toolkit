import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/domain/character_models.dart';
import '../services/persistence/character_persistence_service.dart';
import '../services/repository/reference_resolver.dart';
import '../services/rules/character_evaluation_engine.dart';

/// State controller for managing an active Character sheet, handling live stat recalculation,
/// resource management, equipment/attunement toggles, and persistence.
class CharacterSheetController extends ChangeNotifier {
  final CharacterPersistenceService _persistenceService;
  final ReferenceResolver? _resolver;

  late Character _character;
  late EvaluatedCharacterStats _stats;
  bool _isSaving = false;

  CharacterSheetController({
    required Character character,
    CharacterPersistenceService? persistenceService,
    ReferenceResolver? resolver,
  })  : _character = character,
        _persistenceService = persistenceService ?? CharacterPersistenceService(),
        _resolver = resolver {
    _recalculateStats();
  }

  Character get character => _character;
  EvaluatedCharacterStats get stats => _stats;
  bool get isSaving => _isSaving;

  bool get hasInspiration => _character.customProperties['hasInspiration'] == true;

  /// Recalculates stats synchronously.
  void _recalculateStats() {
    _stats = CharacterEvaluationEngine.evaluate(
      _character,
      resolver: _resolver,
    );
  }

  /// Sets a new active character and re-evaluates stats.
  void setCharacter(Character newCharacter) {
    _character = newCharacter;
    _recalculateStats();
    notifyListeners();
  }

  /// Persists the active character asynchronously.
  Future<void> _persist() async {
    _isSaving = true;
    notifyListeners();
    try {
      await _persistenceService.saveCharacter(_character);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggles the equipped state of an inventory item instance.
  Future<void> toggleEquipItem(String instanceId) async {
    final updatedInventory = _character.inventory.map((item) {
      if (item.instanceId == instanceId) {
        final nextEquipped = !item.isEquipped;
        return item.copyWith(
          isEquipped: nextEquipped,
          // If unequipping and was equipped to a slot, clear or keep
          equippedSlot: nextEquipped ? (item.equippedSlot ?? EquipmentSlot.wondrous) : null,
        );
      }
      return item;
    }).toList();

    _character = _copyCharacterWith(inventory: updatedInventory);
    _recalculateStats();
    notifyListeners();
    await _persist();
  }

  /// Toggles the attuned state of an item instance, strictly respecting the dynamic attunement limit.
  /// Returns `true` if successful, or `false` if the attunement limit prevents attuning.
  Future<bool> toggleAttuneItem(String instanceId) async {
    final targetItem = _character.inventory.firstWhere(
      (item) => item.instanceId == instanceId,
      orElse: () => throw ArgumentError('Item with instanceId $instanceId not found'),
    );

    // If attempting to attune, verify attunement slot availability
    if (!targetItem.isAttuned) {
      if (_stats.attunedItemCount >= _stats.effectiveMaxAttunementSlots) {
        return false; // Limit reached
      }
    }

    final updatedInventory = _character.inventory.map((item) {
      if (item.instanceId == instanceId) {
        return item.copyWith(isAttuned: !item.isAttuned);
      }
      return item;
    }).toList();

    _character = _copyCharacterWith(inventory: updatedInventory);
    _recalculateStats();
    notifyListeners();
    await _persist();
    return true;
  }

  /// Modifies HP: damage (negative delta) absorbs from Temp HP first, then current HP.
  /// Healing (positive delta) adds to current HP (clamped to max HP).
  Future<void> modifyHp(int delta) async {
    final curHp = _character.resources.currentHp;
    final curTemp = _character.resources.tempHp;
    final maxHp = _stats.maxHp;

    int newHp = curHp;
    int newTemp = curTemp;

    if (delta < 0) {
      final damage = delta.abs();
      if (curTemp > 0) {
        if (damage <= curTemp) {
          newTemp = curTemp - damage;
        } else {
          final remainingDamage = damage - curTemp;
          newTemp = 0;
          newHp = math.max(0, curHp - remainingDamage);
        }
      } else {
        newHp = math.max(0, curHp - damage);
      }
    } else if (delta > 0) {
      newHp = math.min(maxHp, curHp + delta);
    }

    _character = _copyCharacterWith(
      resources: _character.resources.copyWith(
        currentHp: newHp,
        tempHp: newTemp,
      ),
    );
    _recalculateStats();
    notifyListeners();
    await _persist();
  }

  /// Sets temporary hit points directly.
  Future<void> setTempHp(int tempHp) async {
    final clampedTemp = math.max(0, tempHp);
    _character = _copyCharacterWith(
      resources: _character.resources.copyWith(tempHp: clampedTemp),
    );
    _recalculateStats();
    notifyListeners();
    await _persist();
  }

  /// Spends a hit die of the given type (e.g., "d8", "d10").
  Future<bool> expendHitDie(String dieType) async {
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);
    final count = currentDice[dieType] ?? 0;
    if (count <= 0) return false;

    currentDice[dieType] = count - 1;
    _character = _copyCharacterWith(
      resources: _character.resources.copyWith(currentHitDice: currentDice),
    );
    _recalculateStats();
    notifyListeners();
    await _persist();
    return true;
  }

  /// Recovers a hit die of the given type up to class max.
  Future<void> recoverHitDie(String dieType) async {
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);
    final count = currentDice[dieType] ?? 0;
    currentDice[dieType] = count + 1;

    _character = _copyCharacterWith(
      resources: _character.resources.copyWith(currentHitDice: currentDice),
    );
    _recalculateStats();
    notifyListeners();
    await _persist();
  }

  /// Toggles heroic inspiration status.
  Future<void> toggleInspiration() async {
    final customProps = Map<String, dynamic>.from(_character.customProperties);
    final current = customProps['hasInspiration'] == true;
    customProps['hasInspiration'] = !current;

    _character = _copyCharacterWith(customProperties: customProps);
    notifyListeners();
    await _persist();
  }

  /// Consumes or recovers a spell slot of a given level.
  Future<void> toggleSpellSlot(int level, bool isExpending) async {
    final pool = _character.resources.spellSlots;
    final curMap = Map<int, int>.from(pool.currentSlots);
    final maxMap = pool.maxSlots;

    final currentAvailable = curMap[level] ?? (maxMap[level] ?? 0);
    final maxAvailable = maxMap[level] ?? currentAvailable;

    if (isExpending && currentAvailable > 0) {
      curMap[level] = currentAvailable - 1;
    } else if (!isExpending && currentAvailable < maxAvailable) {
      curMap[level] = currentAvailable + 1;
    }

    _character = _copyCharacterWith(
      resources: _character.resources.copyWith(
        spellSlots: pool.copyWith(currentSlots: curMap),
      ),
    );
    notifyListeners();
    await _persist();
  }

  /// Helper to recreate a Character with updated fields since Character does not implement copyWith directly.
  Character _copyCharacterWith({
    String? name,
    CharacterResourcePool? resources,
    List<InventoryItemInstance>? inventory,
    Map<String, dynamic>? customProperties,
  }) {
    return Character(
      id: _character.id,
      name: name ?? _character.name,
      speciesRef: _character.speciesRef,
      backgroundRef: _character.backgroundRef,
      progression: _character.progression,
      baseScores: _character.baseScores,
      bonusScores: _character.bonusScores,
      skillProficiencies: _character.skillProficiencies,
      savingThrowProficiencies: _character.savingThrowProficiencies,
      toolProficiencies: _character.toolProficiencies,
      languages: _character.languages,
      inventory: inventory ?? _character.inventory,
      purse: _character.purse,
      cantrips: _character.cantrips,
      spellsKnown: _character.spellsKnown,
      spellsPrepared: _character.spellsPrepared,
      feats: _character.feats,
      resources: resources ?? _character.resources,
      conditions: _character.conditions,
      maxAttunementSlots: _character.maxAttunementSlots,
      baseSpeedFeet: _character.baseSpeedFeet,
      customProperties: customProperties ?? _character.customProperties,
    );
  }
}
