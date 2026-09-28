import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/candidate_detector.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';

void main() {
  group('CandidateDetector Tests', () {
    const parser = SourceBlockParser();
    const detector = CandidateDetector();

    test('correctly identifies representative monster text', () {
      const source = '''
### Young Blue Dragon
Large dragon, lawful evil
Armor Class 18 (natural armor)
Hit Points 152 (16d10 + 64)
Speed 40 ft., burrow 20 ft., fly 80 ft.
STR DEX CON INT WIS CHA
21 (+5) 10 (+0) 19 (+4) 14 (+2) 13 (+1) 15 (+2)
Challenge 9 (5,000 XP)
Actions
Multiattack. The dragon makes three attacks.
''';
      final doc = parser.parse(source);
      final clusters = detector.detectClusters(doc);

      expect(clusters.length, equals(1));
      expect(clusters[0].isCandidate, isTrue);
      final ident = clusters[0].identification;
      expect(ident.identifiedTypeKey, equals('monster'));
      expect(ident.confidence, greaterThanOrEqualTo(0.8));
      expect(ident.isUnknown, isFalse);
      expect(ident.isAmbiguous, isFalse);
      expect(ident.evidence, isNotEmpty);
      expect(ident.evidence.any((e) => e.category.contains('Armor Class')), isTrue);
      expect(ident.evidence.any((e) => e.category.contains('Hit Points')), isTrue);
      expect(ident.evidence.any((e) => e.category.contains('Ability Scores')), isTrue);
    });

    test('correctly identifies representative spell text', () {
      const source = '''
### Lightning Bolt
3rd-level evocation
Casting Time: 1 action
Range: Self (100-foot line)
Components: V, S, M (a bit of fur and a rod of amber, crystal, or glass)
Duration: Instantaneous
A stroke of lightning forming a line 100 feet long and 5 feet wide blasts out from you.
''';
      final doc = parser.parse(source);
      final clusters = detector.detectClusters(doc);

      expect(clusters.length, equals(1));
      expect(clusters[0].isCandidate, isTrue);
      final ident = clusters[0].identification;
      expect(ident.identifiedTypeKey, equals('spell'));
      expect(ident.confidence, greaterThanOrEqualTo(0.8));
      expect(ident.isUnknown, isFalse);
      expect(ident.isAmbiguous, isFalse);
      expect(ident.evidence.any((e) => e.category.contains('Casting Time')), isTrue);
      expect(ident.evidence.any((e) => e.category.contains('Duration')), isTrue);
    });

    test('unknown object remains unknown when text is merely a title followed by prose', () {
      const source = '''
### The Whispering Woods
The forest stretches across the northern border, shrouded in eternal mist.
Travelers speak of ghostly figures moving between the ancient weeping willows.
Many adventurers who ventured inside never returned to tell their tale.
''';
      final doc = parser.parse(source);
      final clusters = detector.detectClusters(doc);
      expect(clusters.length, equals(1));

      final ident = detector.identifyCluster(doc.blocks);
      expect(ident.isUnknown, isTrue);
      expect(ident.identifiedTypeKey, isNull);
      expect(ident.confidence, equals(0.0));
    });

    test('ambiguous object type remains ambiguous when signals conflict', () {
      const source = '''
### Eldritch Guardian
Medium humanoid, neutral
Armor Class 14
Hit Points 30
Casting Time: 1 action
Range: 60 feet
Duration: 1 minute
Components: V, S
Challenge 2
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      expect(ident.isAmbiguous, isTrue);
      expect(ident.plausibleTypeKeys, containsAll(['monster', 'spell']));
      expect(ident.identifiedTypeKey, isNull);
    });

    test('detects multiple objects in one source and isolates preamble prose', () {
      const source = '''
Here is the first creature for our campaign:

### Goblin Scout
Small humanoid (goblinoid), neutral evil
Armor Class 14 (leather armor)
Hit Points 10 (3d6)
Speed 30 ft.
Challenge 1/4 (50 XP)

And here is their signature cantrip:

### Goblin Hex
Enchantment cantrip
Casting Time: 1 bonus action
Range: 30 feet
Components: V, S
Duration: Instantaneous
The target feels an unsettling dread.
''';
      final doc = parser.parse(source);
      final clusters = detector.detectClusters(doc);

      // Preamble should be non-candidate, followed by monster candidate, prose, then spell candidate
      final candidates = clusters.where((c) => c.isCandidate).toList();
      final nonCandidates = clusters.where((c) => !c.isCandidate).toList();

      expect(candidates.length, equals(2));
      expect(candidates[0].identification.identifiedTypeKey, equals('monster'));
      expect(candidates[1].identification.identifiedTypeKey, equals('spell'));
      expect(nonCandidates, isNotEmpty);
    });
  });
}
