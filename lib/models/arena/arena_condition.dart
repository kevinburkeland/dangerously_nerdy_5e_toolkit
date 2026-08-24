import 'package:flutter/material.dart';

/// Core 5e Conditions & Combat Statuses affecting combat status, advantage, and aerial stability.
enum ArenaCondition {
  prone(
    'Prone',
    'PRN',
    Icons.airline_seat_flat,
    Color(0xFF84CC16), // Light green / Lime
    'Disadvantage on attacks; melee attacks against within 5 ft have Advantage; costs half speed to stand.',
  ),
  stunned(
    'Stunned',
    'STN',
    Icons.flash_on,
    Color(0xFFF59E0B), // Amber
    'Incapacitated, can’t move, auto-fails STR/DEX saves, attacks against have Advantage.',
  ),
  paralyzed(
    'Paralyzed',
    'PAR',
    Icons.offline_bolt,
    Color(0xFFEAB308), // Yellow / Gold
    'Incapacitated, speed 0, auto-fails STR/DEX saves, attacks against have Advantage, hits within 5 ft are Crits.',
  ),
  restrained(
    'Restrained',
    'RST',
    Icons.lock,
    Color(0xFFF97316), // Orange
    'Speed 0, attacks against have Advantage, attacks have Disadvantage, DEX save Disadvantage.',
  ),
  unconscious(
    'Unconscious',
    'UNC',
    Icons.bedtime,
    Color(0xFF6366F1), // Indigo
    'Incapacitated, drops items, falls Prone, auto-fails STR/DEX saves, hits within 5 ft are Crits.',
  ),
  incapacitated(
    'Incapacitated',
    'INC',
    Icons.do_not_disturb_on,
    Color(0xFFEF4444), // Crimson Red
    'Cannot take actions, bonus actions, or reactions; breaks active concentration.',
  ),
  blinded(
    'Blinded',
    'BLN',
    Icons.visibility_off,
    Color(0xFF64748B), // Slate / Blue Grey
    'Cannot see, auto-fails sight checks, attacks have Disadvantage, attacks against have Advantage.',
  ),
  charmed(
    'Charmed',
    'CHM',
    Icons.favorite,
    Color(0xFFEC4899), // Pink
    'Cannot attack or harm charmer; charmer has Advantage on social ability checks.',
  ),
  deafened(
    'Deafened',
    'DEF',
    Icons.hearing_disabled,
    Color(0xFF14B8A6), // Teal
    'Cannot hear, automatically fails any ability check requiring hearing.',
  ),
  frightened(
    'Frightened',
    'FRG',
    Icons.sentiment_very_dissatisfied,
    Color(0xFFEA580C), // Deep Orange
    'Disadvantage on ability checks and attack rolls while source visible; cannot willingly move closer.',
  ),
  poisoned(
    'Poisoned',
    'POI',
    Icons.science,
    Color(0xFF10B981), // Emerald Green
    'Disadvantage on attack rolls and ability checks.',
  ),
  invisible(
    'Invisible',
    'INV',
    Icons.blur_on,
    Color(0xFF06B6D4), // Cyan
    'Concealed from sight; attack rolls have Advantage; incoming attacks have Disadvantage.',
  ),
  petrified(
    'Petrified',
    'PET',
    Icons.terrain,
    Color(0xFF78716C), // Stone / Warm Grey
    'Incapacitated, weight ×10, unaware, resistance to all damage, poison immunity.',
  ),
  exhaustion(
    'Exhaustion',
    'EXH',
    Icons.battery_alert,
    Color(0xFFDC2626), // Deep Red
    'Penalties to D20 tests and movement speed.',
  ),
  concentration(
    'Concentration',
    'CNC',
    Icons.psychology,
    Color(0xFFA855F7), // Purple / Amethyst
    'Maintaining concentration on an active spell; ends if Incapacitated or fails CON save upon taking damage.',
  ),
  burning(
    'Burning',
    'BRN',
    Icons.local_fire_department,
    Color(0xFFE11D48), // Rose / Fire Red
    'Suffers periodic fire damage at start/end of turn until extinguished.',
  ),
  bleeding(
    'Bleeding',
    'BLD',
    Icons.water_drop,
    Color(0xFFBE123C), // Blood Crimson
    'Suffers ongoing bleeding damage upon taking actions or ending turn.',
  );

  final String label;
  final String shortCode;
  final IconData icon;
  final Color colorTheme;
  final String penaltySummary;

  const ArenaCondition(
    this.label,
    this.shortCode,
    this.icon,
    this.colorTheme,
    this.penaltySummary,
  );

  /// Helper to get a condition by id or name insensitive.
  static ArenaCondition? fromName(String name) {
    final lower = name.trim().toLowerCase();
    for (final c in ArenaCondition.values) {
      if (c.name.toLowerCase() == lower || c.label.toLowerCase() == lower || c.shortCode.toLowerCase() == lower) {
        return c;
      }
    }
    return null;
  }
}

/// Represents an active instance of a status condition applied to a combatant token.
class ActiveCondition {
  final ArenaCondition condition;
  final int? durationRounds;
  final String? source;
  final String? customNote;

  const ActiveCondition({
    required this.condition,
    this.durationRounds,
    this.source,
    this.customNote,
  });

  String get id => condition.name;
  String get name => condition.label;
  String get shortCode => condition.shortCode;
  IconData get icon => condition.icon;
  Color get colorTheme => condition.colorTheme;
  String get penaltySummary => condition.penaltySummary;
  bool get hasFiniteDuration => durationRounds != null;
  bool get isExpired => durationRounds != null && durationRounds! <= 0;

  String get durationDisplay {
    if (durationRounds == null) return 'Until End of Combat / Saved';
    if (durationRounds == 1) return '1 round remaining';
    return '$durationRounds rounds remaining';
  }

  String get durationBadge {
    if (durationRounds == null) return '∞';
    return '${durationRounds}r';
  }

  /// Decrements remaining duration by 1 round (turn tick).
  ActiveCondition tickTurn() {
    if (durationRounds == null) return this;
    return ActiveCondition(
      condition: condition,
      durationRounds: durationRounds! - 1,
      source: source,
      customNote: customNote,
    );
  }

  ActiveCondition copyWith({
    ArenaCondition? condition,
    int? durationRounds,
    String? source,
    String? customNote,
  }) {
    return ActiveCondition(
      condition: condition ?? this.condition,
      durationRounds: durationRounds ?? this.durationRounds,
      source: source ?? this.source,
      customNote: customNote ?? this.customNote,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveCondition &&
          runtimeType == other.runtimeType &&
          condition == other.condition &&
          durationRounds == other.durationRounds &&
          source == other.source;

  @override
  int get hashCode => condition.hashCode ^ durationRounds.hashCode ^ (source?.hashCode ?? 0);
}
