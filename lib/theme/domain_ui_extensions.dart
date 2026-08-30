import 'package:flutter/material.dart';
import '../models/dm_screen_data.dart';
import '../models/arena/arena_combatant.dart';
import '../models/animated_object.dart';

/// Presentation-layer UI extensions for pure domain models.
/// Keeps pure Dart models free of Flutter UI framework imports (IconData, Color, BuildContext).

extension DmCategoryUI on DmCategory {
  IconData get icon => switch (this) {
        DmCategory.actions => Icons.sports_kabaddi,
        DmCategory.conditions => Icons.medical_information_outlined,
        DmCategory.environment => Icons.landscape_outlined,
        DmCategory.exploration => Icons.explore_outlined,
        DmCategory.magicAndResting => Icons.auto_awesome,
        DmCategory.tables => Icons.table_chart_outlined,
      };

  Color get color => switch (this) {
        DmCategory.actions => Colors.amber,
        DmCategory.conditions => Colors.cyanAccent,
        DmCategory.environment => Colors.lightGreenAccent,
        DmCategory.exploration => Colors.orangeAccent,
        DmCategory.magicAndResting => Colors.purpleAccent,
        DmCategory.tables => Colors.pinkAccent,
      };

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      return switch (this) {
        DmCategory.actions => const Color(0xFFB45309),
        DmCategory.conditions => const Color(0xFF0E7490),
        DmCategory.environment => const Color(0xFF15803D),
        DmCategory.exploration => const Color(0xFFC2410C),
        DmCategory.magicAndResting => const Color(0xFF7E22CE),
        DmCategory.tables => const Color(0xFFBE185D),
      };
    }
    return color;
  }
}

