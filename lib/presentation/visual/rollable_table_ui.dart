import 'package:flutter/material.dart';

import '../../models/tables/rollable_table.dart';
import 'visual_ui.dart';

extension TableCategoryVisualUiExtension on TableCategory {
  IconData get icon => iconKey.iconData;
  Color get accentColor => accentArgb.toColor();
}

