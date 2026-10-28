import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

/// Pool of test IDs including an ID with a space, one with non-ASCII letters,
/// and one 60 characters long.
const List<String> kSettingsTestIdPool = [
  'alpha_id',
  'id with space',
  'élan_rune_ö',
  'sixty_char_id_0123456789_abcdefghijklmnopqrstuvwxyz_01234567',
  'zeta_id',
];

/// Builds an [AppSettings] from `Random(seed)`: every enum field picks any of its values,
/// every bool is random, and each of the eight string sets gets 0 to 3 IDs from [kSettingsTestIdPool].
AppSettings randomSettings(int seed) {
  final rng = Random(seed);

  T pickEnum<T extends Enum>(List<T> values) =>
      values[rng.nextInt(values.length)];

  Set<String> pickSet() {
    final count = rng.nextInt(4); // 0 to 3
    final result = <String>{};
    for (var i = 0; i < count; i++) {
      result.add(kSettingsTestIdPool[rng.nextInt(kSettingsTestIdPool.length)]);
    }
    return result;
  }

  return AppSettings(
    themeMode: pickEnum(ThemeMode.values),
    fantasyAccent: pickEnum(FantasyAccent.values),
    oledPitchBlack: rng.nextBool(),
    hapticLevel: pickEnum(HapticFeedbackLevel.values),
    wizardOrderingPreset: pickEnum(WizardOrderingPreset.values),
    enableCritFumbleFx: rng.nextBool(),
    enableSpellParticles: rng.nextBool(),
    enable3dDiceOverlays: rng.nextBool(),
    enableGlyphAnimations: rng.nextBool(),
    performanceMode: rng.nextBool(),
    rulesEdition: pickEnum(DmRulesEdition.values),
    pinnedRuleIds: pickSet(),
    pinnedSpellIds: pickSet(),
    pinnedMonsterIds: pickSet(),
    pinnedItemIds: pickSet(),
    pinnedFeatIds: pickSet(),
    pinnedClassIds: pickSet(),
    pinnedRaceIds: pickSet(),
    bypassedHomebrewSlugs: pickSet(),
  );
}

/// Returns settings that differ from [s] in every field: each enum takes the next value
/// (wrapping round), each bool is negated, and each set becomes a set not equal to it.
AppSettings opposite(AppSettings s) {
  T nextEnum<T extends Enum>(T current, List<T> values) =>
      values[(values.indexOf(current) + 1) % values.length];

  Set<String> flipSet(Set<String> current) =>
      current.isEmpty ? const {'opposite-id'} : const <String>{};

  return AppSettings(
    themeMode: nextEnum(s.themeMode, ThemeMode.values),
    fantasyAccent: nextEnum(s.fantasyAccent, FantasyAccent.values),
    oledPitchBlack: !s.oledPitchBlack,
    hapticLevel: nextEnum(s.hapticLevel, HapticFeedbackLevel.values),
    wizardOrderingPreset:
        nextEnum(s.wizardOrderingPreset, WizardOrderingPreset.values),
    enableCritFumbleFx: !s.enableCritFumbleFx,
    enableSpellParticles: !s.enableSpellParticles,
    enable3dDiceOverlays: !s.enable3dDiceOverlays,
    enableGlyphAnimations: !s.enableGlyphAnimations,
    performanceMode: !s.performanceMode,
    rulesEdition: nextEnum(s.rulesEdition, DmRulesEdition.values),
    pinnedRuleIds: flipSet(s.pinnedRuleIds),
    pinnedSpellIds: flipSet(s.pinnedSpellIds),
    pinnedMonsterIds: flipSet(s.pinnedMonsterIds),
    pinnedItemIds: flipSet(s.pinnedItemIds),
    pinnedFeatIds: flipSet(s.pinnedFeatIds),
    pinnedClassIds: flipSet(s.pinnedClassIds),
    pinnedRaceIds: flipSet(s.pinnedRaceIds),
    bypassedHomebrewSlugs: flipSet(s.bypassedHomebrewSlugs),
  );
}

