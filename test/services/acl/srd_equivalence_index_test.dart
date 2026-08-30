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

    test('correctly identifies canonical SRD species and feats', () {
      expect(
        index.checkEntity(slug: 'human', name: 'Human', type: EntityType.species),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'alert', name: 'Alert', type: EntityType.feat),
        equals(SrdMatchResult.exactSrdMatch),
      );
      expect(
        index.checkEntity(slug: 'homebrew-feat', name: 'Homebrew Mastery', type: EntityType.feat),
        equals(SrdMatchResult.notSrd),
      );
    });

    test('detects SRD name variants with non-canonical slugs', () {
      expect(
        index.checkEntity(slug: 'custom-fighter', name: 'Fighter', type: EntityType.classDefinition),
        equals(SrdMatchResult.srdVariantAdditive),
      );
    });

    test('isCanonSrd returns true for exact canonical SRD slugs', () {
      expect(index.isCanonSrd('rogue', EntityType.classDefinition), isTrue);
      expect(index.isCanonSrd('custom-rogue', EntityType.classDefinition), isFalse);
    });
  });
}
