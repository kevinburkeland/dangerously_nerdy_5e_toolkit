import '../spellbook_data.dart';
import 'level_6_spells.dart';
import 'level_7_spells.dart';
import 'level_8_spells.dart';
import 'level_9_spells.dart';

export 'level_6_spells.dart';
export 'level_7_spells.dart';
export 'level_8_spells.dart';
export 'level_9_spells.dart';

/// Aggregated high-level spells list (Levels 6–9) for backwards-compatibility.
const List<SpellItem> srdHighLevelSpells = [
  ...srdLevel6Spells,
  ...srdLevel7Spells,
  ...srdLevel8Spells,
  ...srdLevel9Spells,
];