/// Compares [expected] and [actual] field by field and returns the first field name
/// and values that differ, or `null` if all 19 fields are equal.
String? firstSettingsDiff(AppSettings expected, AppSettings actual) {
  if (expected.themeMode != actual.themeMode) {
    return 'themeMode (expected ${expected.themeMode}, got ${actual.themeMode})';
  }
  if (expected.fantasyAccent != actual.fantasyAccent) {
    return 'fantasyAccent (expected ${expected.fantasyAccent}, got ${actual.fantasyAccent})';
  }
  if (expected.oledPitchBlack != actual.oledPitchBlack) {
    return 'oledPitchBlack (expected ${expected.oledPitchBlack}, got ${actual.oledPitchBlack})';
  }
  if (expected.hapticLevel != actual.hapticLevel) {
    return 'hapticLevel (expected ${expected.hapticLevel}, got ${actual.hapticLevel})';
  }
  if (expected.wizardOrderingPreset != actual.wizardOrderingPreset) {
    return 'wizardOrderingPreset (expected ${expected.wizardOrderingPreset}, got ${actual.wizardOrderingPreset})';
  }
  if (expected.enableCritFumbleFx != actual.enableCritFumbleFx) {
    return 'enableCritFumbleFx (expected ${expected.enableCritFumbleFx}, got ${actual.enableCritFumbleFx})';
  }
  if (expected.enableSpellParticles != actual.enableSpellParticles) {
    return 'enableSpellParticles (expected ${expected.enableSpellParticles}, got ${actual.enableSpellParticles})';
  }
  if (expected.enable3dDiceOverlays != actual.enable3dDiceOverlays) {
    return 'enable3dDiceOverlays (expected ${expected.enable3dDiceOverlays}, got ${actual.enable3dDiceOverlays})';
  }
  if (expected.enableGlyphAnimations != actual.enableGlyphAnimations) {
    return 'enableGlyphAnimations (expected ${expected.enableGlyphAnimations}, got ${actual.enableGlyphAnimations})';
  }
  if (expected.performanceMode != actual.performanceMode) {
    return 'performanceMode (expected ${expected.performanceMode}, got ${actual.performanceMode})';
  }
  if (expected.rulesEdition != actual.rulesEdition) {
    return 'rulesEdition (expected ${expected.rulesEdition}, got ${actual.rulesEdition})';
  }
  if (!setEquals(expected.pinnedRuleIds, actual.pinnedRuleIds)) {
    return 'pinnedRuleIds (expected ${expected.pinnedRuleIds}, got ${actual.pinnedRuleIds})';
  }
  if (!setEquals(expected.pinnedSpellIds, actual.pinnedSpellIds)) {
    return 'pinnedSpellIds (expected ${expected.pinnedSpellIds}, got ${actual.pinnedSpellIds})';
  }
  if (!setEquals(expected.pinnedMonsterIds, actual.pinnedMonsterIds)) {
    return 'pinnedMonsterIds (expected ${expected.pinnedMonsterIds}, got ${actual.pinnedMonsterIds})';
  }
  if (!setEquals(expected.pinnedItemIds, actual.pinnedItemIds)) {
    return 'pinnedItemIds (expected ${expected.pinnedItemIds}, got ${actual.pinnedItemIds})';
  }
  if (!setEquals(expected.pinnedFeatIds, actual.pinnedFeatIds)) {
    return 'pinnedFeatIds (expected ${expected.pinnedFeatIds}, got ${actual.pinnedFeatIds})';
  }
  if (!setEquals(expected.pinnedClassIds, actual.pinnedClassIds)) {
    return 'pinnedClassIds (expected ${expected.pinnedClassIds}, got ${actual.pinnedClassIds})';
  }
  if (!setEquals(expected.pinnedRaceIds, actual.pinnedRaceIds)) {
    return 'pinnedRaceIds (expected ${expected.pinnedRaceIds}, got ${actual.pinnedRaceIds})';
  }
  if (!setEquals(
      expected.bypassedHomebrewSlugs, actual.bypassedHomebrewSlugs)) {
    return 'bypassedHomebrewSlugs (expected ${expected.bypassedHomebrewSlugs}, got ${actual.bypassedHomebrewSlugs})';
  }
  return null;
}

/// Known non-default settings value `c` used by SR3 example tests.
const AppSettings kKnownNonDefaultSettings = AppSettings(
  themeMode: ThemeMode.system,
  fantasyAccent: FantasyAccent.celestialAmber,
  oledPitchBlack: true,
  hapticLevel: HapticFeedbackLevel.heavy,
  wizardOrderingPreset: WizardOrderingPreset.attributesFirst,
  enableCritFumbleFx: false,
  enableSpellParticles: false,
  enable3dDiceOverlays: false,
  enableGlyphAnimations: false,
  performanceMode: true,
  rulesEdition: DmRulesEdition.v2014,
  pinnedRuleIds: {'rule_a', 'rule_b'},
  pinnedSpellIds: {'spell_a'},
  pinnedMonsterIds: {'monster_a'},
  pinnedItemIds: {'item_a'},
  pinnedFeatIds: {'feat_a'},
  pinnedClassIds: {'class_a'},
  pinnedRaceIds: {'race_a'},
  bypassedHomebrewSlugs: {'hb_keep_me'},
);
