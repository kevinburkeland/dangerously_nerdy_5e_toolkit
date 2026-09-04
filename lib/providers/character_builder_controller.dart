import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/domain/character_models.dart';
import '../services/rules/character_factory.dart';

/// State manager for 5e Character Builder attribute generation, consumable resource pools,
/// and progression validation.
class CharacterBuilderController extends ChangeNotifier {
  String _abilityScoreMode = 'standard'; // 'standard', 'pointBuy', 'rolled', 'manual'
  String _rollMethod = 'standard_4d6'; // 'standard_4d6', 'classic_3d6_down', 'classic_3d6_nice', 'silly_d20'

  // Consumable Pool state
  List<int> _availableScores = [15, 14, 13, 12, 10, 8];
  final Map<AbilityType, int> _assignedScores = {};
  int? _selectedPoolScore;

  // Dice roll state
  List<int> _rolledPool = [];
  List<String> _rolledBreakdowns = [];

  // Point buy state
  AbilityScores _pointBuyScores = const AbilityScores(
    strength: 8,
    dexterity: 8,
    constitution: 8,
    intelligence: 8,
    wisdom: 8,
    charisma: 8,
  );

  // Manual entry state
  final Map<AbilityType, int> _manualScores = {
    AbilityType.strength: 10,
    AbilityType.dexterity: 10,
    AbilityType.constitution: 10,
    AbilityType.intelligence: 10,
    AbilityType.wisdom: 10,
    AbilityType.charisma: 10,
  };

  CharacterBuilderController({
    String initialMode = 'standard',
    bool startEmpty = true,
  }) {
    _abilityScoreMode = initialMode;
    if (initialMode == 'standard') {
      if (startEmpty) {
        populateStandardArray(clear: true);
      } else {
        autoAssignStandardArray();
      }
    }
  }

  // --- Getters ---
  String get abilityScoreMode => _abilityScoreMode;
  String get rollMethod => _rollMethod;
  List<int> get availableScores => List.unmodifiable(_availableScores);
  Map<AbilityType, int> get assignedScores => Map.unmodifiable(_assignedScores);
  int? get selectedPoolScore => _selectedPoolScore;
  List<int> get rolledPool => List.unmodifiable(_rolledPool);
  List<String> get rolledBreakdowns => List.unmodifiable(_rolledBreakdowns);
  AbilityScores get pointBuyScores => _pointBuyScores;
  Map<AbilityType, int> get manualScores => Map.unmodifiable(_manualScores);

  int get pointBuyCost => CharacterFactory.calculatePointBuyCost(_pointBuyScores);
  int get pointBuyPointsRemaining => 27 - pointBuyCost;

  // --- Mode Switching ---
  void setMode(String mode) {
    if (_abilityScoreMode == mode) return;
    _abilityScoreMode = mode;
    _selectedPoolScore = null;
    if (mode == 'standard') {
      populateStandardArray(clear: true);
    } else if (mode == 'rolled') {
      if (_rolledPool.isEmpty) {
        rollScores();
      } else if (_rollMethod != 'classic_3d6_down') {
        _availableScores = List.of(_rolledPool)..sort((a, b) => b.compareTo(a));
        _assignedScores.clear();
      }
    }
    notifyListeners();
  }

  void setRollMethod(String method) {
    _rollMethod = method;
    rollScores(method: method);
  }

  // --- Consumable Pool Mutation Methods ---

  /// Assigns a score from the consumable pool to [ability].
  /// If [ability] already has a score, that score is returned to [availableScores].
  /// Exactly one instance of [score] is removed from [availableScores].
  void assignScore(AbilityType ability, int score) {
    // If the ability already has a score, return it to the available pool
    if (_assignedScores.containsKey(ability)) {
      _availableScores.add(_assignedScores[ability]!);
    }
    // Remove exactly one instance of the new score from the available pool
    _availableScores.remove(score);
    _assignedScores[ability] = score;
    _availableScores.sort((a, b) => b.compareTo(a)); // Keep pool sorted high-to-low

    if (_selectedPoolScore == score && !_availableScores.contains(score)) {
      _selectedPoolScore = null;
    }
    notifyListeners();
  }

