import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Campaign Record Ownership Source Bar', () {
    final libDir = Directory('lib');

    const allowedFileNames = {
      'local_campaign_repository.dart',
      'app_database_service.dart',
      'campaign_storage_migration.dart',
    };

    const restrictedTokens = [
      'boxCampaignProfiles',
      'dn5e_campaign_profile_',
      'dn5e_campaign_active_id',
      'profileKeyPrefix',
      'profileIndexKey',
      'activeProfileIdKey',
    ];

    List<String> checkFileViolations(String relativePath, String content) {
      final normalizedPath = relativePath.replaceAll('\\', '/');
      final fileName = normalizedPath.split('/').last;

      if (allowedFileNames.contains(fileName)) {
        return [];
      }

      final lines = content.split('\n');
      final violations = <String>[];
      bool inBlockComment = false;

      for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();

        if (inBlockComment) {
          if (line.contains('*/')) {
            line = line.substring(line.indexOf('*/') + 2).trim();
            inBlockComment = false;
          } else {
            continue;
          }
        }
        if (line.startsWith('/*')) {
          if (!line.contains('*/')) {
            inBlockComment = true;
            continue;
          } else {
            line = line.substring(line.indexOf('*/') + 2).trim();
          }
        }

        if (line.startsWith('//') || line.startsWith('*')) {
          continue;
        }

        final lineWithoutComments = line.split('//').first;

        for (final token in restrictedTokens) {
          if (lineWithoutComments.contains(token)) {
            violations.add('$normalizedPath:${i + 1} mentions restricted token "$token": $line');
          }
        }
      }

      return violations;
    }

    test('Source Bar: Only approved repository/migration files may reference campaign persistence keys', () {
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
          .toList();

      final allViolations = <String>[];

      for (final file in dartFiles) {
        final relativePath = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();
        final fileViolations = checkFileViolations(relativePath, content);
        allViolations.addAll(fileViolations);
      }

      expect(
        allViolations,
        isEmpty,
        reason: 'Restricted campaign persistence keys found in unapproved lib/ files:\n${allViolations.join('\n')}',
      );
    });

    group('Source Bar Self-Tests', () {
      test('One violation caught in an unapproved file', () {
        const fakeUnapprovedPath = 'lib/services/fake_unapproved_service.dart';
        const fakeContentWithViolation = '''
class FakeService {
  void doSomething() {
    print(boxCampaignProfiles);
  }
}
''';

        final violations = checkFileViolations(fakeUnapprovedPath, fakeContentWithViolation);
        expect(violations, isNotEmpty);
        expect(violations.first, contains('boxCampaignProfiles'));
      });

      test('One allowed file passes even when referencing restricted tokens', () {
        const allowedPath = 'lib/infrastructure/repositories/local_campaign_repository.dart';
        const contentWithTokens = '''
class LocalCampaignRepository {
  static const String profileKeyPrefix = 'dn5e_campaign_profile_';
  static const String profileIndexKey = 'dn5e_campaign_profile_index';
  static const String activeProfileIdKey = 'dn5e_campaign_active_id';
}
''';

        final violations = checkFileViolations(allowedPath, contentWithTokens);
        expect(violations, isEmpty);
      });
    });
  });
}
