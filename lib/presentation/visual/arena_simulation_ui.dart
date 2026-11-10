import 'package:flutter/material.dart';

import '../../models/arena/arena_simulation_models.dart';
import 'visual_ui.dart';

extension ArenaEnvironmentVisualUiExtension on ArenaEnvironment {
  IconData get icon => iconKey.iconData;
  Color get themeColor => themeArgb.toColor();
}

