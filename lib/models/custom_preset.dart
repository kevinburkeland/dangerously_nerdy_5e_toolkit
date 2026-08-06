import 'dart:convert';
import 'dice_roll.dart';

class CustomPreset {
  final String id;
  final String name;
  final DieType dieType;
  final int count;
  final int modifier;
  final RollMode rollMode;

  CustomPreset({
    required this.id,
    required this.name,
    required this.dieType,
    required this.count,
    required this.modifier,
    this.rollMode = RollMode.normal,
  });

  String get formulaString {
    final modStr = modifier != 0 ? (modifier > 0 ? '+$modifier' : '$modifier') : '';
    final modeStr = rollMode == RollMode.advantage ? ' (Adv)' : (rollMode == RollMode.disadvantage ? ' (Dis)' : '');
    return '$count${dieType.label}$modStr$modeStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dieType': dieType.name,
      'count': count,
      'modifier': modifier,
      'rollMode': rollMode.name,
    };
  }

  factory CustomPreset.fromMap(Map<String, dynamic> map) {
    return CustomPreset(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: map['name'] as String? ?? 'Custom Preset',
      dieType: DieType.values.firstWhere(
        (d) => d.name == map['dieType'],
        orElse: () => DieType.d6,
      ),
      count: map['count'] as int? ?? 1,
      modifier: map['modifier'] as int? ?? 0,
      rollMode: RollMode.values.firstWhere(
        (m) => m.name == map['rollMode'],
        orElse: () => RollMode.normal,
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory CustomPreset.fromJson(String source) => CustomPreset.fromMap(json.decode(source) as Map<String, dynamic>);
}
