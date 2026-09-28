import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/candidate_detector.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/engine/source_block_parser.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';

void main() {
  group('Candidate Cross-Type Ambiguity & Disambiguation Tests', () {
    const parser = SourceBlockParser();
    const detector = CandidateDetector();
    const capability = Dnd5eIngestionCapability();
    final service = IngestionWorkbenchService(capability: capability);

    test('species vs monster disambiguation: creature with AC, HP, and CR is identified as monster, never species', () {
      const source = '''
### Goblin
Small humanoid (goblinoid), neutral evil
Armor Class 15 (leather armor, shield)
Hit Points 7 (2d6)
Speed 30 ft.
Challenge 1/4 (50 XP)

Nimble Escape. The goblin can take the Disengage or Hide action as a bonus action on each of its turns.
Actions
Scimitar. +4 to hit, reach 5 ft. Hit: 5 (1d6 + 2) slashing damage.
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      // Invariant: Monster indicators (AC, HP, CR, Actions) strictly reject classification as playable race!
      expect(ident.identifiedTypeKey, equals('monster'));
      expect(ident.plausibleTypeKeys, isNot(contains('species')));
    });

    test('class vs subclass disambiguation: entity with Hit Die and Saving Throws is class, not subclass', () {
      const source = '''
### Fighter
Hit Dice: 1d10 per fighter level
Primary Ability: Strength or Dexterity
Saving Throws: Strength, Constitution
Armor Proficiencies: All armor, shields
Weapon Proficiencies: Simple weapons, martial weapons

### Class Features
As a fighter, you gain the following class features.
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      expect(ident.identifiedTypeKey, equals('class'));
      expect(ident.plausibleTypeKeys, isNot(contains('subclass')));
    });

    test('cross-type ambiguity: conflicting feat and subclass feature signals remain ambiguous', () {
      const source = '''
### Shadow Stalker
Origin Feat
Prerequisite: Dexterity 13
Subclass for Rogue
3rd-Level Feature: You gain advantage when attacking from darkness.
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      // Invariant: conflicting strong signals must remain ambiguous!
      expect(ident.isAmbiguous, isTrue);
      expect(ident.plausibleTypeKeys, containsAll(['feat', 'subclass']));
      expect(ident.identifiedTypeKey, isNull);
    });

    test('cross-type ambiguity: conflicting item and feat signals remain ambiguous', () {
      const source = '''
### Ring of the Combatant
Wondrous Item, rare (requires attunement)
General Feat
Prerequisite: Proficiency with martial weapons
You gain a +1 bonus to attack rolls and saving throws while wearing this ring.
- Increase your Strength by 1.
- You gain advantage on initiative rolls.
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      expect(ident.isAmbiguous, isTrue);
      expect(ident.plausibleTypeKeys, containsAll(['item', 'feat']));
      expect(ident.identifiedTypeKey, isNull);
    });

    test('unrelated prose is not falsely identified as a background', () {
      const source = '''
### The Old Tavern
The tavern was bustling with travelers from all corners of the kingdom.
Some practiced their Athletics in friendly arm-wrestling contests, while others
shared stories of ancient history and perilous sea voyages over cold ale.
''';
      final doc = parser.parse(source);
      final ident = detector.identifyCluster(doc.blocks);

      // Invariant: Mere narrative mention of athletics does not falsely classify as background!
      expect(ident.isUnknown, isTrue);
      expect(ident.identifiedTypeKey, isNull);

      final result = service.parse(source);
      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;
      expect(candidate.identification.isUnknown, isTrue);
      expect(candidate.targetTypeKey, isNull);
    });

    test('user can explicitly resolve an ambiguous candidate and commit it', () {
      const source = '''
### Mystical Gift
Wondrous Item, rare (requires attunement)
General Feat
Prerequisite: Level 4
A supernatural charm that empowers the bearer.
''';
      final result = service.parse(source);
      final candidate = result.candidates.first;
      expect(candidate.identification.isAmbiguous, isTrue);
      expect(candidate.isTypeResolved, isFalse);

      // User selects 'item'
      final resolvedItem = service.changeCandidateType(candidate, 'item');
      expect(resolvedItem.targetTypeKey, equals('item'));
      expect(resolvedItem.isTypeResolved, isTrue);
      expect(resolvedItem.fields['rarity']?.value, equals('Rare'));

      // Or user selects 'feat'
      final resolvedFeat = service.changeCandidateType(candidate, 'feat');
      expect(resolvedFeat.targetTypeKey, equals('feat'));
      expect(resolvedFeat.isTypeResolved, isTrue);
      expect(resolvedFeat.fields['prerequisite']?.value, equals('Level 4'));
    });
  });
}
