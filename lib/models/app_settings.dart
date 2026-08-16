import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dm_screen_data.dart';

/// Available fantasy accent palettes with distinct primary and secondary luminescence
enum FantasyAccent {
  paladinGold('Paladin Gold', Color(0xFFFFC107), Color(0xFFFFD54F)),
  eldritchPurple('Eldritch Purple', Color(0xFF9C27B0), Color(0xFFBA68C8)),
  rangerEmerald('Ranger Emerald', Color(0xFF00E676), Color(0xFF69F0AE)),
  necroticSlate('Necrotic Slate', Color(0xFF78909C), Color(0xFF90A4AE)),
  dragonfireCrimson('Dragonfire Crimson', Color(0xFFFF3D00), Color(0xFFFF6E40)),
  arcaneSapphire('Arcane Sapphire', Color(0xFF2979FF), Color(0xFF82B1FF)),
  bardicRose('Bardic Rose', Color(0xFFE91E63), Color(0xFFFF4081)),
  abyssalTeal('Abyssal Teal', Color(0xFF00BFA5), Color(0xFF64FFDA)),
  celestialAmber('Celestial Amber', Color(0xFFFF9100), Color(0xFFFFD180));

  final String label;
  final Color primary;
  final Color accent;
  const FantasyAccent(this.label, this.primary, this.accent);
}

/// Haptic tactile feedback strength levels
enum HapticFeedbackLevel {
  off('Off'),
  light('Light (Tactile Ticks)'),
  heavy('Heavy (Combat Rumble)');

  final String label;
  const HapticFeedbackLevel(this.label);
}

/// Immutable user preferences and visual polish configuration
@immutable
class AppSettings {
  final ThemeMode themeMode;
  final FantasyAccent fantasyAccent;
  final bool oledPitchBlack;
  final HapticFeedbackLevel hapticLevel;
  final bool enableCritFumbleFx;
  final bool enableSpellParticles;
  final bool enable3dDiceOverlays;
  final bool performanceMode;
  final DmRulesEdition rulesEdition;
  final Set<String> pinnedRuleIds;
  final Set<String> pinnedSpellIds;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.fantasyAccent = FantasyAccent.paladinGold,
    this.oledPitchBlack = false,
    this.hapticLevel = HapticFeedbackLevel.light,
    this.enableCritFumbleFx = true,
    this.enableSpellParticles = true,
    this.enable3dDiceOverlays = true,
    this.performanceMode = false,
    this.rulesEdition = DmRulesEdition.v2024,
    this.pinnedRuleIds = const <String>{},
    this.pinnedSpellIds = const <String>{},
  });

  /// Whether particle and continuous visual FX are permitted to render
  bool get areParticlesAllowed => enableSpellParticles && !performanceMode;

  /// Whether critical hit and fumble animations are permitted to run
  bool get areCritFxAllowed => enableCritFumbleFx && !performanceMode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    FantasyAccent? fantasyAccent,
    bool? oledPitchBlack,
    HapticFeedbackLevel? hapticLevel,
    bool? enableCritFumbleFx,
    bool? enableSpellParticles,
    bool? enable3dDiceOverlays,
    bool? performanceMode,
    DmRulesEdition? rulesEdition,
    Set<String>? pinnedRuleIds,
    Set<String>? pinnedSpellIds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fantasyAccent: fantasyAccent ?? this.fantasyAccent,
      oledPitchBlack: oledPitchBlack ?? this.oledPitchBlack,
      hapticLevel: hapticLevel ?? this.hapticLevel,
      enableCritFumbleFx: enableCritFumbleFx ?? this.enableCritFumbleFx,
      enableSpellParticles: enableSpellParticles ?? this.enableSpellParticles,
      enable3dDiceOverlays: enable3dDiceOverlays ?? this.enable3dDiceOverlays,
      performanceMode: performanceMode ?? this.performanceMode,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      pinnedRuleIds: pinnedRuleIds ?? this.pinnedRuleIds,
      pinnedSpellIds: pinnedSpellIds ?? this.pinnedSpellIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          themeMode == other.themeMode &&
          fantasyAccent == other.fantasyAccent &&
          oledPitchBlack == other.oledPitchBlack &&
          hapticLevel == other.hapticLevel &&
          enableCritFumbleFx == other.enableCritFumbleFx &&
          enableSpellParticles == other.enableSpellParticles &&
          enable3dDiceOverlays == other.enable3dDiceOverlays &&
          performanceMode == other.performanceMode &&
          rulesEdition == other.rulesEdition &&
          setEquals(pinnedRuleIds, other.pinnedRuleIds) &&
          setEquals(pinnedSpellIds, other.pinnedSpellIds);

  @override
  int get hashCode => Object.hash(
        themeMode,
        fantasyAccent,
        oledPitchBlack,
        hapticLevel,
        enableCritFumbleFx,
        enableSpellParticles,
        enable3dDiceOverlays,
        performanceMode,
        rulesEdition,
        Object.hashAll(pinnedRuleIds),
        Object.hashAll(pinnedSpellIds),
      );
}
