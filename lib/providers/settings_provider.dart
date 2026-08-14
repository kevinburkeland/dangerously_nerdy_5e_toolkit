import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kThemeMode = 'setting_theme_mode';
  static const _kFantasyAccent = 'setting_fantasy_accent';
  static const _kOledPitchBlack = 'setting_oled_pitch_black';
  static const _kHapticLevel = 'setting_haptic_level';
  static const _kCritFumbleFx = 'setting_crit_fumble_fx';
  static const _kSpellParticles = 'setting_spell_particles';
  static const _k3dDice = 'setting_3d_dice';
  static const _kPerformanceMode = 'setting_performance_mode';

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

    _settings = AppSettings(
      themeMode: themeIndex != null && themeIndex >= 0 && themeIndex < ThemeMode.values.length
          ? ThemeMode.values[themeIndex]
          : _settings.themeMode,
      fantasyAccent: accentIndex != null && accentIndex >= 0 && accentIndex < FantasyAccent.values.length
          ? FantasyAccent.values[accentIndex]
          : _settings.fantasyAccent,
      oledPitchBlack: oled ?? _settings.oledPitchBlack,
      hapticLevel: hapticIndex != null && hapticIndex >= 0 && hapticIndex < HapticFeedbackLevel.values.length
          ? HapticFeedbackLevel.values[hapticIndex]
          : _settings.hapticLevel,
      enableCritFumbleFx: critFx ?? _settings.enableCritFumbleFx,
      enableSpellParticles: particles ?? _settings.enableSpellParticles,
      enable3dDiceOverlays: dice ?? _settings.enable3dDiceOverlays,
      performanceMode: perf ?? _settings.performanceMode,
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
}

class SettingsScope extends InheritedNotifier<SettingsProvider> {
  const SettingsScope({
    super.key,
    required SettingsProvider notifier,
    required super.child,
  }) : super(notifier: notifier);

  static final SettingsProvider _defaultInstance = SettingsProvider();

  static SettingsProvider of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    return scope?.notifier ?? _defaultInstance;
  }

  static SettingsProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
  }
}
