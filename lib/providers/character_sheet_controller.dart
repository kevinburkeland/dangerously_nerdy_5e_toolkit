import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/dice_roll.dart';
import '../models/dm_screen_data.dart' show DmRulesEdition;
import '../models/domain/character_models.dart';
import '../models/domain/entity_reference.dart';
import '../models/domain/spell_monster_equipment.dart';
import '../models/room_roll.dart';
import '../services/dice_room_service.dart';
import '../services/persistence/character_persistence_service.dart';
import '../services/persistence/debounced_storage_service.dart';
import '../services/repository/reference_resolver.dart';
import '../services/rules/character_evaluation_engine.dart';
import '../services/rules/character_progression_engine.dart';
import '../utils/secure_random.dart';

/// State controller for managing an active Character sheet, handling live stat recalculation,
/// resource management, equipment/attunement toggles, condition management, and debounced persistence.
class CharacterSheetController extends ChangeNotifier {
  final CharacterPersistenceService _persistenceService;
  final DebouncedStorageService _debouncedStorage;
  final ReferenceResolver? _resolver;

  late Character _character;
  late EvaluatedCharacterStats _stats;
  bool _isSaving = false;

  CharacterSheetController({
    required Character character,
    CharacterPersistenceService? persistenceService,
    DebouncedStorageService? debouncedStorage,
    ReferenceResolver? resolver,
  })  : _character = character,
        _persistenceService = persistenceService ?? CharacterPersistenceService(),
        _debouncedStorage = debouncedStorage ?? DebouncedStorageService(),
        _resolver = resolver {
    _recalculateStats();
  }

  Character get character => _character;
  EvaluatedCharacterStats get stats => _stats;
  bool get isSaving => _isSaving;
  DmRulesEdition get rulesEdition => _character.rulesEdition;

  bool get hasInspiration =>
      _character.resources.hasHeroicInspiration ||
      _character.customProperties['hasInspiration'] == true;

  String get _debounceTaskKey => 'character_sheet_persist_${_character.id.slug}';

  /// Recalculates stats synchronously.
  void _recalculateStats() {
    _stats = CharacterEvaluationEngine.evaluate(
      _character,
      resolver: _resolver,
    );
  }

  /// Sets a new active character, flushes any pending writes for the previous character, and re-evaluates stats.
  /// If [persist] is true (default), immediately saves the updated character to storage.
  Future<void> setCharacter(Character newCharacter, {bool persist = true}) async {
    await flush();
    _character = newCharacter;
    _recalculateStats();
    notifyListeners();
    if (persist) {
      await _persistImmediate();
    }
  }