extension DmReferenceItemUI on DmReferenceItem {
  static const Map<String, IconData> _itemIcons = {
    'action_attack': Icons.sports_kabaddi,
    'action_cast_spell': Icons.auto_awesome,
    'action_dash': Icons.directions_run,
    'action_disengage': Icons.transit_enterexit,
    'action_dodge': Icons.shield,
    'action_help': Icons.handshake,
    'action_hide': Icons.visibility_off,
    'action_ready': Icons.hourglass_top,
    'action_search': Icons.search,
    'action_study': Icons.menu_book,
    'action_influence': Icons.record_voice_over,
    'action_use_object': Icons.touch_app,
    'action_improvise': Icons.lightbulb_outline,
    'action_grapple_shove': Icons.sports_mma,
    'action_damage_rolls_crit': Icons.gps_fixed,
    'action_damage_types': Icons.whatshot,
    'action_unseen_attackers': Icons.visibility_off,
    'action_ranged_in_melee': Icons.crisis_alert,
    'action_potions': Icons.liquor,
    'action_death_saves': Icons.favorite_border,
    'action_nonlethal_knockout': Icons.bedtime_outlined,
    'action_temporary_hp': Icons.shield_outlined,
    'action_movement_combat': Icons.alt_route,
    'action_jumping': Icons.nordic_walking,
    'action_flying_falling': Icons.flight,
    'action_underwater_combat': Icons.water,
    'action_mounted_combat': Icons.cruelty_free,
    'action_flanking': Icons.join_inner,
    'action_two_weapon_fighting': Icons.content_cut,
    'action_bonus_action_spells': Icons.bolt,
    'action_class_features': Icons.star,
    'action_opportunity_attack': Icons.front_hand,
    'action_reaction_spells': Icons.security,
    'action_readied_action_trigger': Icons.alarm_on,
    'cond_blinded': Icons.visibility_off,
    'cond_charmed': Icons.favorite,
    'cond_deafened': Icons.hearing_disabled,
    'cond_frightened': Icons.sentiment_very_dissatisfied,
    'cond_grappled': Icons.sports_mma,
    'cond_incapacitated': Icons.do_not_disturb_on,
    'cond_invisible': Icons.blur_on,
    'cond_paralyzed': Icons.offline_bolt,
    'cond_petrified': Icons.terrain,
    'cond_poisoned': Icons.science,
    'cond_prone': Icons.airline_seat_flat,
    'cond_restrained': Icons.lock,
    'cond_stunned': Icons.flash_on,
    'cond_unconscious': Icons.bedtime,
    'cond_exhaustion': Icons.battery_alert,
    'cond_surprise': Icons.priority_high,
    'cond_poisons_diseases': Icons.coronavirus_outlined,
    'env_cover': Icons.shield,
    'env_cover_half': Icons.table_restaurant,
    'env_cover_three_quarters': Icons.fence,
    'env_cover_total': Icons.door_front_door,
    'env_falling': Icons.south,
    'env_vision_lighting': Icons.lightbulb_outline,
    'env_suffocation': Icons.air,
    'env_extreme_temperatures': Icons.thermostat,
    'env_weather_hazards': Icons.storm,
    'env_wilderness_hazards': Icons.warning_amber_rounded,
    'env_survival_foraging': Icons.eco,
    'exp_dc_scale': Icons.speed,
    'exp_ability_scores_skills': Icons.psychology_alt,
    'exp_passive_checks': Icons.remove_red_eye_outlined,
    'exp_travel_pace': Icons.directions_walk,
    'exp_forced_march': Icons.hiking,
    'exp_marching_order_nav': Icons.navigation,
    'exp_social_influence': Icons.record_voice_over,
    'exp_traps_detection': Icons.dangerous_outlined,
    'magic_concentration': Icons.psychology,
    'magic_spell_components': Icons.grain,
    'magic_casting_times_rituals': Icons.hourglass_bottom,
    'magic_combining_effects': Icons.layers,
    'magic_spell_limits': Icons.bolt,
    'magic_counterspell_dispel': Icons.flash_off,
    'magic_attunement': Icons.auto_fix_high,
    'magic_resting': Icons.bed,
    'magic_downtime_expenses': Icons.monetization_on,
    'magic_downtime_activities': Icons.construction,
    'table_improvised_damage': Icons.local_fire_department,
    'table_object_ac_hp': Icons.crop_square,
    'table_size_space_carrying': Icons.aspect_ratio,
    'table_weapon_properties_masteries': Icons.colorize,
    'table_armor_don_doff': Icons.shield,
    'table_currency_exchange': Icons.paid_outlined,
    'table_standard_languages': Icons.translate,
    'table_adventuring_gear_lighting': Icons.flashlight_on_outlined,
  };

