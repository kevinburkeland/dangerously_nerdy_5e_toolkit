import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/dm_screen_data.dart';

/// Canonical list of 18 settings keys exported and restored by full app backups, in export order.
/// Intentionally excludes device-local `bypassedHomebrewSlugs`.
const List<String> kAppBackupSettingsKeys = [
  'themeMode',
  'fantasyAccent',
  'oledPitchBlack',
  'hapticLevel',
  'wizardOrderingPreset',
  'enableCritFumbleFx',
  'enableSpellParticles',
  'enable3dDiceOverlays',
  'enableGlyphAnimations',
  'performanceMode',
  'rulesEdition',
  'pinnedRuleIds',
  'pinnedSpellIds',
  'pinnedMonsterIds',
  'pinnedItemIds',
  'pinnedFeatIds',
  'pinnedClassIds',
  'pinnedRaceIds',
];

/// Result of decoding a backup's `settings` map onto an existing [AppSettings] base.
class AppBackupSettingsDecodeResult {
  final AppSettings settings;
  final int appliedCount;
  final List<String> skipped;

  const AppBackupSettingsDecodeResult({
    required this.settings,
    required this.appliedCount,
    required this.skipped,
  });
}

/// Encodes the 18 backup-eligible fields of [s] into a JSON-compatible map.
Map<String, dynamic> encodeAppBackupSettings(AppSettings s) {
  return <String, dynamic>{
    'themeMode': s.themeMode.name,
    'fantasyAccent': s.fantasyAccent.name,
    'oledPitchBlack': s.oledPitchBlack,
    'hapticLevel': s.hapticLevel.name,
    'wizardOrderingPreset': s.wizardOrderingPreset.name,
    'enableCritFumbleFx': s.enableCritFumbleFx,
    'enableSpellParticles': s.enableSpellParticles,
    'enable3dDiceOverlays': s.enable3dDiceOverlays,
    'enableGlyphAnimations': s.enableGlyphAnimations,
    'performanceMode': s.performanceMode,
    'rulesEdition': s.rulesEdition.name,
    'pinnedRuleIds': s.pinnedRuleIds.toList(),
    'pinnedSpellIds': s.pinnedSpellIds.toList(),
    'pinnedMonsterIds': s.pinnedMonsterIds.toList(),
    'pinnedItemIds': s.pinnedItemIds.toList(),
    'pinnedFeatIds': s.pinnedFeatIds.toList(),
    'pinnedClassIds': s.pinnedClassIds.toList(),
    'pinnedRaceIds': s.pinnedRaceIds.toList(),
  };
}

/// Decodes a backup `settings` map onto [base], validating each of the 18 keys
/// independently without touching `base.bypassedHomebrewSlugs`.
AppBackupSettingsDecodeResult decodeAppBackupSettings(
  Map<String, dynamic> raw, {
  required AppSettings base,
}) {
  var appliedCount = 0;
  final skipped = <String>[];

  T? parseEnum<T extends Enum>(String key, List<T> values) {
    if (!raw.containsKey(key)) return null;
    final val = raw[key];
    if (val is String) {
      for (final candidate in values) {
        if (candidate.name == val) {
          appliedCount++;
          return candidate;
        }
      }
    }
    skipped.add('settings.$key: invalid enum value $val');
    return null;
  }

  bool? parseBool(String key) {
    if (!raw.containsKey(key)) return null;
    final val = raw[key];
    if (val is bool) {
      appliedCount++;
      return val;
    }
    skipped.add('settings.$key: expected bool, got ${val.runtimeType}');
    return null;
  }

  Set<String>? parseStringSet(String key) {
    if (!raw.containsKey(key)) return null;
    final val = raw[key];
    if (val is! List) {
      skipped.add('settings.$key: expected List, got ${val.runtimeType}');
      return null;
    }
    final valid = <String>{};
    for (final element in val) {
      if (element is! String) {
        skipped.add(
          'settings.$key: expected List<String>, found ${element.runtimeType}',
        );
        return null;
      }
      valid.add(element);
    }
    appliedCount++;
    return valid;
  }

  final themeMode = parseEnum('themeMode', ThemeMode.values);
  final fantasyAccent = parseEnum('fantasyAccent', FantasyAccent.values);
  final oledPitchBlack = parseBool('oledPitchBlack');
  final hapticLevel = parseEnum('hapticLevel', HapticFeedbackLevel.values);
  final wizardOrderingPreset =
      parseEnum('wizardOrderingPreset', WizardOrderingPreset.values);
  final enableCritFumbleFx = parseBool('enableCritFumbleFx');
  final enableSpellParticles = parseBool('enableSpellParticles');
  final enable3dDiceOverlays = parseBool('enable3dDiceOverlays');
  final enableGlyphAnimations = parseBool('enableGlyphAnimations');
  final performanceMode = parseBool('performanceMode');
  final rulesEdition = parseEnum('rulesEdition', DmRulesEdition.values);
  final pinnedRuleIds = parseStringSet('pinnedRuleIds');
  final pinnedSpellIds = parseStringSet('pinnedSpellIds');
  final pinnedMonsterIds = parseStringSet('pinnedMonsterIds');
  final pinnedItemIds = parseStringSet('pinnedItemIds');
  final pinnedFeatIds = parseStringSet('pinnedFeatIds');
  final pinnedClassIds = parseStringSet('pinnedClassIds');
  final pinnedRaceIds = parseStringSet('pinnedRaceIds');

  final current = AppSettings(
    themeMode: themeMode ?? base.themeMode,
    fantasyAccent: fantasyAccent ?? base.fantasyAccent,
    oledPitchBlack: oledPitchBlack ?? base.oledPitchBlack,
    hapticLevel: hapticLevel ?? base.hapticLevel,
    wizardOrderingPreset: wizardOrderingPreset ?? base.wizardOrderingPreset,
    enableCritFumbleFx: enableCritFumbleFx ?? base.enableCritFumbleFx,
    enableSpellParticles: enableSpellParticles ?? base.enableSpellParticles,
    enable3dDiceOverlays: enable3dDiceOverlays ?? base.enable3dDiceOverlays,
    enableGlyphAnimations:
        enableGlyphAnimations ?? base.enableGlyphAnimations,
    performanceMode: performanceMode ?? base.performanceMode,
    rulesEdition: rulesEdition ?? base.rulesEdition,
    pinnedRuleIds: pinnedRuleIds ?? base.pinnedRuleIds,
    pinnedSpellIds: pinnedSpellIds ?? base.pinnedSpellIds,
    pinnedMonsterIds: pinnedMonsterIds ?? base.pinnedMonsterIds,
    pinnedItemIds: pinnedItemIds ?? base.pinnedItemIds,
    pinnedFeatIds: pinnedFeatIds ?? base.pinnedFeatIds,
    pinnedClassIds: pinnedClassIds ?? base.pinnedClassIds,
    pinnedRaceIds: pinnedRaceIds ?? base.pinnedRaceIds,
    bypassedHomebrewSlugs: base.bypassedHomebrewSlugs,
  );

  return AppBackupSettingsDecodeResult(
    settings: current,
    appliedCount: appliedCount,
    skipped: skipped,
  );
}