  /// Switches active ruleset edition (2014 vs 2024) and triggers live re-evaluation.
  Future<void> setRulesEdition(DmRulesEdition edition) async {
    if (_character.rulesEdition == edition) return;
    _character = _character.copyWith(rulesEdition: edition);
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Advances character level via [CharacterProgressionEngine] and immediately flushes persistence.
  Future<void> applyLevelUp(LevelUpRequest request) async {
    final updated = CharacterProgressionEngine.applyLevelUp(
      _character,
      request,
      resolver: _resolver,
    );
    _character = updated;
    _recalculateStats();
    notifyListeners();
    await _persistImmediate();
  }

  /// Schedules debounced disk persistence to prevent main-isolate I/O thrashing.
  void _schedulePersist({Duration duration = const Duration(milliseconds: 350)}) {
    _debouncedStorage.scheduleWrite(
      _debounceTaskKey,
      () => _persistImmediate(),
      duration: duration,
    );
  }

  /// Flushes pending persistence immediately.
  Future<void> flush() async {
    await _debouncedStorage.flushKey(_debounceTaskKey);
  }

  /// Persists the active character immediately.
  Future<void> _persistImmediate() async {
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
          equippedSlot: nextEquipped ? (item.equippedSlot ?? EquipmentSlot.wondrous) : null,
        );
      }
      return item;
    }).toList();

    _character = _character.copyWith(inventory: updatedInventory);
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Explicitly sets or toggles the attuned state of an item instance, validating capacity against [effectiveMaxAttunementSlots].
  /// Returns `true` if successful, or `false` if the attunement limit is exceeded.
  Future<bool> toggleAttunement(String instanceId, bool isAttuned) async {
    final targetItem = _character.inventory.firstWhere(
      (item) => item.instanceId == instanceId,
      orElse: () => throw ArgumentError('Item instance $instanceId not found'),
    );

    if (isAttuned && !targetItem.isAttuned) {
      final currentAttunedCount = _character.inventory.where((i) => i.isAttuned).length;
      final maxSlots = _stats.effectiveMaxAttunementSlots;
      if (currentAttunedCount >= maxSlots) {
        return false;
      }
    }

    final updatedInventory = _character.inventory.map((item) {
      if (item.instanceId == instanceId) {
        return item.copyWith(isAttuned: isAttuned);
      }
      return item;
    }).toList();

    _character = _character.copyWith(inventory: updatedInventory);
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Toggles the attuned state of an item instance, strictly respecting the dynamic attunement limit.
  /// Returns `true` if successful, or `false` if the attunement limit prevents attuning.
  Future<bool> toggleAttuneItem(String instanceId) async {
    final targetItem = _character.inventory.firstWhere(
      (item) => item.instanceId == instanceId,
      orElse: () => throw ArgumentError('Item instance $instanceId not found'),
    );
    return toggleAttunement(instanceId, !targetItem.isAttuned);
  }

  /// Applies damage to the character.
  /// Damage strictly depletes temporary HP before reducing current HP, clamping at 0.
  Future<void> takeDamage(int amount) async {
    if (amount <= 0) return;
    final curHp = _character.resources.currentHp;
    final curTemp = _character.resources.tempHp;

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

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        currentHp: newHp,
        tempHp: newTemp,
      ),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Heals the character by [amount], clamping at [stats.maxHp].
  Future<void> heal(int amount) async {
    if (amount <= 0) return;
    final curHp = _character.resources.currentHp;
    final maxHp = _stats.maxHp;
    final newHp = math.min(maxHp, curHp + amount);

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        currentHp: newHp,
      ),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Modifies current HP by [delta] (positive for healing, negative for damage).
  /// Damage is absorbed by temporary HP first before depleting current HP.
  Future<void> modifyHp(int delta) async {
    if (delta < 0) {
      await takeDamage(delta.abs());
    } else if (delta > 0) {
      await heal(delta);
    }
  }

  /// Sets temporary hit points directly.
  Future<void> setTempHp(int tempHp) async {
    final clampedTemp = math.max(0, tempHp);
    _character = _character.copyWith(
      resources: _character.resources.copyWith(tempHp: clampedTemp),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Sets or updates death save counters (clamped 0 to 3).
  Future<void> setDeathSaves({int? successes, int? failures}) async {
    final curSuccesses = _character.resources.deathSaveSuccesses;
    final curFailures = _character.resources.deathSaveFailures;
    final newSuccesses = (successes ?? curSuccesses).clamp(0, 3);
    final newFailures = (failures ?? curFailures).clamp(0, 3);

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        deathSaveSuccesses: newSuccesses,
        deathSaveFailures: newFailures,
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  /// Sets or updates exhaustion level (0 to 10).
  Future<void> setExhaustionLevel(int level) async {
    final clampedLevel = level.clamp(0, 10);
    final conditions = List<CharacterCondition>.from(_character.conditions)
      ..removeWhere((c) => c.conditionName.toLowerCase() == 'exhaustion');

    if (clampedLevel > 0) {
      conditions.add(CharacterCondition(
        conditionName: 'exhaustion',
        parameters: {'level': clampedLevel},
      ));
    }

    _character = _character.copyWith(
      resources: _character.resources.copyWith(exhaustionLevel: clampedLevel),
      conditions: conditions,
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Adds a condition to the character.
  Future<void> addCondition(CharacterCondition condition) async {
    final conditions = List<CharacterCondition>.from(_character.conditions)
      ..removeWhere((c) => c.conditionName.toLowerCase() == condition.conditionName.toLowerCase())
      ..add(condition);

    _character = _character.copyWith(conditions: conditions);
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Removes a condition from the character.
  Future<void> removeCondition(String conditionName) async {
    final conditions = List<CharacterCondition>.from(_character.conditions)
      ..removeWhere((c) => c.conditionName.toLowerCase() == conditionName.toLowerCase());

    _character = _character.copyWith(conditions: conditions);
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Adds a language to the character if not already present.
  Future<void> addLanguage(String language) async {
    final clean = language.trim();
    if (clean.isEmpty) return;
    final langs = List<String>.from(_character.languages);
    if (!langs.any((l) => l.toLowerCase() == clean.toLowerCase())) {
      langs.add(clean);
      _character = _character.copyWith(languages: langs);
      notifyListeners();
      _schedulePersist();
    }
  }

  /// Removes a language from the character.
  Future<void> removeLanguage(String language) async {
    final clean = language.trim().toLowerCase();
    final langs = List<String>.from(_character.languages)
      ..removeWhere((l) => l.toLowerCase() == clean);
    _character = _character.copyWith(languages: langs);
    notifyListeners();
    _schedulePersist();
  }

  /// Overwrites the full language list of the character.
  Future<void> setLanguages(List<String> languages) async {
    final seen = <String>{};
    final unique = <String>[];
    for (final l in languages) {
      final clean = l.trim();
      if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
        unique.add(clean);
      }
    }
    _character = _character.copyWith(languages: unique);
    notifyListeners();
    _schedulePersist();
  }

  /// Adds a tool proficiency to the character if not already present.
  Future<void> addToolProficiency(String tool) async {
    final clean = tool.trim();
    if (clean.isEmpty) return;
    final tools = List<String>.from(_character.toolProficiencies);
    if (!tools.any((t) => t.toLowerCase() == clean.toLowerCase())) {
      tools.add(clean);
      _character = _character.copyWith(toolProficiencies: tools);
      notifyListeners();
      _schedulePersist();
    }
  }

  /// Removes a tool proficiency from the character.
  Future<void> removeToolProficiency(String tool) async {
    final clean = tool.trim().toLowerCase();
    final tools = List<String>.from(_character.toolProficiencies)
      ..removeWhere((t) => t.toLowerCase() == clean);
    _character = _character.copyWith(toolProficiencies: tools);
    notifyListeners();
    _schedulePersist();
  }

  /// Overwrites the full tool proficiency list of the character.
  Future<void> setToolProficiencies(List<String> tools) async {
    final seen = <String>{};
    final unique = <String>[];
    for (final t in tools) {
      final clean = t.trim();
      if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
        unique.add(clean);
      }
    }
    _character = _character.copyWith(toolProficiencies: unique);
    notifyListeners();
    _schedulePersist();
  }

  /// Spends a hit die of the given type (e.g., "d8", "d10").
  Future<bool> expendHitDie(String dieType) async {
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);
    final count = currentDice[dieType] ?? 0;
    if (count <= 0) return false;

    currentDice[dieType] = count - 1;
    _character = _character.copyWith(
      resources: _character.resources.copyWith(currentHitDice: currentDice),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
    return true;
  }

  /// Recovers a hit die of the given type up to class max.
  Future<void> recoverHitDie(String dieType) async {
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);
    final count = currentDice[dieType] ?? 0;
    currentDice[dieType] = count + 1;

    _character = _character.copyWith(
      resources: _character.resources.copyWith(currentHitDice: currentDice),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
  }

  /// Sets heroic inspiration explicitly.
  Future<void> setHeroicInspiration(bool value) async {
    final customProps = Map<String, dynamic>.from(_character.customProperties);
    customProps['hasInspiration'] = value;

    _character = _character.copyWith(
      resources: _character.resources.copyWith(hasHeroicInspiration: value),
      customProperties: customProps,
    );
    notifyListeners();
    _schedulePersist();
  }

  /// Toggles heroic inspiration status.
  Future<void> toggleInspiration() async {
    final current = hasInspiration;
    await setHeroicInspiration(!current);
  }

  /// Applies a Short Rest: spends the provided hit dice, applies rolled healing via [heal],
  /// recovers Pact Magic slots, and persists state.
  Future<void> applyShortRest({
    required Map<String, int> hitDiceSpent,
    required int healingRolled,
  }) async {
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);
    for (final entry in hitDiceSpent.entries) {
      final cur = currentDice[entry.key] ?? 0;
      currentDice[entry.key] = math.max(0, cur - entry.value);
    }

    // Pact Magic slots recharge on short rest (RAW 5e Warlock mechanics)
    final spellSlots = _character.resources.spellSlots;
    final updatedSpellSlots = spellSlots.copyWith(
      pactMagicCurrent: spellSlots.pactMagicMax,
    );

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        currentHitDice: currentDice,
        spellSlots: updatedSpellSlots,
      ),
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();

    if (healingRolled > 0) {
      await heal(healingRolled);
    }
  }

  /// Applies a Long Rest:
  /// - Resets HP to max
  /// - Resets Temp HP to 0
  /// - Clears death save successes and failures
  /// - Restores all spell slots & pact slots
  /// - Reduces exhaustion level by 1
  /// - Restores spent hit dice up to half of character's total level (min 1 if any spent)
  Future<void> applyLongRest() async {
    final maxHp = _stats.maxHp;
    final spellSlots = _character.resources.spellSlots;
    final restoredSlots = Map<int, int>.from(spellSlots.maxSlots);
    final restoredSpellSlots = spellSlots.copyWith(
      currentSlots: restoredSlots,
      pactMagicCurrent: spellSlots.pactMagicMax,
    );

    // Calculate max hit dice pool per die type
    final maxHitDice = <String, int>{};
    int totalCharacterLevel = 0;
    for (final c in _character.progression.classes) {
      maxHitDice[c.hitDie] = (maxHitDice[c.hitDie] ?? 0) + c.level;
      totalCharacterLevel += c.level;
    }
    if (totalCharacterLevel == 0) {
      totalCharacterLevel = math.max(1, _character.totalLevel);
    }

    // Regain spent hit dice up to half the character's total level (minimum 1)
    int diceToRegain = math.max(1, (totalCharacterLevel / 2).floor());
    final currentDice = Map<String, int>.from(_character.resources.currentHitDice);

    // If currentHitDice was empty, initialize from max
    for (final entry in maxHitDice.entries) {
      if (!currentDice.containsKey(entry.key)) {
        currentDice[entry.key] = entry.value;
      }
    }

    for (final entry in maxHitDice.entries) {
      if (diceToRegain <= 0) break;
      final die = entry.key;
      final maxCount = entry.value;
      final curCount = currentDice[die] ?? maxCount;
      final spent = maxCount - curCount;
      if (spent > 0) {
        final recoverAmount = math.min(spent, diceToRegain);
        currentDice[die] = curCount + recoverAmount;
        diceToRegain -= recoverAmount;
      }
    }

    // Reduce exhaustion by 1
    final curExhaustion = _character.resources.exhaustionLevel;
    final newExhaustion = math.max(0, curExhaustion - 1);
    final conditions = List<CharacterCondition>.from(_character.conditions)
      ..removeWhere((c) => c.conditionName.toLowerCase() == 'exhaustion');
    if (newExhaustion > 0) {
      conditions.add(CharacterCondition(
        conditionName: 'exhaustion',
        parameters: {'level': newExhaustion},
      ));
    }

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        currentHp: maxHp,
        tempHp: 0,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        exhaustionLevel: newExhaustion,
        currentHitDice: currentDice,
        spellSlots: restoredSpellSlots,
      ),
      conditions: conditions,
    );
    _recalculateStats();
    notifyListeners();
    _schedulePersist();
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

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        spellSlots: pool.copyWith(currentSlots: curMap),
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  /// Consumes or recovers a Pact Magic spell slot.
  Future<void> togglePactSlot(bool isExpending) async {
    final pool = _character.resources.spellSlots;
    final cur = pool.pactMagicCurrent;
    final max = pool.pactMagicMax;

    int newCur = cur;
    if (isExpending && cur > 0) {
      newCur = cur - 1;
    } else if (!isExpending && cur < max) {
      newCur = cur + 1;
    }

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        spellSlots: pool.copyWith(pactMagicCurrent: newCur),
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  /// Restores all spell slots (including Pact Magic) to maximum (Long Rest).
  Future<void> restoreAllSpellSlots() async {
    final pool = _character.resources.spellSlots;
    final restoredMap = Map<int, int>.from(pool.maxSlots);

    _character = _character.copyWith(
      resources: _character.resources.copyWith(
        spellSlots: pool.copyWith(
          currentSlots: restoredMap,
          pactMagicCurrent: pool.pactMagicMax,
        ),
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  /// Toggles whether a known spell is currently prepared.
  Future<void> togglePreparedSpell(EntityReference<Spell> spellRef) async {
    final curPrep = List<EntityReference<Spell>>.from(_character.spellsPrepared);
    final isAlreadyPrep = curPrep.any((s) => s.slug == spellRef.slug);

    if (isAlreadyPrep) {
      curPrep.removeWhere((s) => s.slug == spellRef.slug);
    } else {
      curPrep.add(spellRef);
    }

    _character = _character.copyWith(spellsPrepared: curPrep);
    notifyListeners();
    _schedulePersist();
  }

  /// Adds a new spell or cantrip to the character sheet.
  Future<void> addSpell(
    EntityReference<Spell> spellRef, {
    bool isCantrip = false,
    bool isPrepared = false,
  }) async {
    if (isCantrip) {
      final curCantrips = List<EntityReference<Spell>>.from(_character.cantrips);
      if (!curCantrips.any((c) => c.slug == spellRef.slug)) {
        curCantrips.add(spellRef);
        _character = _character.copyWith(cantrips: curCantrips);
      }
    } else {
      final curKnown = List<EntityReference<Spell>>.from(_character.spellsKnown);
      if (!curKnown.any((s) => s.slug == spellRef.slug)) {
        curKnown.add(spellRef);
      }
      final curPrep = List<EntityReference<Spell>>.from(_character.spellsPrepared);
      if (isPrepared && !curPrep.any((s) => s.slug == spellRef.slug)) {
        curPrep.add(spellRef);
      }
      _character = _character.copyWith(
        spellsKnown: curKnown,
        spellsPrepared: curPrep,
      );
    }
    notifyListeners();
    _schedulePersist();
  }

  /// Removes a spell or cantrip from the character sheet.
  Future<void> removeSpell(
    EntityReference<Spell> spellRef, {
    bool isCantrip = false,
  }) async {
    if (isCantrip) {
      final curCantrips = List<EntityReference<Spell>>.from(_character.cantrips)
        ..removeWhere((c) => c.slug == spellRef.slug);
      _character = _character.copyWith(cantrips: curCantrips);
    } else {
      final curKnown = List<EntityReference<Spell>>.from(_character.spellsKnown)
        ..removeWhere((s) => s.slug == spellRef.slug);
      final curPrep = List<EntityReference<Spell>>.from(_character.spellsPrepared)
        ..removeWhere((s) => s.slug == spellRef.slug);
      _character = _character.copyWith(
        spellsKnown: curKnown,
        spellsPrepared: curPrep,
      );
    }
    notifyListeners();
    _schedulePersist();
  }

  /// Evaluates whether the character has a specific capability flag enabled from any selected feature option, feat, class feature, or custom properties.
  bool hasCapabilityFlag(String flagKey) => _character.hasCapabilityFlag(flagKey);

  /// True if character has Agonizing Blast invocation enabled (adds CHA modifier to Eldritch Blast damage).
  bool get hasAgonizingBlast => hasCapabilityFlag('eldritchBlastChaDamage');

  /// True if character has Jack of All Trades (adds half proficiency bonus to untrained ability checks/initiative).
  bool get hasJackOfAllTrades => hasCapabilityFlag('jackOfAllTrades');

  /// True if character has Medium Armor Master feat (raises medium armor DEX cap from +2 to +3).
  bool get hasMediumArmorMaster => hasCapabilityFlag('mediumArmorMaster');

  /// Executes a spell attack roll: 1d20 + stats.spellAttackBonus.
  DiceRollResult rollSpellAttack(Spell spell) {
    final bonus = stats.spellAttackBonus;
    final result = DiceRollResult.roll(
      dieType: DieType.d20,
      count: 1,
      modifier: bonus,
    );

    // Broadcast roll to dice room if active
    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;
    if (activeRoom != null) {
      final playerName = _character.name.isNotEmpty ? _character.name : 'Player';
      final roomRoll = RoomRoll(
        id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: playerName,
        formulaString: '${spell.name} (Spell Attack)',
        total: result.total,
        individualRolls: result.individualRolls,
        details: ['1d20(${result.individualRolls.first}) + $bonus = ${result.total}'],
        isCrit: result.isCrit,
        isFumble: result.isFumble,
        timestamp: DateTime.now(),
      );
      roomService.broadcastRoll(roomRoll);
    }

    return result;
  }

  /// Executes a spell damage roll, dynamically routing capability flags
  /// (e.g. adding Charisma modifier to Eldritch Blast if 'eldritchBlastChaDamage' is active).
  DiceRollResult rollSpellDamage(Spell spell, {int? slotLevel}) {
    final slug = spell.id.slug.toLowerCase().replaceAll('_', '-');
    final cleanSlug = slug.startsWith('spell-') ? slug.substring(6) : slug;
    final isEldritchBlast = cleanSlug == 'eldritch-blast' || spell.name.toLowerCase() == 'eldritch blast';

    // Parse or retrieve damage dice
    String formula = '1d10';
    if (spell.damageMath.isNotEmpty) {
      formula = spell.damageMath.first.diceFormula;
    } else if (spell.customProperties['rollFormula'] != null) {
      formula = spell.customProperties['rollFormula'].toString();
    }

    // Determine base dice count and die type
    int count = 1;
    DieType dieType = DieType.d10;
    int customSides = 10;

    final match = RegExp(r'^(\d+)d(\d+)').firstMatch(formula.trim());
    if (match != null) {
      count = int.tryParse(match.group(1)!) ?? 1;
      final sides = int.tryParse(match.group(2)!) ?? 10;
      dieType = DieType.values.firstWhere(
        (d) => d.sides == sides && d != DieType.custom,
        orElse: () => DieType.custom,
      );
      customSides = sides;
    }

    int modifier = 0;
    if (isEldritchBlast && (hasAgonizingBlast || hasCapabilityFlag('eldritchBlastChaDamage') || hasCapabilityFlag('agonizing_blast'))) {
      final chaMod = _character.effectiveAbilityScores.getModifier(AbilityType.charisma);
      modifier += chaMod;
    }

    final result = DiceRollResult.rollPool(
      diceEntries: [
        DiceEntry(
          dieType: dieType,
          count: count,
          customSides: customSides,
        ),
      ],
      modifier: modifier,
    );

    // Broadcast roll to dice room if active
    final roomService = DiceRoomService();
    final activeRoom = roomService.activeRoomCode;
    if (activeRoom != null) {
      final playerName = _character.name.isNotEmpty ? _character.name : 'Player';
      final roomRoll = RoomRoll(
        id: 'roll-${DateTime.now().millisecondsSinceEpoch}-${secureRandom.nextInt(9999)}',
        roomCode: activeRoom,
        playerName: playerName,
        formulaString: '${spell.name} (Damage: ${result.formulaString})',
        total: result.total,
        individualRolls: result.individualRolls,
        details: [
          '${result.diceEntries.first.formulaString}(${result.individualRolls.join(", ")})'
              '${modifier != 0 ? (modifier > 0 ? " + $modifier" : " - ${modifier.abs()}") : ""} = ${result.total}'
        ],
        isCrit: result.isCrit,
        isFumble: result.isFumble,
        timestamp: DateTime.now(),
      );
      roomService.broadcastRoll(roomRoll);
    }

    return result;
  }

  @override
  void dispose() {
    flush();
    super.dispose();
  }
}