  /// Removes the assigned score from [ability] and returns it to [availableScores].
  void unassignScore(AbilityType ability) {
    if (_assignedScores.containsKey(ability)) {
      _availableScores.add(_assignedScores.remove(ability)!);
      _availableScores.sort((a, b) => b.compareTo(a)); // Keep pool sorted high-to-low
      notifyListeners();
    }
  }

  /// Selects a pool score chip for two-tap assignment. Tapping an already-selected
  /// chip deselects it.
  void selectPoolScore(int? score) {
    if (_selectedPoolScore == score) {
      _selectedPoolScore = null;
    } else {
      _selectedPoolScore = score;
    }
    notifyListeners();
  }

  /// Assigns the currently highlighted [_selectedPoolScore] to [ability].
  void assignSelectedPoolScore(AbilityType ability) {
    if (_selectedPoolScore != null && _availableScores.contains(_selectedPoolScore)) {
      assignScore(ability, _selectedPoolScore!);
      _selectedPoolScore = null;
    }
  }

  /// Clears assigned scores and restores the standard array pool [15, 14, 13, 12, 10, 8].
  void populateStandardArray({bool clear = true}) {
    if (clear) {
      _availableScores = [15, 14, 13, 12, 10, 8];
      _assignedScores.clear();
      _selectedPoolScore = null;
    }
    notifyListeners();
  }

  /// Convenience method that assigns standard array in traditional high-to-low order
  /// (STR 15 -> CHA 8) and exhausts the pool.
  void autoAssignStandardArray() {
    _availableScores.clear();
    _assignedScores[AbilityType.strength] = 15;
    _assignedScores[AbilityType.dexterity] = 14;
    _assignedScores[AbilityType.constitution] = 13;
    _assignedScores[AbilityType.intelligence] = 12;
    _assignedScores[AbilityType.wisdom] = 10;
    _assignedScores[AbilityType.charisma] = 8;
    _selectedPoolScore = null;
    notifyListeners();
  }

