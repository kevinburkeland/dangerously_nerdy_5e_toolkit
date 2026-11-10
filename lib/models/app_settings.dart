import 'package:meta/meta.dart';
import 'dm_screen_data.dart';
import 'visual/argb.dart';

/// System theme appearance preference mode.
enum ThemeMode {
  system,
  light,
  dark,
}

/// Available fantasy accent palettes with distinct primary and secondary luminescence
enum FantasyAccent {
  paladinGold('Paladin Gold', Argb(0xFF112233), Argb(0xFFFFD54F),
      lightPrimary: Argb(0xFF92400E), lightAccent: Argb(0xFFB45309)),
  eldritchPurple('Eldritch Purple', Argb(0xFF9C27B0), Argb(0xFFBA68C8),
      lightPrimary: Argb(0xFF7E22CE), lightAccent: Argb(0xFFA855F7)),
  rangerEmerald('Ranger Emerald', Argb(0xFF00E676), Argb(0xFF69F0AE),
      lightPrimary: Argb(0xFF047857), lightAccent: Argb(0xFF059669)),
  necroticSlate('Necrotic Slate', Argb(0xFF78909C), Argb(0xFF90A4AE),
      lightPrimary: Argb(0xFF475569), lightAccent: Argb(0xFF64748B)),
  dragonfireCrimson('Dragonfire Crimson', Argb(0xFFFF3D00), Argb(0xFFFF6E40),
      lightPrimary: Argb(0xFFC2410C), lightAccent: Argb(0xFFEA580C)),
  arcaneSapphire('Arcane Sapphire', Argb(0xFF2979FF), Argb(0xFF82B1FF),
      lightPrimary: Argb(0xFF1D4ED8), lightAccent: Argb(0xFF2563EB)),
  bardicRose('Bardic Rose', Argb(0xFFE91E63), Argb(0xFFFF4081),
      lightPrimary: Argb(0xFFBE123C), lightAccent: Argb(0xFFE11D48)),
  abyssalTeal('Abyssal Teal', Argb(0xFF00BFA5), Argb(0xFF64FFDA),
      lightPrimary: Argb(0xFF0F766E), lightAccent: Argb(0xFF0D9488)),
  celestialAmber('Celestial Amber', Argb(0xFFFF9100), Argb(0xFFFFD180),
      lightPrimary: Argb(0xFF92400E), lightAccent: Argb(0xFFB45309));

  final String label;
  final Argb primaryArgb;
  final Argb accentArgb;
  final Argb lightPrimaryArgb;
  final Argb lightAccentArgb;

  const FantasyAccent(
    this.label,
    this.primaryArgb,
    this.accentArgb, {
    Argb? lightPrimary,
    Argb? lightAccent,
  })  : lightPrimaryArgb = lightPrimary ?? primaryArgb,
        lightAccentArgb = lightAccent ?? accentArgb;

  Argb getPrimaryArgb(bool isDarkMode) =>
      isDarkMode ? primaryArgb : lightPrimaryArgb;
  Argb getAccentArgb(bool isDarkMode) =>
      isDarkMode ? accentArgb : lightAccentArgb;
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
  final Set<String> pinnedFeatIds;
  final Set<String> pinnedClassIds;
  final Set<String> pinnedRaceIds;
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
    this.pinnedFeatIds = const <String>{},
    this.pinnedClassIds = const <String>{},
    this.pinnedRaceIds = const <String>{},
    this.bypassedHomebrewSlugs = const <String>{},
  });

  /// Whether particle and continuous visual FX are permitted to render
  bool get areParticlesAllowed => enableSpellParticles && !performanceMode;

  /// Whether critical hit and fumble animations are permitted to run
  bool get areCritFxAllowed => enableCritFumbleFx && !performanceMode;

  /// Whether creature and spell techno-rune glyph animations are permitted to run
  bool get areGlyphAnimationsAllowed =>
      enableGlyphAnimations && !performanceMode;

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
    Set<String>? pinnedFeatIds,
    Set<String>? pinnedClassIds,
    Set<String>? pinnedRaceIds,
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
      enableGlyphAnimations:
          enableGlyphAnimations ?? this.enableGlyphAnimations,
      performanceMode: performanceMode ?? this.performanceMode,
      rulesEdition: rulesEdition ?? this.rulesEdition,
      pinnedRuleIds: pinnedRuleIds ?? this.pinnedRuleIds,
      pinnedSpellIds: pinnedSpellIds ?? this.pinnedSpellIds,
      pinnedMonsterIds: pinnedMonsterIds ?? this.pinnedMonsterIds,
      pinnedItemIds: pinnedItemIds ?? this.pinnedItemIds,
      pinnedFeatIds: pinnedFeatIds ?? this.pinnedFeatIds,
      pinnedClassIds: pinnedClassIds ?? this.pinnedClassIds,
      pinnedRaceIds: pinnedRaceIds ?? this.pinnedRaceIds,
      bypassedHomebrewSlugs:
          bypassedHomebrewSlugs ?? this.bypassedHomebrewSlugs,
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
          _setEquals(pinnedRuleIds, other.pinnedRuleIds) &&
          _setEquals(pinnedSpellIds, other.pinnedSpellIds) &&
          _setEquals(pinnedMonsterIds, other.pinnedMonsterIds) &&
          _setEquals(pinnedItemIds, other.pinnedItemIds) &&
          _setEquals(pinnedFeatIds, other.pinnedFeatIds) &&
          _setEquals(pinnedClassIds, other.pinnedClassIds) &&
          _setEquals(pinnedRaceIds, other.pinnedRaceIds) &&
          _setEquals(bypassedHomebrewSlugs, other.bypassedHomebrewSlugs);

  static bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

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
        Object.hashAllUnordered(pinnedFeatIds),
        Object.hashAllUnordered(pinnedClassIds),
        Object.hashAllUnordered(pinnedRaceIds),
        Object.hashAllUnordered(bypassedHomebrewSlugs),
      );
}
