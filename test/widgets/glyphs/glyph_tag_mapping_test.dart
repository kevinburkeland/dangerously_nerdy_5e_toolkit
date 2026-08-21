import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/monster_codex_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/spellbook_data.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/srd_summons/minion_stat_block.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/magic_items/magic_item_library.dart';
import 'package:dangerously_nerdy_5e_toolkit/widgets/glyphs/dnd_glyph.dart';

void main() {
  group('Glyph & Tag Mapping Tests', () {
    test('All 8 spell schools map to distinct frame shapes and valid colors', () {
      for (final school in SpellSchool.values) {
        expect(school.displayName.isNotEmpty, isTrue);
        expect(school.frameShape, isNotNull);
        expect(school.getLegibleColor(true), isNotNull);
        expect(school.getLegibleColor(false), isNotNull);

        final glyph = DndGlyph.spell(
          school: school,
          level: 3,
        );
        expect(glyph.school, school);
        expect(glyph.tierLevel, 3);
      }
    });

    test('All 14 creature types map to distinct frame shapes and valid colors', () {
      for (final type in CreatureType.values) {
        expect(type.displayName.isNotEmpty, isTrue);
        expect(type.frameShape, isNotNull);
        expect(type.getLegibleColor(true), isNotNull);
        expect(type.getLegibleColor(false), isNotNull);

        final glyph = DndGlyph.monster(
          creatureType: type,
          crTier: 2,
        );
        expect(glyph.creatureType, type);
        expect(glyph.tierLevel, 2);
      }
    });

    test('Spell tag semantics map correctly to ActionTraitRings', () {
      // Fireball -> Recharge / AoE ring with Fire accent
      final fireball = SpellbookLibrary.allSpells.firstWhere((s) => s.name == 'Fireball');
      final fireballRings = fireball.getGlyphActionRings(DmRulesEdition.v2014);
      expect(fireballRings.any((r) => r.ringType == ActionRingType.recharge), isTrue);
      expect(fireball.getGlyphPrimaryDamageAccent(DmRulesEdition.v2014), DamageAccent.fire);

      // Hold Person -> Concentration & Control rings
      final holdPerson = SpellbookLibrary.allSpells.firstWhere((s) => s.name == 'Hold Person');
      final holdRings = holdPerson.getGlyphActionRings(DmRulesEdition.v2014);
      expect(holdRings.any((r) => r.ringType == ActionRingType.concentration), isTrue);
      expect(holdRings.any((r) => r.ringType == ActionRingType.control), isTrue);

      // Healing Word -> Sustain ring
      final healingWord = SpellbookLibrary.allSpells.firstWhere((s) => s.name == 'Healing Word');
      final healRings = healingWord.getGlyphActionRings(DmRulesEdition.v2014);
      expect(healRings.any((r) => r.ringType == ActionRingType.sustain), isTrue);

      // Shield -> Reaction ring
      final shield = SpellbookLibrary.allSpells.firstWhere((s) => s.name == 'Shield');
      final shieldRings = shield.getGlyphActionRings(DmRulesEdition.v2014);
      expect(shieldRings.any((r) => r.ringType == ActionRingType.reaction), isTrue);
    });

    test('Magic Item tag semantics map correctly to ActionTraitRings and DamageAccents', () {
      // Flame Tongue -> Melee ring with Fire damage accent
      final flameTongue = MagicItemLibrary.findByName('Flame Tongue')!;
      final flameRings = flameTongue.getGlyphActionRings(DmRulesEdition.v2024);
      expect(flameRings.any((r) => r.ringType == ActionRingType.attunement), isTrue);
      expect(flameRings.any((r) => r.ringType == ActionRingType.melee), isTrue);
      expect(flameTongue.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024), DamageAccent.fire);

      // Staff of Healing -> Attunement + Sustain + Recharge rings
      final staffOfHealing = MagicItemLibrary.findByName('Staff of Healing')!;
      final staffRings = staffOfHealing.getGlyphActionRings(DmRulesEdition.v2024);
      expect(staffRings.any((r) => r.ringType == ActionRingType.attunement), isTrue);
      expect(staffRings.any((r) => r.ringType == ActionRingType.sustain), isTrue);
      expect(staffRings.any((r) => r.ringType == ActionRingType.recharge), isTrue);

      // Wand of Magic Missiles -> Recharge / Force damage accent
      final wandMm = MagicItemLibrary.findByName('Wand of Magic Missiles')!;
      final wandRings = wandMm.getGlyphActionRings(DmRulesEdition.v2024);
      expect(wandRings.any((r) => r.ringType == ActionRingType.recharge), isTrue);
      expect(wandMm.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024), DamageAccent.force);

      // Ring of Protection -> Attunement + Reaction/Defense ring
      final ringProt = MagicItemLibrary.findByName('Ring of Protection')!;
      final ringProtRings = ringProt.getGlyphActionRings(DmRulesEdition.v2024);
      expect(ringProtRings.any((r) => r.ringType == ActionRingType.attunement), isTrue);
      expect(ringProtRings.any((r) => r.ringType == ActionRingType.reaction), isTrue);

      // Longsword -> Melee ring with Slashing damage
      final longsword = MagicItemLibrary.findByName('Longsword')!;
      final longswordRings = longsword.getGlyphActionRings(DmRulesEdition.v2024);
      expect(longswordRings.any((r) => r.ringType == ActionRingType.melee), isTrue);
      expect(longsword.getGlyphPrimaryDamageAccent(DmRulesEdition.v2024), DamageAccent.slashing);
    });

    test('Monster type display strings map accurately to CreatureType and CR Tiers', () {
      final goblin = MonsterCodexLibrary.getMonsterByName('Goblin')!;
      final goblinStat = goblin.getStatBlock(DmRulesEdition.v2014);
      expect(goblinStat.glyphCreatureType, CreatureType.humanoid);
      expect(goblinStat.glyphCrTier, 1); // CR 1/4 -> Tier 1

      final gelCube = MonsterCodexLibrary.getMonsterByName('Gelatinous Cube')!;
      final gelStat = gelCube.getStatBlock(DmRulesEdition.v2014);
      expect(gelStat.glyphCreatureType, CreatureType.ooze);
      expect(gelStat.glyphCrTier, 1); // CR 2 -> Tier 1

      final bulette = MonsterCodexLibrary.getMonsterByName('Bulette')!;
      final buletteStat = bulette.getStatBlock(DmRulesEdition.v2014);
      expect(buletteStat.glyphCreatureType, CreatureType.monstrosity);
      expect(buletteStat.glyphCrTier, 2); // CR 5 -> Tier 2

      final aboleth = MonsterCodexLibrary.getMonsterByName('Aboleth')!;
      final abolethStat = aboleth.getStatBlock(DmRulesEdition.v2014);
      expect(abolethStat.glyphCreatureType, CreatureType.aberration);
      expect(abolethStat.glyphCrTier, 2); // CR 10 -> Tier 2

      final vampire = MonsterCodexLibrary.getMonsterByName('Vampire')!;
      final vampStat = vampire.getStatBlock(DmRulesEdition.v2014);
      expect(vampStat.glyphCreatureType, CreatureType.undead);
      expect(vampStat.glyphCrTier, 3); // CR 13 -> Tier 3
      expect(vampStat.glyphActionRings.any((r) => r.ringType == ActionRingType.legendary), isTrue);
      expect(vampStat.glyphActionRings.any((r) => r.ringType == ActionRingType.sustain), isTrue);

      final dragon = MonsterCodexLibrary.getMonsterByName('Ancient Red Dragon')!;
      final dragonStat = dragon.getStatBlock(DmRulesEdition.v2014);
      expect(dragonStat.glyphCreatureType, CreatureType.dragon);
      expect(dragonStat.glyphCrTier, 4); // CR 24 -> Tier 4
      expect(dragonStat.glyphActionRings.any((r) => r.ringType == ActionRingType.legendary), isTrue);
      expect(dragonStat.glyphActionRings.any((r) => r.ringType == ActionRingType.recharge), isTrue);

      final tarrasque = MonsterCodexLibrary.getMonsterByName('Tarrasque')!;
      final tarStat = tarrasque.getStatBlock(DmRulesEdition.v2014);
      expect(tarStat.glyphCreatureType, CreatureType.monstrosity);
      expect(tarStat.glyphCrTier, 4); // CR 30 -> Tier 4
      expect(tarStat.glyphActionRings.any((r) => r.ringType == ActionRingType.legendary), isTrue);
    });

    test('Elemental damage accents match RAW 5e energy types', () {
      for (final accent in DamageAccent.values) {
        expect(accent.displayName.isNotEmpty, isTrue);
        expect(accent.color, isNotNull);
      }

      expect(DamageAccent.fire.color, const Color(0xFFEF4444));
      expect(DamageAccent.cold.color, const Color(0xFF06B6D4));
      expect(DamageAccent.lightning.color, const Color(0xFFEAB308));
      expect(DamageAccent.acid.color, const Color(0xFF84CC16));
      expect(DamageAccent.poison.color, const Color(0xFF10B981));
      expect(DamageAccent.necrotic.color, const Color(0xFF8B5CF6));
      expect(DamageAccent.radiant.color, const Color(0xFFF59E0B));
      expect(DamageAccent.psychic.color, const Color(0xFFEC4899));
      expect(DamageAccent.force.color, const Color(0xFF3B82F6));
      expect(DamageAccent.thunder.color, const Color(0xFF6366F1));
    });
  });
}
