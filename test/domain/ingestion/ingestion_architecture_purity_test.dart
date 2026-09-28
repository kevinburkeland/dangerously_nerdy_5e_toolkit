import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/domain/ingestion/services/ingestion_workbench_service.dart';
import 'package:dangerously_nerdy_5e_toolkit/infrastructure/modules/dnd5e/ingestion/dnd5e_ingestion_capability.dart';

void main() {
  group('Ingestion Architecture Purity & Non-Coercion Invariants', () {
    test('Ensures lib/domain/ingestion/ never imports concrete 5e domain models', () {
      final domainDir = Directory('lib/domain/ingestion');
      expect(domainDir.existsSync(), isTrue);

      final dartFiles = domainDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final forbiddenImportPattern = RegExp(
        r'''import\s+['"].*(?:models/domain|dnd5e|spell_monster|character_models|dm_screen).*['"];''',
      );

      final violations = <String>[];
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final matches = forbiddenImportPattern.allMatches(content);
        for (final m in matches) {
          violations.add('${file.path}: ${m.group(0)}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'lib/domain/ingestion/ must remain 100% ruleset-agnostic.\nViolations:\n${violations.join("\n")}',
      );
    });

    test('Ensures lib/presentation/screens/homebrew/ never imports concrete 5e domain models', () {
      final presDir = Directory('lib/presentation/screens/homebrew');
      expect(presDir.existsSync(), isTrue);

      final dartFiles = presDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final forbiddenImportPattern = RegExp(
        r'''import\s+['"].*(?:spell_monster_equipment|character_models).*['"];''',
      );

      final violations = <String>[];
      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        final matches = forbiddenImportPattern.allMatches(content);
        for (final m in matches) {
          violations.add('${file.path}: ${m.group(0)}');
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Generic workbench presentation must not directly construct or import 5e entities.\nViolations:\n${violations.join("\n")}',
      );
    });

    test('unknown candidate remains unknown and targetTypeKey is null (never coerced to Monster)', () {
      const source = '''
### The Whispering Woods
The forest stretches across the northern border, shrouded in eternal mist.
Travelers speak of ghostly figures moving between the ancient weeping willows.
Many adventurers who ventured inside never returned to tell their tale.
''';
      final service = IngestionWorkbenchService(capability: const Dnd5eIngestionCapability());
      final result = service.parse(source);

      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;

      // Invariant: Unknown candidate MUST NOT be coerced to Monster!
      expect(candidate.identification.isUnknown, isTrue);
      expect(candidate.targetTypeKey, isNull);
      expect(candidate.isTypeResolved, isFalse);
      expect(candidate.displayName, equals('The Whispering Woods'));

      // Invariant: Unresolved candidate cannot be committed
      final validation = service.validate(candidate);
      expect(validation.isValid, isFalse);
      expect(validation.blockingErrors.any((e) => e.contains('unresolved')), isTrue);

      final conversion = service.convertToDomainEntity(candidate);
      expect(conversion.isSuccess, isFalse);
    });

    test('ambiguous candidate remains ambiguous and targetTypeKey is null (never auto-coerced to first)', () {
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
      final service = IngestionWorkbenchService(capability: const Dnd5eIngestionCapability());
      final result = service.parse(source);

      expect(result.candidates.length, equals(1));
      final candidate = result.candidates.first;

      // Invariant: Ambiguous candidate MUST NOT auto-choose the first type!
      expect(candidate.identification.isAmbiguous, isTrue);
      expect(candidate.identification.plausibleTypeKeys, containsAll(['monster', 'spell']));
      expect(candidate.targetTypeKey, isNull);
      expect(candidate.isTypeResolved, isFalse);

      // Invariant: Cannot be committed while ambiguous
      final validation = service.validate(candidate);
      expect(validation.isValid, isFalse);
      expect(validation.blockingErrors.any((e) => e.contains('unresolved')), isTrue);

      // User explicitly resolves ambiguity
      final resolved = service.changeCandidateType(candidate, 'monster');
      expect(resolved.targetTypeKey, equals('monster'));
      expect(resolved.isTypeResolved, isTrue);
      expect(resolved.fields['armorClass']?.value, equals(14));
      expect(resolved.fields['hitPoints']?.value, equals(30));
    });
  });
}
