import 'dart:io';

/// Pattern matching top-level public class, mixin, enum, typedef, extension type, or named extension declarations.
final _declarationPattern = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*'
  r'(?:class|enum|mixin|typedef|extension\s+type|extension)\s+'
  r'([A-Za-z0-9_]+)',
);

/// Extracts public top-level type names declared directly in [content].
Set<String> extractDeclaredTypeNames(String content) {
  final types = <String>{};
  final lines = content.split('\n');
  for (final line in lines) {
    final match = _declarationPattern.firstMatch(line);
    if (match != null) {
      final name = match.group(1)!;
      if (name.startsWith('_')) continue;
      if (name == 'on' || name == 'type') continue;
      types.add(name);
    }
  }
  return types;
}

/// Scans all .dart files across [libs] and returns all declared public type names.
Set<String> declaredTypeNames(List<Directory> libs) {
  final types = <String>{};
  for (final libDir in libs) {
    if (!libDir.existsSync()) continue;
    for (final entity in libDir.listSync(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        types.addAll(extractDeclaredTypeNames(entity.readAsStringSync()));
      }
    }
  }
  return types;
}

/// Renders a deterministic Markdown table folder index for all folders under lib/.
String renderFolderIndex(String repoRoot) {
  final rootLib = Directory('$repoRoot/lib');
  if (!rootLib.existsSync()) {
    return '| Folder | Files | Declared Types |\n|---|---|---|\n';
  }

  // Find all folders under lib/ (including lib itself)
  final folderPaths = <String>{'lib'};
  for (final entity in rootLib.listSync(recursive: true, followLinks: false)) {
    if (entity is Directory) {
      var rel = entity.path.replaceAll('\\', '/');
      if (rel.startsWith('./')) rel = rel.substring(2);
      if (repoRoot != '.' && repoRoot.isNotEmpty && rel.startsWith('$repoRoot/')) {
        rel = rel.substring(repoRoot.length + 1);
      }
      if (rel.startsWith('./')) rel = rel.substring(2);
      folderPaths.add(rel);
    }
  }

  final sortedFolders = folderPaths.toList()..sort();

  final buf = StringBuffer();
  buf.writeln('| Folder | Files | Declared Types |');
  buf.writeln('|---|---|---|');

  for (final folder in sortedFolders) {
    final dir = Directory('$repoRoot/$folder');
    final entities = dir.existsSync() ? dir.listSync(followLinks: false) : <FileSystemEntity>[];
    final dartFiles = entities.whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    final count = dartFiles.length;

    if (count == 0) {
      buf.writeln('| `$folder` | 0 | |');
    } else {
      final names = <String>{};
      for (final file in dartFiles) {
        names.addAll(extractDeclaredTypeNames(file.readAsStringSync()));
      }
      final sortedNames = names.toList()..sort();
      final String namesCell;
      if (sortedNames.length <= 8) {
        namesCell = sortedNames.join(', ');
      } else {
        final first8 = sortedNames.take(8).join(', ');
        final remaining = sortedNames.length - 8;
        namesCell = '$first8, +$remaining more';
      }
      buf.writeln('| `$folder` | $count | $namesCell |');
    }
  }

  return buf.toString();
}

const startMarker = '<!-- GENERATED:folder-index START (dart run tool/generate_codebase_map.dart) -->';
const endMarker = '<!-- GENERATED:folder-index END -->';

/// Replaces only the text between [startMarker] and [endMarker] in [originalContent].
String updateCodebaseMapContent(String originalContent, String newFolderIndex) {
  final startIdx = originalContent.indexOf(startMarker);
  if (startIdx == -1) {
    throw StateError('Missing start marker: $startMarker');
  }
  final endIdx = originalContent.indexOf(endMarker);
  if (endIdx == -1 || endIdx < startIdx) {
    throw StateError('Missing end marker: $endMarker');
  }

  final before = originalContent.substring(0, startIdx + startMarker.length);
  final after = originalContent.substring(endIdx);
  return '$before\n$newFolderIndex$after';
}
