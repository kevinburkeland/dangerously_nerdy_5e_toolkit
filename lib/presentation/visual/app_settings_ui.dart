import 'package:material_ui/material_ui.dart' as flutter;
import 'package:material_ui/material_ui.dart' show Color;

import '../../models/app_settings.dart';
import 'visual_ui.dart';

extension FantasyAccentVisualUiExtension on FantasyAccent {
  Color get primary => primaryArgb.toColor();
  Color get accent => accentArgb.toColor();
  Color get lightPrimary => lightPrimaryArgb.toColor();
  Color get lightAccent => lightAccentArgb.toColor();
  Color getPrimary(bool isDarkMode) => getPrimaryArgb(isDarkMode).toColor();
  Color getAccent(bool isDarkMode) => getAccentArgb(isDarkMode).toColor();
}

extension ThemeModeVisualUiExtension on ThemeMode {
  flutter.ThemeMode toFlutter() => switch (this) {
        ThemeMode.system => flutter.ThemeMode.system,
        ThemeMode.light => flutter.ThemeMode.light,
        ThemeMode.dark => flutter.ThemeMode.dark,
      };
}

