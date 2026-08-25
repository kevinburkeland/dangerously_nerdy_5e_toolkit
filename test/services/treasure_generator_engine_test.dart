import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/models/tables/rollable_table.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/rules/treasure_generator_engine.dart';

void main() {
  group('TreasureGeneratorEngine Tests', () {
    final engine = TreasureGeneratorEngine();

    test('generateIndividualTreasure produces valid drops for all tiers', () {
      for (final tier in TreasureTier.values) {
        final drop = engine.generateIndividualTreasure(tier);
        expect(drop.tierLabel, tier.label);
        expect(drop.isHoard, isFalse);
        expect(drop.d100Roll, inInclusiveRange(1, 100));
        expect(drop.grandTotalGoldValue, greaterThan(0));
      }
    });

    test('generateTreasureHoard generates coins, gems/art, and magic items', () {
      for (final tier in TreasureTier.values) {
        final hoard = engine.generateTreasureHoard(tier);
        expect(hoard.tierLabel, tier.label);
        expect(hoard.isHoard, isTrue);
        expect(hoard.coinsGoldValue, greaterThan(0));
        expect(hoard.grandTotalGoldValue, greaterThan(0));
      }
    });

    test('calculateShares evenly divides coins and computes correct remainders', () {
      const drop = TreasureDropResult(
        tierLabel: 'CR 5–10',
        isHoard: true,
        cp: 200,
        sp: 1000,
        ep: 0,
        gp: 600,
        pp: 30,
        d100Roll: 50,
        rollSummary: 'Test Hoard',
      );

      final shares = drop.calculateShares(4);
      expect(shares.partySize, 4);
      expect(shares.cpPerPlayer, 50); // 200 / 4
      expect(shares.spPerPlayer, 250); // 1000 / 4
      expect(shares.gpPerPlayer, 150); // 600 / 4
      expect(shares.ppPerPlayer, 7); // 30 / 4 = 7
      expect(shares.remainderCoins['pp'], 2); // 30 % 4 = 2
    });

    test('calculateShares with includeLiquidatedGemsAndArt computes accurate gold appraisal', () {
      final drop = TreasureDropResult(
        tierLabel: 'CR 5–10',
        isHoard: true,
        gp: 1000,
        gemstones: const [
          GemArtItem(name: 'Diamond', gpValue: 5000, category: '5000 gp Gem', count: 1),
        ],
        artObjects: const [
          GemArtItem(name: 'Gold Chalice', gpValue: 250, category: '250 gp Art', count: 2),
        ],
        d100Roll: 50,
        rollSummary: 'Test Hoard with Gems & Art',
      );

      // Coins: 1,000 GP, Gems: 5,000 GP, Art: 500 GP -> Total 6,500 GP
      expect(drop.grandTotalGoldValue, 6500.0);

      final shares = drop.calculateShares(4, includeLiquidatedGemsAndArt: true);
      expect(shares.gpPerPlayer, 1625); // 6500 / 4
      expect(shares.totalGpEquivalentPerPlayer, 1625.0);
    });

    test('formatMarkdownSummary outputs readable markdown with party distribution', () {
      final drop = engine.generateTreasureHoard(TreasureTier.cr5To10);
      final md = engine.formatMarkdownSummary(drop, partySize: 4);

      expect(md.contains('5e Treasure Drop: Hoard'), isTrue);
      expect(md.contains('Total Estimated Hoard Value:'), isTrue);
      expect(md.contains('Party Distribution (4 Players):'), isTrue);
    });
  });
}
