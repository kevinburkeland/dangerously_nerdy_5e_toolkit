import 'package:material_ui/material_ui.dart';

import '../../models/characters/srd_equipment_library.dart';
import 'visual_ui.dart';

extension SrdEquipmentPackageVisualUiExtension on SrdEquipmentPackage {
  IconData get icon => iconKey.iconData;
}

