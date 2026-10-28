import 'package:flutter/material.dart';
import '../../models/app_settings.dart';
import '../../models/dm_screen_data.dart';

/// Supported types of settings values handled by backup codec.
enum AppBackupSettingsFieldKind {
  enumValue,
  boolean,
  stringSet,
}

/// Metadata, getter, setter and serializer for a single backup-eligible setting.
class AppBackupSettingsField {
  final String key;
  final AppBackupSettingsFieldKind kind;
  final Object Function(AppSettings s) getter;
  final AppSettings Function(AppSettings s, dynamic value) setter;
  final List<Enum>? enumValues;

  const AppBackupSettingsField._({
    required this.key,
    required this.kind,
    required this.getter,
    required this.setter,
    this.enumValues,
  });

  static AppBackupSettingsField forEnum<E extends Enum>({
    required String key,
    required List<E> values,
    required E Function(AppSettings s) getter,
    required AppSettings Function(AppSettings s, E value) setter,
  }) {
    return AppBackupSettingsField._(
      key: key,
      kind: AppBackupSettingsFieldKind.enumValue,
      getter: getter,
      setter: (s, dynamic v) => setter(s, v as E),
      enumValues: values,
    );
  }

  static AppBackupSettingsField forBool({
    required String key,
    required bool Function(AppSettings s) getter,
    required AppSettings Function(AppSettings s, bool value) setter,
  }) {
    return AppBackupSettingsField._(
      key: key,
      kind: AppBackupSettingsFieldKind.boolean,
      getter: getter,
      setter: (s, dynamic v) => setter(s, v as bool),
    );
  }

  static AppBackupSettingsField forStringSet({
    required String key,
    required Set<String> Function(AppSettings s) getter,
    required AppSettings Function(AppSettings s, Set<String> value) setter,
  }) {
    return AppBackupSettingsField._(
      key: key,
      kind: AppBackupSettingsFieldKind.stringSet,
      getter: getter,
      setter: (s, dynamic v) => setter(s, v as Set<String>),
    );
  }

  dynamic encode(AppSettings s) {
    switch (kind) {
      case AppBackupSettingsFieldKind.enumValue:
        return (getter(s) as Enum).name;
      case AppBackupSettingsFieldKind.boolean:
        return getter(s) as bool;
      case AppBackupSettingsFieldKind.stringSet:
        return (getter(s) as Set<String>).toList();
    }
  }

  (dynamic, String?) decode(dynamic rawVal) {
    switch (kind) {
      case AppBackupSettingsFieldKind.enumValue:
        if (rawVal is String) {
          for (final candidate in enumValues!) {
            if (candidate.name == rawVal) {
              return (candidate, null);
            }
          }
        }
        return (null, 'settings.$key: invalid enum value $rawVal');
      case AppBackupSettingsFieldKind.boolean:
        if (rawVal is bool) {
          return (rawVal, null);
        }
        return (null, 'settings.$key: expected bool, got ${rawVal.runtimeType}');
      case AppBackupSettingsFieldKind.stringSet:
        if (rawVal is! List) {
          return (null, 'settings.$key: expected List, got ${rawVal.runtimeType}');
        }
        final valid = <String>{};
        for (final element in rawVal) {
          if (element is! String) {
            return (
              null,
              'settings.$key: expected List<String>, found ${element.runtimeType}',
            );
          }
          valid.add(element);
        }
        return (valid, null);
    }
  }

  AppSettings apply(AppSettings s, dynamic value) {
    return setter(s, value);
  }
}

