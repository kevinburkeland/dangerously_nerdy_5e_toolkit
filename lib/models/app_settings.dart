import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dm_screen_data.dart';

/// Available fantasy accent palettes with distinct primary and secondary luminescence
enum FantasyAccent {
  paladinGold('Paladin Gold', Color(0xFFFFC107), Color(0xFFFFD54F), lightPrimary: Color(0xFF92400E), lightAccent: Color(0xFFB45309)),
  eldritchPurple('Eldritch Purple', Color(0xFF9C27B0), Color(0xFFBA68C8), lightPrimary: Color(0xFF7E22CE), lightAccent: Color(0xFFA855F7)),
  rangerEmerald('Ranger Emerald', Color(0xFF00E676), Color(0xFF69F0AE), lightPrimary: Color(0xFF047857), lightAccent: Color(0xFF059669)),
  necroticSlate('Necrotic Slate', Color(0xFF78909C), Color(0xFF90A4AE), lightPrimary: Color(0xFF475569), lightAccent: Color(0xFF64748B)),
  dragonfireCrimson('Dragonfire Crimson', Color(0xFFFF3D00), Color(0xFFFF6E40), lightPrimary: Color(0xFFC2410C), lightAccent: Color(0xFFEA580C)),
  arcaneSapphire('Arcane Sapphire', Color(0xFF2979FF), Color(0xFF82B1FF), lightPrimary: Color(0xFF1D4ED8), lightAccent: Color(0xFF2563EB)),
  bardicRose('Bardic Rose', Color(0xFFE91E63), Color(0xFFFF4081), lightPrimary: Color(0xFFBE123C), lightAccent: Color(0xFFE11D48)),
  abyssalTeal('Abyssal Teal', Color(0xFF00BFA5), Color(0xFF64FFDA), lightPrimary: Color(0xFF0F766E), lightAccent: Color(0xFF0D9488)),
  celestialAmber('Celestial Amber', Color(0xFFFF9100), Color(0xFFFFD180), lightPrimary: Color(0xFF92400E), lightAccent: Color(0xFFB45309));

  final String label;
  final Color primary;
  final Color accent;
  final Color lightPrimary;
  final Color lightAccent;

  const FantasyAccent(
    this.label,
    this.primary,
    this.accent, {
    Color? lightPrimary,
    Color? lightAccent,
  })  : lightPrimary = lightPrimary ?? primary,
        lightAccent = lightAccent ?? accent;

  Color getPrimary(bool isDarkMode) => isDarkMode ? primary : lightPrimary;
  Color getAccent(bool isDarkMode) => isDarkMode ? accent : lightAccent;
}

/// Haptic tactile feedback strength levels
enum HapticFeedbackLevel {
  off('Off'),
  light('Light (Tactile Ticks)'),
  heavy('Heavy (Combat Rumble)');

  final String label;
  const HapticFeedbackLevel(this.label);
}

/// Available guided character creation wizard step ordering flows
enum WizardOrderingPreset {
  classic2014('2014 Classic (Species First)'),
  modern2024('2024 Modern (Class First)'),
  attributesFirst('Attributes First (Scores First)');

  final String label;
  const WizardOrderingPreset(this.label);
}

