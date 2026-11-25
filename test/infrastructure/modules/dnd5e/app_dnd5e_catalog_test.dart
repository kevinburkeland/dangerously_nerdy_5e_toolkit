import 'package:flutter_test/flutter_test.dart';
import 'package:vtt_ruleset_dnd5e/vtt_ruleset_dnd5e.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/dnd5e_ruleset_catalog.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/characters/srd_feats_library.dart';

void main() {
  group('Fix 5.1: AppDnd5eCatalog typed views and fail-loud extractors', () {
    const catalog = AppDnd5eCatalog();

    test('findFeat returns CatalogFeat with grants and null for unknown slug',
        () {
      final firstSlug = SrdFeatsLibrary.allFeats.first.id.slug;
      final feat = catalog.findFeat(firstSlug);
      expect(feat, isA<CatalogFeat>());
      expect(catalog.findFeat('no-such-feat-slug'), isNull);
    });

    test(
        'findMagicItem returns CatalogMagicItem with categoryName, tags, and summaries',
        () {
      final item = catalog.findMagicItem('Ring of Protection');
      expect(item, isA<CatalogMagicItem>());
      expect(item!.categoryName, isNotEmpty);
      expect(item.summary2024, isNotEmpty);
      expect(item.summary2014, isNotEmpty);
      expect(catalog.findMagicItem('no-such-magic-item-xyz'), isNull);
    });

    test('extract methods fail loudly naming runtimeType on unsupported shapes',
        () {
      expect(
        () => catalog.extractSpellDescriptors(42),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          contains('int'),
        )),
      );
      expect(
        () => catalog.extractSpellNames(true),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          contains('bool'),
        )),
      );
      expect(
        () => catalog.extractBonusSpells(3.14, 'class', 'wizard'),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message.toString(),
          'message',
          contains('double'),
        )),
      );
    });

    test('extract methods accept null, String, List, and Map shapes', () {
      expect(catalog.extractSpellDescriptors(null), isEmpty);
      expect(catalog.extractSpellNames('fireball'), contains('fireball'));
      expect(catalog.extractSpellNames(['fireball']), contains('fireball'));
      expect(
        catalog.extractBonusSpells({'spells': ['fireball']}, 'class', 'wizard'),
        isNotEmpty,
      );
    });
  });
}