/// Canonical list of 18 settings fields exported and restored by full app backups, in export order.
/// Intentionally excludes device-local `bypassedHomebrewSlugs`.
final List<AppBackupSettingsField> kAppBackupSettingsFields = [
  AppBackupSettingsField.forEnum<ThemeMode>(
    key: 'themeMode',
    values: ThemeMode.values,
    getter: (s) => s.themeMode,
    setter: (s, v) => s.copyWith(themeMode: v),
  ),
  AppBackupSettingsField.forEnum<FantasyAccent>(
    key: 'fantasyAccent',
    values: FantasyAccent.values,
    getter: (s) => s.fantasyAccent,
    setter: (s, v) => s.copyWith(fantasyAccent: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'oledPitchBlack',
    getter: (s) => s.oledPitchBlack,
    setter: (s, v) => s.copyWith(oledPitchBlack: v),
  ),
  AppBackupSettingsField.forEnum<HapticFeedbackLevel>(
    key: 'hapticLevel',
    values: HapticFeedbackLevel.values,
    getter: (s) => s.hapticLevel,
    setter: (s, v) => s.copyWith(hapticLevel: v),
  ),
  AppBackupSettingsField.forEnum<WizardOrderingPreset>(
    key: 'wizardOrderingPreset',
    values: WizardOrderingPreset.values,
    getter: (s) => s.wizardOrderingPreset,
    setter: (s, v) => s.copyWith(wizardOrderingPreset: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'enableCritFumbleFx',
    getter: (s) => s.enableCritFumbleFx,
    setter: (s, v) => s.copyWith(enableCritFumbleFx: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'enableSpellParticles',
    getter: (s) => s.enableSpellParticles,
    setter: (s, v) => s.copyWith(enableSpellParticles: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'enable3dDiceOverlays',
    getter: (s) => s.enable3dDiceOverlays,
    setter: (s, v) => s.copyWith(enable3dDiceOverlays: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'enableGlyphAnimations',
    getter: (s) => s.enableGlyphAnimations,
    setter: (s, v) => s.copyWith(enableGlyphAnimations: v),
  ),
  AppBackupSettingsField.forBool(
    key: 'performanceMode',
    getter: (s) => s.performanceMode,
    setter: (s, v) => s.copyWith(performanceMode: v),
  ),
  AppBackupSettingsField.forEnum<DmRulesEdition>(
    key: 'rulesEdition',
    values: DmRulesEdition.values,
    getter: (s) => s.rulesEdition,
    setter: (s, v) => s.copyWith(rulesEdition: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedRuleIds',
    getter: (s) => s.pinnedRuleIds,
    setter: (s, v) {
      final copy = s.copyWith;
      return copy(pinnedRuleIds: v);
    },
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedSpellIds',
    getter: (s) => s.pinnedSpellIds,
    setter: (s, v) => s.copyWith(pinnedSpellIds: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedMonsterIds',
    getter: (s) => s.pinnedMonsterIds,
    setter: (s, v) => s.copyWith(pinnedMonsterIds: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedItemIds',
    getter: (s) => s.pinnedItemIds,
    setter: (s, v) => s.copyWith(pinnedItemIds: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedFeatIds',
    getter: (s) => s.pinnedFeatIds,
    setter: (s, v) => s.copyWith(pinnedFeatIds: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedClassIds',
    getter: (s) => s.pinnedClassIds,
    setter: (s, v) => s.copyWith(pinnedClassIds: v),
  ),
  AppBackupSettingsField.forStringSet(
    key: 'pinnedRaceIds',
    getter: (s) => s.pinnedRaceIds,
    setter: (s, v) => s.copyWith(pinnedRaceIds: v),
  ),
];

/// Canonical list of 18 settings keys exported and restored by full app backups, derived from [kAppBackupSettingsFields].
List<String> get kAppBackupSettingsKeys =>
    kAppBackupSettingsFields.map((f) => f.key).toList();

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
  final result = <String, dynamic>{};
  for (final field in kAppBackupSettingsFields) {
    result[field.key] = field.encode(s);
  }
  return result;
}

/// Decodes a backup `settings` map onto [base], validating each of the 18 keys
/// independently without touching `base.bypassedHomebrewSlugs`.
AppBackupSettingsDecodeResult decodeAppBackupSettings(
  Map<String, dynamic> raw, {
  required AppSettings base,
}) {
  var appliedCount = 0;
  final skipped = <String>[];
  var current = base;

  for (final field in kAppBackupSettingsFields) {
    if (!raw.containsKey(field.key)) continue;
    final val = raw[field.key];
    final (decoded, error) = field.decode(val);
    if (error != null) {
      skipped.add(error);
    } else if (decoded != null) {
      current = field.apply(current, decoded);
      appliedCount++;
    }
  }

  current = current.copyWith(
    bypassedHomebrewSlugs: base.bypassedHomebrewSlugs,
  );

  return AppBackupSettingsDecodeResult(
    settings: current,
    appliedCount: appliedCount,
    skipped: skipped,
  );
}
