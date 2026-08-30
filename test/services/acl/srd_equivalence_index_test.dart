import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/domain/core_types.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/acl/srd_equivalence_index.dart';

void main() {
  group('SrdEquivalenceIndex Deduplication Tests', () {
    late SrdEquivalenceIndex index;

    setUp(() {
      index = SrdEquivalenceIndex();
      index.build();
    });

    test('correctly identifies canonical SRD spells', () {
      expect(
        index.checkEntity(slug: 'fireball', name: 'Fireball', type: EntityType.spell),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'magic-missile-phb', name: 'Magic Missile', type: EntityType.spell),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'void-blast', name: 'Void Blast', type: EntityType.spell),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('correctly identifies canonical SRD monsters', () {
      expect(
        index.checkEntity(slug: 'goblin', name: 'Goblin', type: EntityType.monster),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'ancient-red-dragon-mm', name: 'Ancient Red Dragon', type: EntityType.monster),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'void-crawler', name: 'Void Crawler', type: EntityType.monster),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('correctly identifies canonical SRD equipment and magic items', () {
      expect(
        index.checkEntity(slug: 'potion-of-healing', name: 'Potion of Healing', type: EntityType.equipment),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'longsword-dmg', name: 'Longsword', type: EntityType.equipment),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'ring-of-the-void', name: 'Ring of the Void', type: EntityType.equipment),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('correctly identifies canonical SRD classes', () {
      expect(
        index.checkEntity(slug: 'fighter', name: 'Fighter', type: EntityType.classDefinition),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'wizard', name: 'Wizard', type: EntityType.classDefinition),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'blood-hunter', name: 'Blood Hunter', type: EntityType.classDefinition),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('correctly identifies canonical SRD species, feats, and backgrounds', () {
      expect(
        index.checkEntity(slug: 'human', name: 'Human', type: EntityType.species),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'high-elf', name: 'High Elf', type: EntityType.species),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'alert', name: 'Alert', type: EntityType.feat),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'acolyte', name: 'Acolyte', type: EntityType.background),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'homebrew-feat', name: 'Homebrew Mastery', type: EntityType.feat),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('isCanonSrd returns true for exact canonical SRD slugs and stripped slugs', () {
      expect(index.isCanonSrd('rogue', EntityType.classDefinition), isTrue);
      expect(index.isCanonSrd('rogue-phb', EntityType.classDefinition), isTrue);
      expect(index.isCanonSrd('custom-rogue', EntityType.classDefinition), isFalse);
      expect(index.isCanonSrd('custom-rogue', EntityType.classDefinition, name: 'Rogue'), isTrue);
    });
  });
}
