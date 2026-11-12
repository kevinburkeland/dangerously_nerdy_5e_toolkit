import 'package:material_ui/material_ui.dart';

import '../../models/srd_summons/minion_stat_block.dart';
import 'visual_ui.dart';

extension MinionStatBlockVisualUiExtension on MinionStatBlock {
  Color get accentColor => accentArgb.toColor();
}

