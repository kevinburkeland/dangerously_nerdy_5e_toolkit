import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

List<String> checkActionPinningInWorkflow(String workflowContent, {String filename = 'workflow.yml'}) {
  final lines = workflowContent.split('\n');
  final problems = <String>[];
  final usesRegex = RegExp(r'^\s*(?:-\s*)?uses:\s*([^#\s]+)');
  final pinnedActionRegex = RegExp(r'^[a-zA-Z0-9_\-\./]+@[0-9a-fA-F]{40}$');

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final match = usesRegex.firstMatch(line);
    if (match != null) {
      final actionRef = match.group(1)!;
      if (!pinnedActionRegex.hasMatch(actionRef)) {
        problems.add(
          '$filename:${i + 1}: Action "$actionRef" is not pinned to a 40-character commit SHA',
        );
      }
    }
  }

  return problems;
}

void main() {
  group('Workflow Action Pinning Compliance Tests', () {
    test('all GitHub Action workflows only use actions pinned to 40-character commit SHAs', () {
      final workflowsDir = Directory('.github/workflows');
      expect(workflowsDir.existsSync(), isTrue, reason: '.github/workflows must exist');

      final ymlFiles = workflowsDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
          .toList();

      expect(ymlFiles, isNotEmpty, reason: 'Expected to find workflow files in .github/workflows');

      final allProblems = <String>[];
      for (final file in ymlFiles) {
        final content = file.readAsStringSync();
        final problems = checkActionPinningInWorkflow(content, filename: file.path);
        allProblems.addAll(problems);
      }

      expect(
        allProblems,
        isEmpty,
        reason: 'Found unpinned GitHub Actions:\n${allProblems.join('\n')}',
      );
    });

    test('negative case: unpinned action reference (branch, tag, or version) is rejected', () {
      const invalidWorkflow = '''
name: Test Workflow
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4.7.0
      - uses: subosito/flutter-action@main
''';
      final problems = checkActionPinningInWorkflow(invalidWorkflow, filename: 'invalid.yml');
      expect(problems.length, 3);
      expect(problems[0], contains('actions/checkout@v4'));
      expect(problems[1], contains('actions/setup-java@v4.7.0'));
      expect(problems[2], contains('subosito/flutter-action@main'));
    });
  });
}
