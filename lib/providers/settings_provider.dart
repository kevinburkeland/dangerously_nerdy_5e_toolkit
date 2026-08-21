import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/dm_screen_data.dart';
import '../services/logging_service.dart';

class SettingsProvider extends ChangeNotifier {
  // Canonical v2 storage keys (string-based enums)
  static const _kThemeModeV2 = 'setting_theme_mode_v2';
  static const _kFantasyAccentV2 = 'setting_fantasy_accent_v2';
  static const _kHapticLevelV2 = 'setting_haptic_level_v2';
  static const _kRulesEditionV2 = 'setting_rules_edition_v2';

  // Boolean & Collection keys
  static const _kOledPitchBlack = 'setting_oled_pitch_black';
  static const _kCritFumbleFx = 'setting_crit_fumble_fx';
  static const _kSpellParticles = 'setting_spell_particles';
  static const _k3dDice = 'setting_3d_dice';
  static const _kGlyphAnimations = 'setting_enable_glyph_animations';
  static const _kPerformanceMode = 'setting_performance_mode';
  static const _kPinnedRuleIds = 'setting_pinned_rule_ids';
  static const _kPinnedSpellIds = 'setting_pinned_spell_ids';
  static const _kPinnedMonsterIds = 'setting_pinned_monster_ids';
  static const _kPinnedItemIds = 'setting_pinned_item_ids';

  // Legacy v1 keys (for fallback during in-flight upgrades)
  static const _kLegacyThemeMode = 'setting_theme_mode';
  static const _kLegacyFantasyAccent = 'setting_fantasy_accent';
  static const _kLegacyHapticLevel = 'setting_haptic_level';
  static const _kLegacyRulesEdition = 'setting_rules_edition';

  AppSettings _settings;
  AppSettings get settings => _settings;

  SettingsProvider({AppSettings initialSettings = const AppSettings(), bool autoLoad = true})
      : _settings = initialSettings {
    if (autoLoad && initialSettings == const AppSettings()) {
      reloadFromPreferences();
    }
  }

  /// Synchronously hydrates an [AppSettings] instance from pre-initialized [SharedPreferences].
  /// This prevents any Frame 1 flash-of-unstyled-content (FOUC) during app boot.
  static AppSettings hydrateFromPrefs(SharedPreferences prefs) {
    try {
      // 1. ThemeMode
      ThemeMode resolvedTheme = ThemeMode.dark;
      final themeStr = prefs.getString(_kThemeModeV2);
      if (themeStr != null) {
        resolvedTheme = ThemeMode.values.firstWhere(
          (e) => e.name == themeStr,
          orElse: () => ThemeMode.dark,
        );
      } else {
        final legacyIndex = prefs.getInt(_kLegacyThemeMode);
        if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < ThemeMode.values.length) {
          resolvedTheme = ThemeMode.values[legacyIndex];
        }
      }

      // 2. FantasyAccent
      FantasyAccent resolvedAccent = FantasyAccent.paladinGold;
      final accentStr = prefs.getString(_kFantasyAccentV2);
      if (accentStr != null) {
        resolvedAccent = FantasyAccent.values.firstWhere(
          (e) => e.name == accentStr,
          orElse: () => FantasyAccent.paladinGold,
        );
      } else {
        final legacyIndex = prefs.getInt(_kLegacyFantasyAccent);
        if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < FantasyAccent.values.length) {
          resolvedAccent = FantasyAccent.values[legacyIndex];
        }
      }