  /// Rolls dice according to [_rollMethod] and resets the consumable pool or auto-assigns
  /// down the line.
  void rollScores({String? method, math.Random? random}) {
    if (method != null) _rollMethod = method;
    final rand = random ?? math.Random();
    final newPool = <int>[];
    final newBreakdowns = <String>[];

    if (_rollMethod == 'standard_4d6') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(4, (_) => rand.nextInt(6) + 1)..sort();
        final dropped = dice.first;
        final kept = dice.sublist(1);
        final total = kept.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns.add('Roll ${i + 1}: [${dice.join(', ')}] drop $dropped = $total');
      }
    } else if (_rollMethod == 'classic_3d6_down' || _rollMethod == 'classic_3d6_nice') {
      for (int i = 0; i < 6; i++) {
        final dice = List.generate(3, (_) => rand.nextInt(6) + 1);
        final total = dice.reduce((a, b) => a + b);
        newPool.add(total);
        newBreakdowns.add('Roll ${i + 1}: [${dice.join(' + ')}] = $total');
      }
    } else if (_rollMethod == 'silly_d20') {
      for (int i = 0; i < 6; i++) {
        final roll = rand.nextInt(20) + 1;
        newPool.add(roll);
        newBreakdowns.add('Roll ${i + 1}: 1d20 = $roll');
      }
    }

    _rolledPool = List.of(newPool);
    _rolledBreakdowns = newBreakdowns;
    _selectedPoolScore = null;

    if (_rollMethod == 'classic_3d6_down') {
      _availableScores.clear();
      _assignedScores[AbilityType.strength] = newPool[0];
      _assignedScores[AbilityType.dexterity] = newPool[1];
      _assignedScores[AbilityType.constitution] = newPool[2];
      _assignedScores[AbilityType.intelligence] = newPool[3];
      _assignedScores[AbilityType.wisdom] = newPool[4];
      _assignedScores[AbilityType.charisma] = newPool[5];
    } else {
      _availableScores = List.of(newPool)..sort((a, b) => b.compareTo(a));
      _assignedScores.clear();
    }
    notifyListeners();
  }

  /// Sets rolled scores directly. Useful for tests or external seed generators.
  void populateRolledScores(List<int> scores, {List<String> breakdowns = const [], bool downTheLine = false}) {
    _rolledPool = List.of(scores);
    _rolledBreakdowns = List.of(breakdowns);
    _selectedPoolScore = null;

    if (downTheLine) {
      _availableScores.clear();
      _assignedScores[AbilityType.strength] = scores[0];
      _assignedScores[AbilityType.dexterity] = scores[1];
      _assignedScores[AbilityType.constitution] = scores[2];
      _assignedScores[AbilityType.intelligence] = scores[3];
      _assignedScores[AbilityType.wisdom] = scores[4];
      _assignedScores[AbilityType.charisma] = scores[5];
    } else {
      _availableScores = List.of(scores)..sort((a, b) => b.compareTo(a));
      _assignedScores.clear();
    }
    notifyListeners();
  }

  // --- Point Buy & Manual Mutations ---
  void adjustPointBuy(AbilityType ability, int delta) {
    final curScore = _pointBuyScores.getScore(ability);
    final target = curScore + delta;
    if (target < 8 || target > 15) return;
    final updated = _adjustScoresRecord(_pointBuyScores, ability, delta);
    final cost = CharacterFactory.calculatePointBuyCost(updated);
    if (cost <= 27 || delta < 0) {
      _pointBuyScores = updated;
      notifyListeners();
    }
  }

  void setManualScore(AbilityType ability, int value) {
    _manualScores[ability] = value.clamp(3, 30);
    notifyListeners();
  }

  AbilityScores _adjustScoresRecord(AbilityScores scores, AbilityType ab, int delta) {
    switch (ab) {
      case AbilityType.strength:
        return scores.copyWith(strength: scores.strength + delta);
      case AbilityType.dexterity:
        return scores.copyWith(dexterity: scores.dexterity + delta);
      case AbilityType.constitution:
        return scores.copyWith(constitution: scores.constitution + delta);
      case AbilityType.intelligence:
        return scores.copyWith(intelligence: scores.intelligence + delta);
      case AbilityType.wisdom:
        return scores.copyWith(wisdom: scores.wisdom + delta);
      case AbilityType.charisma:
        return scores.copyWith(charisma: scores.charisma + delta);
    }
  }

  // --- Progression Validation ---

  /// Evaluates whether the ability score allocation step is complete and valid.
  bool get isAbilityAllocationComplete {
    switch (_abilityScoreMode) {
      case 'standard':
        return _availableScores.isEmpty &&
            _assignedScores.length == 6 &&
            AbilityType.values.every((a) => _assignedScores.containsKey(a));
      case 'rolled':
        if (_rollMethod == 'classic_3d6_down') {
          return _assignedScores.length == 6 &&
              AbilityType.values.every((a) => _assignedScores.containsKey(a));
        }
        return _availableScores.isEmpty &&
            _assignedScores.length == 6 &&
            AbilityType.values.every((a) => _assignedScores.containsKey(a));
      case 'pointBuy':
        final cost = CharacterFactory.calculatePointBuyCost(_pointBuyScores);
        return cost <= 27 &&
            AbilityType.values.every((a) {
              final s = _pointBuyScores.getScore(a);
              return s >= 8 && s <= 15;
            });
      case 'manual':
        return AbilityType.values.every((a) {
          final s = _manualScores[a];
          return s != null && s >= 3 && s <= 30;
        });
      default:
        return false;
    }
  }

  // --- Effective Output ---

  /// Computes the effective base scores for character creation.
  AbilityScores get effectiveBaseScores {
    switch (_abilityScoreMode) {
      case 'standard':
      case 'rolled':
        return AbilityScores(
          strength: _assignedScores[AbilityType.strength] ?? 10,
          dexterity: _assignedScores[AbilityType.dexterity] ?? 10,
          constitution: _assignedScores[AbilityType.constitution] ?? 10,
          intelligence: _assignedScores[AbilityType.intelligence] ?? 10,
          wisdom: _assignedScores[AbilityType.wisdom] ?? 10,
          charisma: _assignedScores[AbilityType.charisma] ?? 10,
        );
      case 'pointBuy':
        return _pointBuyScores;
      case 'manual':
        return AbilityScores(
          strength: _manualScores[AbilityType.strength] ?? 10,
          dexterity: _manualScores[AbilityType.dexterity] ?? 10,
          constitution: _manualScores[AbilityType.constitution] ?? 10,
          intelligence: _manualScores[AbilityType.intelligence] ?? 10,
          wisdom: _manualScores[AbilityType.wisdom] ?? 10,
          charisma: _manualScores[AbilityType.charisma] ?? 10,
        );
      default:
        return const AbilityScores.standardArray();
    }
  }
}