/// Immutable user preferences and visual polish configuration
@immutable
class AppSettings {
  final ThemeMode themeMode;
  final FantasyAccent fantasyAccent;
  final bool oledPitchBlack;
  final HapticFeedbackLevel hapticLevel;
  final WizardOrderingPreset wizardOrderingPreset;
  final bool enableCritFumbleFx;
  final bool enableSpellParticles;
  final bool enable3dDiceOverlays;
  final bool enableGlyphAnimations;
  final bool performanceMode;
  final DmRulesEdition rulesEdition;
  final Set<String> pinnedRuleIds;
  final Set<String> pinnedSpellIds;
  final Set<String> pinnedMonsterIds;
  final Set<String> pinnedItemIds;
  final Set<String> bypassedHomebrewSlugs;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.fantasyAccent = FantasyAccent.paladinGold,
    this.oledPitchBlack = false,
    this.hapticLevel = HapticFeedbackLevel.light,
    this.wizardOrderingPreset = WizardOrderingPreset.classic2014,
    this.enableCritFumbleFx = true,
    this.enableSpellParticles = true,
    this.enable3dDiceOverlays = true,
    this.enableGlyphAnimations = true,
    this.performanceMode = false,
    this.rulesEdition = DmRulesEdition.v2024,
    this.pinnedRuleIds = const <String>{},
    this.pinnedSpellIds = const <String>{},
    this.pinnedMonsterIds = const <String>{},
    this.pinnedItemIds = const <String>{},
    this.bypassedHomebrewSlugs = const <String>{},
  });

  /// Whether particle and continuous visual FX are permitted to render
  bool get areParticlesAllowed => enableSpellParticles && !performanceMode;

  /// Whether critical hit and fumble animations are permitted to run
  bool get areCritFxAllowed => enableCritFumbleFx && !performanceMode;

  /// Whether creature and spell techno-rune glyph animations are permitted to run
  bool get areGlyphAnimationsAllowed => enableGlyphAnimations && !performanceMode;

  AppSettings copyWith({
    ThemeMode? themeMode,
    FantasyAccent? fantasyAccent,
    bool? oledPitchBlack,
    HapticFeedbackLevel? hapticLevel,
    WizardOrderingPreset? wizardOrderingPreset,
    bool? enableCritFumbleFx,
    bool? enableSpellParticles,
    bool? enable3dDiceOverlays,
    bool? enableGlyphAnimations,
    bool? performanceMode,
    DmRulesEdition? rulesEdition,
    Set<String>? pinnedRuleIds,
    Set<String>? pinnedSpellIds,
    Set<String>? pinnedMonsterIds,
    Set<String>? pinnedItemIds,
    Set<String>? bypassedHomebrewSlugs,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fantasyAccent: fantasyAccent ?? this.fantasyAccent,
      oledPitchBlack: oledPitchBlack ?? this.oledPitchBlack,
      hapticLevel: hapticLevel ?? this.hapticLevel,
      wizardOrderingPreset: wizardOrderingPreset ?? this.wizardOrderingPreset,
      enableCritFumbleFx: enableCritFumbleFx ?? this.enableCritFumbleFx,
      enableSpellParticles: enableSpellParticles ?? this.enableSpellParticles,
      enable3dDiceOverlays: enable3dDiceOverlays ?? this.enable3dDiceOverlays,
      enableGlyphAnimations: enableGlyphAnimations ?? this.enableGlyphAnimations,
      performanceMode: performanceMode ?? this.performanceMode,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      pinnedRuleIds: pinnedRuleIds ?? this.pinnedRuleIds,
      pinnedSpellIds: pinnedSpellIds ?? this.pinnedSpellIds,
      pinnedMonsterIds: pinnedMonsterIds ?? this.pinnedMonsterIds,
      pinnedItemIds: pinnedItemIds ?? this.pinnedItemIds,
      bypassedHomebrewSlugs: bypassedHomebrewSlugs ?? this.bypassedHomebrewSlugs,
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
          wizardOrderingPreset == other.wizardOrderingPreset &&
          enableCritFumbleFx == other.enableCritFumbleFx &&
          enableSpellParticles == other.enableSpellParticles &&
          enable3dDiceOverlays == other.enable3dDiceOverlays &&
          enableGlyphAnimations == other.enableGlyphAnimations &&
          performanceMode == other.performanceMode &&
          rulesEdition == other.rulesEdition &&
          setEquals(pinnedRuleIds, other.pinnedRuleIds) &&
          setEquals(pinnedSpellIds, other.pinnedSpellIds) &&
          setEquals(pinnedMonsterIds, other.pinnedMonsterIds) &&
          setEquals(pinnedItemIds, other.pinnedItemIds) &&
          setEquals(bypassedHomebrewSlugs, other.bypassedHomebrewSlugs);

  @override
  int get hashCode => Object.hash(
        themeMode,
        fantasyAccent,
        oledPitchBlack,
        hapticLevel,
        wizardOrderingPreset,
        enableCritFumbleFx,
        enableSpellParticles,
        enable3dDiceOverlays,
        enableGlyphAnimations,
        performanceMode,
        Object.hashAllUnordered(pinnedRuleIds),
        Object.hashAllUnordered(pinnedSpellIds),
        Object.hashAllUnordered(pinnedMonsterIds),
        Object.hashAllUnordered(pinnedItemIds),
        Object.hashAllUnordered(bypassedHomebrewSlugs),
      );
}
