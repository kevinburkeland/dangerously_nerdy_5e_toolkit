import 'package:flutter/material.dart';

import '../../models/spellbook_data.dart';
import 'visual_ui.dart';

extension SpellClassUiExtension on SpellClass {
  IconData get icon => iconKey.iconData;
}

