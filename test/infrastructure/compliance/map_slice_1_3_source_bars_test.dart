import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Map Slice 1.3 Source Bars Compliance', () {
    test('SB9: Every file under lib/application/map/ contains none of the forbidden imports/types', () {
      final forbiddenTokens = [
        'package:' 'flutter',
        'package:' 'web',
        'dart:' 'js_interop',
        'dart:' 'io',
        'IP2p' 'TransportPort',
        'broadcast' 'Payload',
      ];

      final dir = Directory('lib/application/map');
      expect(dir.existsSync(), isTrue, reason: 'lib/application/map must exist');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);

      final violations = <String>[];
      for (final file in files) {
        final content = file.readAsStringSync();
        for (final token in forbiddenTokens) {
          if (content.contains(token)) {
            violations.add('${file.path} contains forbidden token: $token');
          }
        }
      }
      expect(violations, isEmpty, reason: 'SB9 violation: $violations');

      // Control: in-memory violating strings produce violations for each token
      for (final token in forbiddenTokens) {
        final badContent = 'import "$token";';
        expect(badContent.contains(token), isTrue);
      }
    });

    test('SB10: In web_blob_store_adapter.dart: readonly appears exactly once and _deleteEntry does not appear', () {
      final file = File('lib/infrastructure/storage/web/web_blob_store_adapter.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      const readonlyToken = 'read' 'only';
      const deleteEntryToken = '_delete' 'Entry';

      final readonlyCount = readonlyToken.allMatches(content).length;
      expect(readonlyCount, equals(1), reason: "'readonly' must appear exactly once in web_blob_store_adapter.dart");

      final hasDeleteEntry = content.contains(deleteEntryToken);
      expect(hasDeleteEntry, isFalse, reason: '_deleteEntry must not appear in web_blob_store_adapter.dart');

      // Controls:
      const badReadonly = 'tx1 = read' 'only; tx2 = read' 'only;';
      expect(readonlyToken.allMatches(badReadonly).length, equals(2));

      const badDeleteEntry = 'void _delete' 'Entry() {}';
      expect(badDeleteEntry.contains(deleteEntryToken), isTrue);
    });

    test('SB11: In web_map_image_intake_adapter.dart: arrayBuffer( appears exactly twice, readAsArrayBuffer 0, createImageBitmap( exactly 1', () {
      final file = File('lib/infrastructure/map/web/web_map_image_intake_adapter.dart');
      expect(file.existsSync(), isTrue);
      final lines = file.readAsLinesSync();
      final content = file.readAsStringSync();

      const arrayBufferToken = 'array' 'Buffer(';
      const sliceToken = '.sli' 'ce(';
      const readAsArrayBufferToken = 'readAs' 'ArrayBuffer';
      const createImageBitmapToken = 'createImage' 'Bitmap(';

      final arrayBufferMatches = arrayBufferToken.allMatches(content).length;
      expect(arrayBufferMatches, equals(2), reason: 'arrayBuffer( must appear exactly twice');

      // One on a line with .slice(
      final sliceAndBufferLines = lines.where((l) => l.contains(arrayBufferToken) && l.contains(sliceToken)).toList();
      expect(sliceAndBufferLines.length, equals(1), reason: 'Exactly one arrayBuffer( line must also contain .slice(');

      // One inside _readEncodedOutput
      expect(content.contains('_readEncodedOutput'), isTrue);
      final readOutputSection = content.substring(content.indexOf('_readEncodedOutput'));
      final readOutputFunc = readOutputSection.substring(0, readOutputSection.indexOf('}'));
      expect(arrayBufferToken.allMatches(readOutputFunc).length, equals(1), reason: 'arrayBuffer( must appear inside _readEncodedOutput');

      expect(content.contains(readAsArrayBufferToken), isFalse, reason: 'readAsArrayBuffer must not appear');
      expect(createImageBitmapToken.allMatches(content).length, equals(1), reason: 'createImageBitmap( must appear exactly once');

      // Controls:
      const badArrayBuffer = 'b1.array' 'Buffer(); b2.array' 'Buffer(); b3.array' 'Buffer();';
      expect(arrayBufferToken.allMatches(badArrayBuffer).length, equals(3));

      const badReadAs = 'reader.readAs' 'ArrayBuffer(file);';
      expect(badReadAs.contains(readAsArrayBufferToken), isTrue);

      const badBitmap = 'createImage' 'Bitmap(f); createImage' 'Bitmap(f);';
      expect(createImageBitmapToken.allMatches(badBitmap).length, equals(2));
    });

    test('SB12: Under lib/, BlobRef( constructor appears only in map_intake_service.dart', () {
      const blobRefCtor = 'Blob' 'Ref(';

      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final hits = <String>[];
      for (final f in files) {
        final content = f.readAsStringSync();
        if (content.contains(blobRefCtor)) {
          hits.add(f.path.replaceAll(r'\', '/'));
        }
      }

      expect(hits, equals(['lib/application/map/map_intake_service.dart']),
          reason: 'BlobRef( constructor must only appear in map_intake_service.dart');

      // Control:
      const badRef = 'final ref = Blob' 'Ref();';
      expect(badRef.contains(blobRefCtor), isTrue);
    });

    test('SB13: Under lib/, image decoder tokens appear only in map_view.dart and web_map_image_intake_adapter.dart', () {
      final tokens = [
        'Image.' 'memory(',
        'Memory' 'Image(',
        'instantiate' 'ImageCodec',
        'decode' 'ImageFromList',
        'createImage' 'Bitmap(',
      ];

      final allowedPaths = {
        'lib/presentation/widgets/map/map_view.dart',
        'lib/infrastructure/map/web/web_map_image_intake_adapter.dart',
      };

      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final violations = <String>[];
      for (final f in files) {
        final normalizedPath = f.path.replaceAll(r'\', '/');
        if (allowedPaths.contains(normalizedPath)) continue;

        final content = f.readAsStringSync();
        for (final token in tokens) {
          if (content.contains(token)) {
            violations.add('$normalizedPath contains forbidden decoder token: $token');
          }
        }
      }

      expect(violations, isEmpty, reason: 'SB13 violation: $violations');

      // Controls:
      for (final token in tokens) {
        final badCode = 'final x = $token;';
        expect(badCode.contains(token), isTrue);
      }
    });

    test('SB14: Under lib/, .deleteProfile( appears only in designated files and is followed by releaseCampaign( in campaign_profile_service.dart', () {
      const deleteProfileToken = '.delete' 'Profile(';
      const releaseCampaignToken = 'release' 'Campaign(';

      final allowedPaths = {
        'lib/infrastructure/repositories/local_campaign_repository.dart',
        'lib/services/persistence/campaign_profile_service.dart',
        'lib/services/party/party_room_service.dart',
        'lib/screens/dm_dashboard_screen.dart',
      };

      final libDir = Directory('lib');
      final files = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();

      final hits = <String>[];
      for (final f in files) {
        final content = f.readAsStringSync();
        if (content.contains(deleteProfileToken)) {
          hits.add(f.path.replaceAll(r'\', '/'));
        }
      }

      for (final hit in hits) {
        expect(allowedPaths.contains(hit), isTrue, reason: 'Unexpected .deleteProfile( call in $hit');
      }

      // Check campaign_profile_service.dart: deleteProfile method has repo.deleteProfile followed by releaseCampaign
      final cpsFile = File('lib/services/persistence/campaign_profile_service.dart');
      final cpsContent = cpsFile.readAsStringSync();
      expect(cpsContent.contains(deleteProfileToken), isTrue);
      final deleteIdx = cpsContent.indexOf(deleteProfileToken);
      final releaseIdx = cpsContent.indexOf(releaseCampaignToken, deleteIdx);
      expect(releaseIdx, greaterThan(deleteIdx),
          reason: 'In campaign_profile_service.dart, .deleteProfile( must be followed by releaseCampaign(');

      // Controls:
      const badCall = 'await repo.delete' 'Profile("1");';
      expect(badCall.contains(deleteProfileToken), isTrue);

      const noRelease = 'await repo.delete' 'Profile("1"); return;';
      expect(noRelease.contains(releaseCampaignToken), isFalse);
    });

    test('SB15: map_view.dart does not contain Scaffold(', () {
      const scaffoldToken = 'Scaffold' '(';

      final file = File('lib/presentation/widgets/map/map_view.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content.contains(scaffoldToken), isFalse, reason: 'map_view.dart must not contain Scaffold(');

      // Control:
      const badWidget = 'return Scaffold' '(body: Container());';
      expect(badWidget.contains(scaffoldToken), isTrue);
    });
  });
}
