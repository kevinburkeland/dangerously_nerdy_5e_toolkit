import 'package:material_ui/material_ui.dart';

import '../../models/monster_codex_data.dart';
import 'visual_ui.dart';

extension MonsterSortModeVisualUiExtension on MonsterSortMode {
  IconData get icon => iconKey.iconData;
}

