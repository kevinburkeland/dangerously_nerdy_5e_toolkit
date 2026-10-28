import 'package:flutter/material.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/app_settings.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/dm_screen_data.dart';

/// Shared non-default AppSettings constant that differs from `const AppSettings()`
/// in every one of the 18 exported backup settings fields, and also sets
/// `bypassedHomebrewSlugs: {'hb_keep_me'}` to verify restore does not touch it.
const AppSettings kDistinctNonDefaultSettings = AppSettings(
  themeMode: ThemeMode.light,
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