      // 3. HapticLevel
      HapticFeedbackLevel resolvedHaptic = HapticFeedbackLevel.light;
      final hapticStr = prefs.getString(_kHapticLevelV2);
      if (hapticStr != null) {
        resolvedHaptic = HapticFeedbackLevel.values.firstWhere(
          (e) => e.name == hapticStr,
          orElse: () => HapticFeedbackLevel.light,
        );
      } else {
        final legacyIndex = prefs.getInt(_kLegacyHapticLevel);
        if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < HapticFeedbackLevel.values.length) {
          resolvedHaptic = HapticFeedbackLevel.values[legacyIndex];
        }
      }

      // 4. RulesEdition
      DmRulesEdition resolvedEdition = DmRulesEdition.v2024;
      final editionStr = prefs.getString(_kRulesEditionV2);
      if (editionStr != null) {
        resolvedEdition = DmRulesEdition.values.firstWhere(
          (e) => e.name == editionStr,
          orElse: () => DmRulesEdition.v2024,
        );
      } else {
        final legacyIndex = prefs.getInt(_kLegacyRulesEdition);
        if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < DmRulesEdition.values.length) {
          resolvedEdition = DmRulesEdition.values[legacyIndex];
        }
      }

      final oled = prefs.getBool(_kOledPitchBlack);
      final critFx = prefs.getBool(_kCritFumbleFx);
      final particles = prefs.getBool(_kSpellParticles);
      final dice = prefs.getBool(_k3dDice);
      final glyphs = prefs.getBool(_kGlyphAnimations);
      final perf = prefs.getBool(_kPerformanceMode);
      final pinnedList = prefs.getStringList(_kPinnedRuleIds);
      final pinnedSpellList = prefs.getStringList(_kPinnedSpellIds);
      final pinnedMonsterList = prefs.getStringList(_kPinnedMonsterIds);
      final pinnedItemList = prefs.getStringList(_kPinnedItemIds);

      return AppSettings(
        themeMode: resolvedTheme,
        fantasyAccent: resolvedAccent,
        oledPitchBlack: oled ?? false,
        hapticLevel: resolvedHaptic,
        enableCritFumbleFx: critFx ?? true,
        enableSpellParticles: particles ?? true,
        enable3dDiceOverlays: dice ?? true,
        enableGlyphAnimations: glyphs ?? true,
        performanceMode: perf ?? false,
        rulesEdition: resolvedEdition,
        pinnedRuleIds: pinnedList?.toSet() ?? const <String>{},
        pinnedSpellIds: pinnedSpellList?.toSet() ?? const <String>{},
        pinnedMonsterIds: pinnedMonsterList?.toSet() ?? const <String>{},
        pinnedItemIds: pinnedItemList?.toSet() ?? const <String>{},
      );
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to hydrate AppSettings from SharedPreferences; using defaults',
      );
      return const AppSettings();
    }
  }

  /// Asynchronously reloads preferences from disk if needed.
  Future<void> reloadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _settings = hydrateFromPrefs(prefs);
      notifyListeners();
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to reload AppSettings from SharedPreferences',
      );
    }
  }

  /// Updates settings in-memory and flushes changes to persistent storage.
  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString(_kThemeModeV2, newSettings.themeMode.name),
        prefs.setString(_kFantasyAccentV2, newSettings.fantasyAccent.name),
        prefs.setBool(_kOledPitchBlack, newSettings.oledPitchBlack),
        prefs.setString(_kHapticLevelV2, newSettings.hapticLevel.name),
        prefs.setBool(_kCritFumbleFx, newSettings.enableCritFumbleFx),
        prefs.setBool(_kSpellParticles, newSettings.enableSpellParticles),
        prefs.setBool(_k3dDice, newSettings.enable3dDiceOverlays),
        prefs.setBool(_kGlyphAnimations, newSettings.enableGlyphAnimations),
        prefs.setBool(_kPerformanceMode, newSettings.performanceMode),
        prefs.setString(_kRulesEditionV2, newSettings.rulesEdition.name),
        prefs.setStringList(_kPinnedRuleIds, newSettings.pinnedRuleIds.toList()),
        prefs.setStringList(_kPinnedSpellIds, newSettings.pinnedSpellIds.toList()),
        prefs.setStringList(_kPinnedMonsterIds, newSettings.pinnedMonsterIds.toList()),
        prefs.setStringList(_kPinnedItemIds, newSettings.pinnedItemIds.toList()),
      ]);
    } catch (e, stackTrace) {
      LoggingService().logNonFatal(
        e,
        stackTrace,
        reason: 'Failed to persist updated AppSettings to SharedPreferences',
      );
    }
  }

  void setThemeMode(ThemeMode mode) => updateSettings(_settings.copyWith(themeMode: mode));
  void setFantasyAccent(FantasyAccent accent) => updateSettings(_settings.copyWith(fantasyAccent: accent));
  void setOledMode(bool value) => updateSettings(_settings.copyWith(oledPitchBlack: value));
  void setHapticLevel(HapticFeedbackLevel level) => updateSettings(_settings.copyWith(hapticLevel: level));
  void setCritFumbleFx(bool value) => updateSettings(_settings.copyWith(enableCritFumbleFx: value));
  void setSpellParticles(bool value) => updateSettings(_settings.copyWith(enableSpellParticles: value));
  void set3dDiceOverlays(bool value) => updateSettings(_settings.copyWith(enable3dDiceOverlays: value));
  void setGlyphAnimations(bool value) => updateSettings(_settings.copyWith(enableGlyphAnimations: value));
  void setPerformanceMode(bool value) => updateSettings(_settings.copyWith(performanceMode: value));
  void setRulesEdition(DmRulesEdition edition) => updateSettings(_settings.copyWith(rulesEdition: edition));

  // --- Generic Pinning Helpers ---
  Set<String> _toggleSetId(Set<String> current, String id) {
    final updated = Set<String>.from(current);
    if (!updated.remove(id)) {
      updated.add(id);
    }
    return updated;
  }

  Set<String> _addSetId(Set<String> current, String id) {
    if (current.contains(id)) return current;
    return Set<String>.from(current)..add(id);
  }

  Set<String> _removeSetId(Set<String> current, String id) {
    if (!current.contains(id)) return current;
    return Set<String>.from(current)..remove(id);
  }

  // --- Rules Pinning ---
  bool isRulePinned(String ruleId) => _settings.pinnedRuleIds.contains(ruleId);
  void togglePinRule(String ruleId) => updateSettings(_settings.copyWith(pinnedRuleIds: _toggleSetId(_settings.pinnedRuleIds, ruleId)));
  void pinRule(String ruleId) => updateSettings(_settings.copyWith(pinnedRuleIds: _addSetId(_settings.pinnedRuleIds, ruleId)));
  void unpinRule(String ruleId) => updateSettings(_settings.copyWith(pinnedRuleIds: _removeSetId(_settings.pinnedRuleIds, ruleId)));
  void clearPinnedRules() => _settings.pinnedRuleIds.isEmpty ? null : updateSettings(_settings.copyWith(pinnedRuleIds: const <String>{}));

  // --- Spells Pinning ---
  bool isSpellPinned(String spellId) => _settings.pinnedSpellIds.contains(spellId);
  void togglePinSpell(String spellId) => updateSettings(_settings.copyWith(pinnedSpellIds: _toggleSetId(_settings.pinnedSpellIds, spellId)));
  void pinSpell(String spellId) => updateSettings(_settings.copyWith(pinnedSpellIds: _addSetId(_settings.pinnedSpellIds, spellId)));
  void unpinSpell(String spellId) => updateSettings(_settings.copyWith(pinnedSpellIds: _removeSetId(_settings.pinnedSpellIds, spellId)));
  void clearPinnedSpells() => _settings.pinnedSpellIds.isEmpty ? null : updateSettings(_settings.copyWith(pinnedSpellIds: const <String>{}));

  // --- Monsters Pinning ---
  bool isMonsterPinned(String monsterId) => _settings.pinnedMonsterIds.contains(monsterId);
  void togglePinMonster(String monsterId) => updateSettings(_settings.copyWith(pinnedMonsterIds: _toggleSetId(_settings.pinnedMonsterIds, monsterId)));
  void pinMonster(String monsterId) => updateSettings(_settings.copyWith(pinnedMonsterIds: _addSetId(_settings.pinnedMonsterIds, monsterId)));
  void unpinMonster(String monsterId) => updateSettings(_settings.copyWith(pinnedMonsterIds: _removeSetId(_settings.pinnedMonsterIds, monsterId)));
  void clearPinnedMonsters() => _settings.pinnedMonsterIds.isEmpty ? null : updateSettings(_settings.copyWith(pinnedMonsterIds: const <String>{}));

  // --- Magic Items Pinning ---
  bool isItemPinned(String itemId) => _settings.pinnedItemIds.contains(itemId);
  void togglePinItem(String itemId) => updateSettings(_settings.copyWith(pinnedItemIds: _toggleSetId(_settings.pinnedItemIds, itemId)));
  void pinItem(String itemId) => updateSettings(_settings.copyWith(pinnedItemIds: _addSetId(_settings.pinnedItemIds, itemId)));
  void unpinItem(String itemId) => updateSettings(_settings.copyWith(pinnedItemIds: _removeSetId(_settings.pinnedItemIds, itemId)));
  void clearPinnedItems() => _settings.pinnedItemIds.isEmpty ? null : updateSettings(_settings.copyWith(pinnedItemIds: const <String>{}));
}

class SettingsScope extends InheritedNotifier<SettingsProvider> {
  const SettingsScope({
    super.key,
    required SettingsProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static final SettingsProvider _fallbackProvider = SettingsProvider();

  /// Obtains the [SettingsProvider], falling back safely to a default instance
  /// if no [SettingsScope] is present in the widget tree (e.g. during headless widget tests).
  static SettingsProvider of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<SettingsScope>()
        : context.getInheritedWidgetOfExactType<SettingsScope>();
    return scope?.notifier ?? _fallbackProvider;
  }

  /// Direct accessor for current immutable [AppSettings].
  static AppSettings settingsOf(BuildContext context, {bool listen = true}) {
    return of(context, listen: listen).settings;
  }

  static SettingsProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
  }
}