  static const Map<String, Color> _itemColors = {
    'action_attack': Colors.amber,
    'action_cast_spell': Colors.purpleAccent,
    'action_dash': Colors.cyanAccent,
    'action_disengage': Colors.greenAccent,
    'action_dodge': Colors.blueAccent,
    'action_help': Colors.tealAccent,
    'action_hide': Colors.blueGrey,
    'action_ready': Colors.orangeAccent,
    'action_search': Colors.lightGreenAccent,
    'action_study': Colors.teal,
    'action_influence': Colors.pinkAccent,
    'action_use_object': Colors.pinkAccent,
    'action_improvise': Colors.amber,
    'action_grapple_shove': Colors.deepOrangeAccent,
    'action_damage_rolls_crit': Colors.redAccent,
    'action_damage_types': Colors.orangeAccent,
    'action_unseen_attackers': Colors.blueGrey,
    'action_ranged_in_melee': Colors.deepOrange,
    'action_potions': Colors.redAccent,
    'action_death_saves': Colors.red,
    'action_nonlethal_knockout': Colors.indigoAccent,
    'action_temporary_hp': Colors.cyanAccent,
    'action_movement_combat': Colors.tealAccent,
    'action_jumping': Colors.greenAccent,
    'action_flying_falling': Colors.lightBlueAccent,
    'action_underwater_combat': Colors.cyan,
    'action_mounted_combat': Colors.brown,
    'action_flanking': Colors.amber,
    'action_two_weapon_fighting': Colors.amber,
    'action_bonus_action_spells': Colors.purpleAccent,
    'action_class_features': Colors.cyanAccent,
    'action_opportunity_attack': Colors.redAccent,
    'action_reaction_spells': Colors.purpleAccent,
    'action_readied_action_trigger': Colors.orangeAccent,
    'cond_blinded': Colors.blueGrey,
    'cond_charmed': Colors.pinkAccent,
    'cond_deafened': Colors.tealAccent,
    'cond_frightened': Colors.deepOrangeAccent,
    'cond_grappled': Colors.amber,
    'cond_incapacitated': Colors.redAccent,
    'cond_invisible': Colors.cyanAccent,
    'cond_paralyzed': Colors.yellowAccent,
    'cond_petrified': Colors.brown,
    'cond_poisoned': Colors.greenAccent,
    'cond_prone': Colors.lightGreenAccent,
    'cond_restrained': Colors.orangeAccent,
    'cond_stunned': Colors.purpleAccent,
    'cond_unconscious': Colors.indigoAccent,
    'cond_exhaustion': Colors.red,
    'cond_surprise': Colors.deepPurpleAccent,
    'cond_poisons_diseases': Colors.green,
    'env_cover': Colors.tealAccent,
    'env_cover_half': Colors.lightGreenAccent,
    'env_cover_three_quarters': Colors.amber,
    'env_cover_total': Colors.redAccent,
    'env_falling': Colors.deepOrange,
    'env_vision_lighting': Colors.amber,
    'env_suffocation': Colors.cyan,
    'env_extreme_temperatures': Colors.deepOrangeAccent,
    'env_weather_hazards': Colors.blueAccent,
    'env_wilderness_hazards': Colors.lime,
    'env_survival_foraging': Colors.green,
    'exp_dc_scale': Colors.lightGreenAccent,
    'exp_ability_scores_skills': Colors.cyanAccent,
    'exp_passive_checks': Colors.teal,
    'exp_travel_pace': Colors.orangeAccent,
    'exp_forced_march': Colors.deepOrangeAccent,
    'exp_marching_order_nav': Colors.deepPurpleAccent,
    'exp_social_influence': Colors.pinkAccent,
    'exp_traps_detection': Colors.redAccent,
    'magic_concentration': Colors.purpleAccent,
    'magic_spell_components': Colors.tealAccent,
    'magic_casting_times_rituals': Colors.deepPurpleAccent,
    'magic_combining_effects': Colors.indigoAccent,
    'magic_spell_limits': Colors.deepPurpleAccent,
    'magic_counterspell_dispel': Colors.purple,
    'magic_attunement': Colors.cyanAccent,
    'magic_resting': Colors.indigoAccent,
    'magic_downtime_expenses': Colors.amber,
    'magic_downtime_activities': Colors.tealAccent,
    'table_improvised_damage': Colors.deepOrangeAccent,
    'table_object_ac_hp': Colors.brown,
    'table_size_space_carrying': Colors.blueAccent,
    'table_weapon_properties_masteries': Colors.redAccent,
    'table_armor_don_doff': Colors.amber,
    'table_currency_exchange': Colors.amberAccent,
    'table_standard_languages': Colors.lightGreenAccent,
    'table_adventuring_gear_lighting': Colors.orangeAccent,
  };

  IconData get icon => _itemIcons[id] ?? category.icon;
  Color get color => _itemColors[id] ?? category.color;

  Color getLegibleColor(bool isDarkMode) {
    if (!isDarkMode) {
      final c = color;
      if (c == Colors.amber) return const Color(0xFFB45309);
      if (c == Colors.cyanAccent) return const Color(0xFF0E7490);
      if (c == Colors.lightGreenAccent) return const Color(0xFF15803D);
      if (c == Colors.orangeAccent) return const Color(0xFFC2410C);
      if (c == Colors.purpleAccent) return const Color(0xFF7E22CE);
      if (c == Colors.pinkAccent) return const Color(0xFFBE185D);
      return category.getLegibleColor(isDarkMode);
    }
    return color;
  }
}

