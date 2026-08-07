import 'dart:convert';
import 'dice_roll.dart';

class CustomPreset {
  final String id;
  final String name;
  final List<DiceEntry> diceEntries;
  final int modifier;
  final RollMode rollMode;

  CustomPreset({
    required this.id,
    required this.name,
    List<DiceEntry>? diceEntries,
    DieType? dieType,
    int? count,
    int customSides = 6,
    required this.modifier,
    this.rollMode = RollMode.normal,
  }) : diceEntries = diceEntries ??
            [
              DiceEntry(
                dieType: dieType ?? DieType.d6,
                count: count ?? 1,
                customSides: customSides,
              )
            ];

  DieType get dieType => diceEntries.isNotEmpty ? diceEntries.first.dieType : DieType.d6;
  int get count => diceEntries.isNotEmpty ? diceEntries.fold(0, (sum, e) => sum + e.count) : 1;

  String get formulaString {
    final diceStr = diceEntries.map((e) => e.formulaString).join('+');
    final modStr = modifier != 0 ? (modifier > 0 ? '+$modifier' : '$modifier') : '';
    final modeStr = rollMode == RollMode.advantage ? ' (Adv)' : (rollMode == RollMode.disadvantage ? ' (Dis)' : '');
    return '$diceStr$modStr$modeStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'diceEntries': diceEntries.map((e) => e.toMap()).toList(),
      'dieType': dieType.name,
      'count': count,
      'modifier': modifier,
      'rollMode': rollMode.name,
    };
  }

  factory CustomPreset.fromMap(Map<String, dynamic> map) {
    List<DiceEntry> parsedEntries = [];
    if (map['diceEntries'] is List && (map['diceEntries'] as List).isNotEmpty) {
      parsedEntries = (map['diceEntries'] as List)
          .map((item) => DiceEntry.fromMap(item as Map<String, dynamic>))
          .toList();
    } else {
      final dt = DieType.values.firstWhere(
        (d) => d.name == map['dieType'],
        orElse: () => DieType.d6,
      );
      parsedEntries = [
        DiceEntry(
          dieType: dt,
          count: map['count'] as int? ?? 1,
          customSides: map['customSides'] as int? ?? 6,
        )
      ];
    }

    return CustomPreset(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? 'Custom Preset',
      diceEntries: parsedEntries,
      modifier: map['modifier'] as int? ?? 0,
      rollMode: RollMode.values.firstWhere(
        (m) => m.name == map['rollMode'],
        orElse: () => RollMode.normal,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory CustomPreset.fromJson(String source) => CustomPreset.fromMap(json.decode(source) as Map<String, dynamic>);

  CustomPreset copyWith({
    String? id,
    String? name,
    List<DiceEntry>? diceEntries,
    int? modifier,
    RollMode? rollMode,
  }) {
    return CustomPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      diceEntries: diceEntries ?? this.diceEntries,
      modifier: modifier ?? this.modifier,
      rollMode: rollMode ?? this.rollMode,
    );
  }
}

