import 'dart:io';
import 'codebase_map_generator.dart';

void main() {
  final targetFile = File('.agents/rules/codebase_map.md');
  if (!targetFile.existsSync()) {
    stderr.writeln('Error: .agents/rules/codebase_map.md not found.');
    exit(1);
  }

  final originalContent = targetFile.readAsStringSync();
  final folderIndex = renderFolderIndex('.');

  final updatedContent = updateCodebaseMapContent(originalContent, folderIndex);
  targetFile.writeAsStringSync(updatedContent);
  stdout.writeln('Successfully updated .agents/rules/codebase_map.md folder index.');
}