extension ArenaTeamUI on ArenaTeam {
  Color get color => this == ArenaTeam.teamA ? const Color(0xFFEF4444) : const Color(0xFF3B82F6);
  IconData get icon => this == ArenaTeam.teamA ? Icons.shield_moon : Icons.shield_outlined;
}

extension ArenaConditionUI on ArenaCondition {
  IconData get icon => switch (this) {
        ArenaCondition.prone => Icons.airline_seat_flat,
        ArenaCondition.stunned => Icons.flash_on,
        ArenaCondition.paralyzed => Icons.offline_bolt,
        ArenaCondition.restrained => Icons.lock,
        ArenaCondition.unconscious => Icons.bedtime,
        ArenaCondition.incapacitated => Icons.do_not_disturb_on,
        ArenaCondition.blinded => Icons.visibility_off,
        ArenaCondition.charmed => Icons.favorite,
        ArenaCondition.deafened => Icons.hearing_disabled,
        ArenaCondition.frightened => Icons.sentiment_very_dissatisfied,
        ArenaCondition.grappled => Icons.front_hand,
        ArenaCondition.poisoned => Icons.science,
        ArenaCondition.invisible => Icons.blur_on,
        ArenaCondition.petrified => Icons.terrain,
        ArenaCondition.exhaustion => Icons.battery_alert,
        ArenaCondition.concentration => Icons.psychology,
        ArenaCondition.burning => Icons.local_fire_department,
        ArenaCondition.bleeding => Icons.water_drop,
      };

  Color get colorTheme => switch (this) {
        ArenaCondition.prone => const Color(0xFF84CC16),
        ArenaCondition.stunned => const Color(0xFFF59E0B),
        ArenaCondition.paralyzed => const Color(0xFFEAB308),
        ArenaCondition.restrained => const Color(0xFFF97316),
        ArenaCondition.unconscious => const Color(0xFF6366F1),
        ArenaCondition.incapacitated => const Color(0xFFEF4444),
        ArenaCondition.blinded => const Color(0xFF64748B),
        ArenaCondition.charmed => const Color(0xFFEC4899),
        ArenaCondition.deafened => const Color(0xFF14B8A6),
        ArenaCondition.frightened => const Color(0xFFEA580C),
        ArenaCondition.grappled => const Color(0xFFEAB308),
        ArenaCondition.poisoned => const Color(0xFF10B981),
        ArenaCondition.invisible => const Color(0xFF06B6D4),
        ArenaCondition.petrified => const Color(0xFF78716C),
        ArenaCondition.exhaustion => const Color(0xFFDC2626),
        ArenaCondition.concentration => const Color(0xFFA855F7),
        ArenaCondition.burning => const Color(0xFFE11D48),
        ArenaCondition.bleeding => const Color(0xFFBE123C),
      };
}

extension ActiveConditionUI on ActiveCondition {
  IconData get icon => condition.icon;
  Color get colorTheme => condition.colorTheme;
}

extension ObjectSizeUI on ObjectSize {
  Color get accentColor => switch (this) {
        ObjectSize.tiny => const Color(0xFF4CAF50),
        ObjectSize.small => const Color(0xFF03A9F4),
        ObjectSize.medium => const Color(0xFFFF9800),
        ObjectSize.large => const Color(0xFFE91E63),
        ObjectSize.huge => const Color(0xFF9C27B0),
      };
}

extension AnimatedObjectInstanceUI on AnimatedObjectInstance {
  Color? get customAccentColor =>
      customAccentColorValue != null ? Color(customAccentColorValue!) : null;

  Color get effectiveAccentColor =>
      customAccentColorValue != null ? Color(customAccentColorValue!) : size.accentColor;

  Color get accentColor => effectiveAccentColor;
}
