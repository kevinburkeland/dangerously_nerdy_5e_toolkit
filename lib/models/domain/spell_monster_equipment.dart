/// Re-exported canonical D&D 5e implementation from package:vtt_ruleset_dnd5e.
library;
export 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';

import '../../services/ingestion/stat_block_acl_parser.dart';
import '../dm_screen_data.dart';
import '../spellbook_data.dart';

final bool spellAclInitialized = () {
  Spell.riderExtractor = StatBlockAclParser.extractRiders;
  return true;
}();

extension SpellGlyphX on Spell {
  /// Dynamic action rings for DndGlyph HUD rendering conforming to the Glyph Style Guide.
  List<ActionTraitRing> getGlyphActionRings(
      [DmRulesEdition edition = DmRulesEdition.v2024]) {
    final libSpell = SpellbookLibrary.getSpellById(id.slug) ??
        SpellbookLibrary.getSpellById(
            name.toLowerCase().replaceAll(' ', '-').replaceAll('/', '-'));
    if (libSpell != null) {
      return libSpell.getGlyphActionRings(edition);
    }
    final rings = <ActionTraitRing>[];
    if (duration.requiresConcentration) {
      rings.add(const ActionTraitRing(
          ringType: ActionRingType.concentration, label: 'Concentration'));
    }
    if (castingTime.actionType == ActionType.bonusAction) {
      rings.add(const ActionTraitRing(
          ringType: ActionRingType.bonusAction, label: 'Bonus Action'));
    } else if (castingTime.actionType == ActionType.reaction) {
      rings.add(const ActionTraitRing(
          ringType: ActionRingType.reaction, label: 'Reaction'));
    }
    return rings;
  }
}
