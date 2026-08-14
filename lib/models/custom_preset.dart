import 'dart:convert';
import '../utils/dice_formatters.dart';
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
    final modStr = DiceFormatters.formatBonus(modifier);
    final modeStr = switch (rollMode) {
      RollMode.advantage => ' (Adv)',
      RollMode.disadvantage => ' (Dis)',
      RollMode.normal => '',
    };
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
    final rawEntries = map['diceEntries'];
    if (rawEntries is List && rawEntries.isNotEmpty) {
      for (final item in rawEntries) {
        if (item is Map<String, dynamic>) {
          parsedEntries.add(DiceEntry.fromMap(item));
        } else if (item is Map) {
          parsedEntries.add(DiceEntry.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    if (parsedEntries.isEmpty) {
      final dtStr = map['dieType']?.toString() ?? 'd6';
      final dt = DieType.values.firstWhere(
        (d) => d.name == dtStr,
        orElse: () => DieType.d6,
      );
      parsedEntries = [
        DiceEntry(
          dieType: dt,
          count: (map['count'] as num?)?.toInt() ?? 1,
          customSides: (map['customSides'] as num?)?.toInt() ?? 6,
        )
      ];
    }

    final rawRollMode = map['rollMode']?.toString() ?? 'normal';
    return CustomPreset(
      id: map['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name']?.toString() ?? 'Custom Preset',
      diceEntries: parsedEntries,
      modifier: (map['modifier'] as num?)?.toInt() ?? 0,
      rollMode: RollMode.values.firstWhere(
        (m) => m.name == rawRollMode,
        orElse: () => RollMode.normal,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory CustomPreset.fromJson(String source) {
    final decoded = json.decode(source);
    if (decoded is Map) {
      return CustomPreset.fromMap(Map<String, dynamic>.from(decoded));
    }
    throw const FormatException('Invalid JSON format for CustomPreset');
  }

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

