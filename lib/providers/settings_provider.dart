import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/dm_screen_data.dart';
import '../services/rules/dnd_5e_rules_engine.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'setting_theme_mode';
  static const _kFantasyAccent = 'setting_fantasy_accent';
  static const _kOledPitchBlack = 'setting_oled_pitch_black';
  static const _kHapticLevel = 'setting_haptic_level';
  static const _kCritFumbleFx = 'setting_crit_fumble_fx';
  static const _kSpellParticles = 'setting_spell_particles';
  static const _k3dDice = 'setting_3d_dice';
  static const _kPerformanceMode = 'setting_performance_mode';
  static const _kRulesEdition = 'setting_rules_edition';
  static const _kPinnedRuleIds = 'setting_pinned_rule_ids';

  AppSettings _settings;
  AppSettings get settings => _settings;

  SettingsProvider({AppSettings initialSettings = const AppSettings()})
      : _settings = initialSettings {
    _loadFromPreferences();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_kThemeMode);
    final accentIndex = prefs.getInt(_kFantasyAccent);
    final oled = prefs.getBool(_kOledPitchBlack);
    final hapticIndex = prefs.getInt(_kHapticLevel);
    final critFx = prefs.getBool(_kCritFumbleFx);
    final particles = prefs.getBool(_kSpellParticles);
    final dice = prefs.getBool(_k3dDice);
    final perf = prefs.getBool(_kPerformanceMode);
    final editionIndex = prefs.getInt(_kRulesEdition);
    final pinnedList = prefs.getStringList(_kPinnedRuleIds);

    _settings = AppSettings(
      themeMode: ThemeMode.values.safeByIndex(themeIndex, _settings.themeMode),
      fantasyAccent: FantasyAccent.values.safeByIndex(accentIndex, _settings.fantasyAccent),
      oledPitchBlack: oled ?? _settings.oledPitchBlack,
      hapticLevel: HapticFeedbackLevel.values.safeByIndex(hapticIndex, _settings.hapticLevel),
      enableCritFumbleFx: critFx ?? _settings.enableCritFumbleFx,
      enableSpellParticles: particles ?? _settings.enableSpellParticles,
      enable3dDiceOverlays: dice ?? _settings.enable3dDiceOverlays,
      performanceMode: perf ?? _settings.performanceMode,
      rulesEdition: DmRulesEdition.values.safeByIndex(editionIndex, _settings.rulesEdition),
      pinnedRuleIds: pinnedList?.toSet() ?? _settings.pinnedRuleIds,
    );
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    _settings = newSettings;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setInt(_kThemeMode, newSettings.themeMode.index),
      prefs.setInt(_kFantasyAccent, newSettings.fantasyAccent.index),
      prefs.setBool(_kOledPitchBlack, newSettings.oledPitchBlack),
      prefs.setInt(_kHapticLevel, newSettings.hapticLevel.index),
      prefs.setBool(_kCritFumbleFx, newSettings.enableCritFumbleFx),
      prefs.setBool(_kSpellParticles, newSettings.enableSpellParticles),
      prefs.setBool(_k3dDice, newSettings.enable3dDiceOverlays),
      prefs.setBool(_kPerformanceMode, newSettings.performanceMode),
      prefs.setInt(_kRulesEdition, newSettings.rulesEdition.index),
      prefs.setStringList(_kPinnedRuleIds, newSettings.pinnedRuleIds.toList()),
    ]);
  }

  void setThemeMode(ThemeMode mode) => updateSettings(_settings.copyWith(themeMode: mode));
  void setFantasyAccent(FantasyAccent accent) => updateSettings(_settings.copyWith(fantasyAccent: accent));
  void setOledMode(bool value) => updateSettings(_settings.copyWith(oledPitchBlack: value));
  void setHapticLevel(HapticFeedbackLevel level) => updateSettings(_settings.copyWith(hapticLevel: level));
  void setCritFumbleFx(bool value) => updateSettings(_settings.copyWith(enableCritFumbleFx: value));
  void setSpellParticles(bool value) => updateSettings(_settings.copyWith(enableSpellParticles: value));
  void set3dDiceOverlays(bool value) => updateSettings(_settings.copyWith(enable3dDiceOverlays: value));
  void setPerformanceMode(bool value) => updateSettings(_settings.copyWith(performanceMode: value));
  void setRulesEdition(DmRulesEdition edition) => updateSettings(_settings.copyWith(rulesEdition: edition));

  bool isRulePinned(String ruleId) => _settings.pinnedRuleIds.contains(ruleId);

  void togglePinRule(String ruleId) {
    final updated = Set<String>.from(_settings.pinnedRuleIds);
    if (updated.contains(ruleId)) {
      updated.remove(ruleId);
    } else {
      updated.add(ruleId);
    }
    updateSettings(_settings.copyWith(pinnedRuleIds: updated));
  }

  void pinRule(String ruleId) {
    if (_settings.pinnedRuleIds.contains(ruleId)) return;
    final updated = Set<String>.from(_settings.pinnedRuleIds)..add(ruleId);
    updateSettings(_settings.copyWith(pinnedRuleIds: updated));
  }

  void unpinRule(String ruleId) {
    if (!_settings.pinnedRuleIds.contains(ruleId)) return;
    final updated = Set<String>.from(_settings.pinnedRuleIds)..remove(ruleId);
    updateSettings(_settings.copyWith(pinnedRuleIds: updated));
  }

  void clearPinnedRules() {
    if (_settings.pinnedRuleIds.isEmpty) return;
    updateSettings(_settings.copyWith(pinnedRuleIds: const <String>{}));
  }
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
