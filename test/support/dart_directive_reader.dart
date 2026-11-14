/// Shared Dart directive reader that extracts import, export, and part
/// directives from Dart source files and strings.
///
/// Handles:
/// - Single-line (`//`) and multi-line (`/* ... */`, including nested) comments
/// - String literals (single, double, triple, raw)
/// - Multi-line directives (where URI is on a subsequent line)
/// - Conditional imports (`if (...) 'uri'`) and configurations
/// - Distinguishing `part 'file.dart';` from `part of 'parent.dart';` / `part of my_lib;`
library;

import 'dart:io';

enum DirectiveKind {
  importDirective,
  exportDirective,
  partDirective,
}

class DirectiveUri {
  final String uri;
  final bool isConditional;
  final String? condition;

  const DirectiveUri({
    required this.uri,
    this.isConditional = false,
    this.condition,
  });

  @override
  String toString() => isConditional ? "if ($condition) '$uri'" : "'$uri'";
}

class DartDirective {
  final DirectiveKind kind;
  final int lineNumber;
  final String statement;
  final List<String> uris;
  final String primaryUri;
  final List<DirectiveUri> detailedUris;

  const DartDirective({
    required this.kind,
    required this.lineNumber,
    required this.statement,
    required this.uris,
    required this.primaryUri,
    required this.detailedUris,
  });

  bool get isImport => kind == DirectiveKind.importDirective;
  bool get isExport => kind == DirectiveKind.exportDirective;
  bool get isPart => kind == DirectiveKind.partDirective;

  @override
  String toString() => 'DartDirective($kind, line $lineNumber, uris: $uris)';
}

/// Strips comments and string literals from [source], preserving exact line
/// breaks and character offsets.
///
/// Replaces characters inside comments and string literals with spaces (or newlines)
/// so that regexes and token scanners never accidentally match directive keywords
/// inside comments or strings, while line numbers remain 100% accurate.
String stripCommentsAndStringsPreservingNewlines(String source) {
  final sb = StringBuffer();
  final len = source.length;
  int i = 0;

  while (i < len) {
    final c = source[i];

    // Check for single-line comment
    if (c == '/' && i + 1 < len && source[i + 1] == '/') {
      sb.write('  ');
      i += 2;
      while (i < len && source[i] != '\n') {
        sb.write(' ');
        i++;
      }
      continue;
    }

    // Check for multi-line comment (supporting nested block comments)
    if (c == '/' && i + 1 < len && source[i + 1] == '*') {
      sb.write('  ');
      i += 2;
      int depth = 1;
      while (i < len && depth > 0) {
        if (source[i] == '/' && i + 1 < len && source[i + 1] == '*') {
          depth++;
          sb.write('  ');
          i += 2;
        } else if (source[i] == '*' && i + 1 < len && source[i + 1] == '/') {
          depth--;
          sb.write('  ');
          i += 2;
        } else {
          sb.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      }
      continue;
    }

    // Check for raw string literals: r'''...''', r"""...""", r'...', r"..."
    if (c == 'r' && i + 1 < len && (source[i + 1] == "'" || source[i + 1] == '"')) {
      final quote = source[i + 1];
      final isTriple = i + 3 < len && source[i + 2] == quote && source[i + 3] == quote;
      if (isTriple) {
        sb.write('    ');
        i += 4;
        while (i < len) {
          if (source[i] == quote && i + 2 < len && source[i + 1] == quote && source[i + 2] == quote) {
            sb.write('   ');
            i += 3;
            break;
          }
          sb.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      } else {
        sb.write('  ');
        i += 2;
        while (i < len && source[i] != quote && source[i] != '\n') {
          sb.write(' ');
          i++;
        }
        if (i < len && source[i] == quote) {
          sb.write(' ');
          i++;
        }
      }
      continue;
    }

    // Check for standard string literals: '''...''', """...""", '...', "..."
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < len && source[i + 1] == quote && source[i + 2] == quote;
      if (isTriple) {
        sb.write('   ');
        i += 3;
        while (i < len) {
          if (source[i] == '\\' && i + 1 < len) {
            sb.write(source[i + 1] == '\n' ? ' \n' : '  ');
            i += 2;
            continue;
          }
          if (source[i] == quote && i + 2 < len && source[i + 1] == quote && source[i + 2] == quote) {
            sb.write('   ');
            i += 3;
            break;
          }
          sb.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      } else {
        sb.write(' ');
        i++;
        while (i < len && source[i] != quote && source[i] != '\n') {
          if (source[i] == '\\' && i + 1 < len) {
            sb.write(source[i + 1] == '\n' ? ' \n' : '  ');
            i += 2;
            continue;
          }
          sb.write(' ');
          i++;
        }
        if (i < len && source[i] == quote) {
          sb.write(' ');
          i++;
        }
      }
      continue;
    }

    sb.write(c);
    i++;
  }

  return sb.toString();
}

/// Strips only comments from [source], preserving string literals, newlines,
/// and character offsets. Characters inside comments are replaced with spaces
/// (or newlines) so character indices match [source] exactly.
String stripCommentsPreservingNewlines(String source) {
  final sb = StringBuffer();
  final len = source.length;
  int i = 0;

  while (i < len) {
    final c = source[i];

    // Single line comment
    if (c == '/' && i + 1 < len && source[i + 1] == '/') {
      sb.write('  ');
      i += 2;
      while (i < len && source[i] != '\n') {
        sb.write(' ');
        i++;
      }
      continue;
    }

    // Multi line comment (supporting nested block comments)
    if (c == '/' && i + 1 < len && source[i + 1] == '*') {
      sb.write('  ');
      i += 2;
      int depth = 1;
      while (i < len && depth > 0) {
        if (source[i] == '/' && i + 1 < len && source[i + 1] == '*') {
          depth++;
          sb.write('  ');
          i += 2;
        } else if (source[i] == '*' && i + 1 < len && source[i + 1] == '/') {
          depth--;
          sb.write('  ');
          i += 2;
        } else {
          sb.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      }
      continue;
    }

    // Raw string literals: keep as is
    if (c == 'r' && i + 1 < len && (source[i + 1] == "'" || source[i + 1] == '"')) {
      final quote = source[i + 1];
      final isTriple = i + 3 < len && source[i + 2] == quote && source[i + 3] == quote;
      if (isTriple) {
        sb.write(source.substring(i, i + 4));
        i += 4;
        while (i < len) {
          if (source[i] == quote && i + 2 < len && source[i + 1] == quote && source[i + 2] == quote) {
            sb.write(source.substring(i, i + 3));
            i += 3;
            break;
          }
          sb.write(source[i]);
          i++;
        }
      } else {
        sb.write(source.substring(i, i + 2));
        i += 2;
        while (i < len && source[i] != quote && source[i] != '\n') {
          sb.write(source[i]);
          i++;
        }
        if (i < len && source[i] == quote) {
          sb.write(quote);
          i++;
        }
      }
      continue;
    }

    // Standard string literals: keep as is
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple = i + 2 < len && source[i + 1] == quote && source[i + 2] == quote;
      if (isTriple) {
        sb.write(source.substring(i, i + 3));
        i += 3;
        while (i < len) {
          if (source[i] == '\\' && i + 1 < len) {
            sb.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          if (source[i] == quote && i + 2 < len && source[i + 1] == quote && source[i + 2] == quote) {
            sb.write(source.substring(i, i + 3));
            i += 3;
            break;
          }
          sb.write(source[i]);
          i++;
        }
      } else {
        sb.write(quote);
        i++;
        while (i < len && source[i] != quote && source[i] != '\n') {
          if (source[i] == '\\' && i + 1 < len) {
            sb.write(source.substring(i, i + 2));
            i += 2;
            continue;
          }
          sb.write(source[i]);
          i++;
        }
        if (i < len && source[i] == quote) {
          sb.write(quote);
          i++;
        }
      }
      continue;
    }

    sb.write(c);
    i++;
  }

  return sb.toString();
}

bool _isIdentifierChar(int codeUnit) {
  return (codeUnit >= 48 && codeUnit <= 57) || // 0-9
      (codeUnit >= 65 && codeUnit <= 90) || // A-Z
      (codeUnit >= 97 && codeUnit <= 122) || // a-z
      codeUnit == 95 || // _
      codeUnit == 36; // $
}

/// Parses all Dart directives (`import`, `export`, and `part`) in [source].
///
/// Skips `part of ...` directives.
List<DartDirective> parseDartDirectives(String source) {
  final strippedComments = stripCommentsPreservingNewlines(source);
  final strippedAll = stripCommentsAndStringsPreservingNewlines(source);

  final directives = <DartDirective>[];
  final len = strippedAll.length;
  int i = 0;
  int braceDepth = 0;

  while (i < len) {
    final c = strippedAll[i];
    if (c == '{') {
      braceDepth++;
      i++;
      continue;
    }
    if (c == '}') {
      if (braceDepth > 0) braceDepth--;
      i++;
      continue;
    }

    // Directives can only occur at top level (braceDepth == 0)
    if (braceDepth > 0) {
      i++;
      continue;
    }

    // Look for directive keyword boundary
    final isWordStart = i == 0 || !_isIdentifierChar(strippedAll.codeUnitAt(i - 1));
    if (!isWordStart || !_isIdentifierChar(strippedAll.codeUnitAt(i))) {
      i++;
      continue;
    }

    final start = i;
    while (i < len && _isIdentifierChar(strippedAll.codeUnitAt(i))) {
      i++;
    }
    final keyword = strippedAll.substring(start, i);

    DirectiveKind? kind;
    if (keyword == 'import') {
      kind = DirectiveKind.importDirective;
    } else if (keyword == 'export') {
      kind = DirectiveKind.exportDirective;
    } else if (keyword == 'part') {
      kind = DirectiveKind.partDirective;
    }

    if (kind == null) {
      continue;
    }

    // Check that keyword is not preceded by a dot (e.g. obj.import) or type keywords
    int prev = start - 1;
    while (prev >= 0 &&
        (strippedAll[prev] == ' ' ||
            strippedAll[prev] == '\t' ||
            strippedAll[prev] == '\n' ||
            strippedAll[prev] == '\r')) {
      prev--;
    }
    if (prev >= 0 && strippedAll[prev] == '.') {
      continue;
    }

    // Look ahead to check the token immediately following the keyword in strippedComments
    int look = i;
    while (look < len &&
        (strippedComments[look] == ' ' ||
            strippedComments[look] == '\t' ||
            strippedComments[look] == '\n' ||
            strippedComments[look] == '\r')) {
      look++;
    }

    if (look >= len) {
      continue;
    }

    // If 'part', check if followed by 'of' or a string literal
    if (kind == DirectiveKind.partDirective) {
      if (look + 2 <= len && strippedComments.substring(look, look + 2) == 'of') {
        if (look + 2 == len || !_isIdentifierChar(strippedComments.codeUnitAt(look + 2))) {
          // It's a 'part of' directive; skip to semicolon
          while (i < len && strippedAll[i] != ';') {
            i++;
          }
          if (i < len && strippedAll[i] == ';') i++;
          continue;
        }
      }

      // If not 'of', the next token for a valid part directive MUST be a string literal (' or " or r' or r")
      final nextChar = strippedComments[look];
      final isRawQuote = nextChar == 'r' && look + 1 < len && (strippedComments[look + 1] == "'" || strippedComments[look + 1] == '"');
      final isQuote = nextChar == "'" || nextChar == '"';
      if (!isQuote && !isRawQuote) {
        // Not a part directive (e.g. 'part' used as identifier)
        continue;
      }
    } else {
      // For import or export, next token must be a string literal, 'deferred', or identifier string
      final nextChar = strippedComments[look];
      final isRawQuote = nextChar == 'r' && look + 1 < len && (strippedComments[look + 1] == "'" || strippedComments[look + 1] == '"');
      final isQuote = nextChar == "'" || nextChar == '"';
      if (!isQuote && !isRawQuote) {
        // Check if starts with deferred
        if (look + 8 <= len && strippedComments.substring(look, look + 8) == 'deferred') {
          // valid
        } else {
          continue;
        }
      }
    }

    // Find the terminating semicolon
    final stmtStart = start;
    while (i < len && strippedAll[i] != ';') {
      i++;
    }
    final stmtEnd = i < len ? i + 1 : len;
    if (i < len && strippedAll[i] == ';') {
      i++;
    }

    // Calculate line number (1-based)
    final lineNumber = '\n'.allMatches(source.substring(0, stmtStart)).length + 1;
    final stmtText = strippedComments.substring(stmtStart, stmtEnd);

    // Extract URIs from stmtText
    final detailedUris = <DirectiveUri>[];
    final uris = <String>[];

    // Regex to match string literals and check if preceded by `if (...)`
    final uriTokenRegex = RegExp(
      r'''(?:if\s*\(([^)]+)\)\s*)?r?['"]([^'"]+)['"]''',
      multiLine: true,
    );

    for (final match in uriTokenRegex.allMatches(stmtText)) {
      final condition = match.group(1)?.trim();
      final uri = match.group(2)!;
      final isConditional = condition != null;

      uris.add(uri);
      detailedUris.add(
        DirectiveUri(
          uri: uri,
          isConditional: isConditional,
          condition: condition,
        ),
      );
    }

    if (uris.isNotEmpty) {
      directives.add(
        DartDirective(
          kind: kind,
          lineNumber: lineNumber,
          statement: stmtText.trim(),
          uris: uris,
          primaryUri: uris.first,
          detailedUris: detailedUris,
        ),
      );
    }
  }

  return directives;
}

/// Parses all Dart directives from [file].
List<DartDirective> parseDartDirectivesFromFile(File file) {
  return parseDartDirectives(file.readAsStringSync());
}

/// Extracts all directive URIs (imports, exports, and parts) from [source].
List<String> extractAllDirectiveUris(String source) {
  final directives = parseDartDirectives(source);
  final allUris = <String>[];
  for (final d in directives) {
    allUris.addAll(d.uris);
  }
  return allUris;
}

/// Extracts all import and export URIs from [source], ignoring comments and strings.
///
/// Drop-in replacement for legacy helper functions.
List<String> extractImportExportUris(String source) {
  final directives = parseDartDirectives(source);
  final uris = <String>[];
  for (final d in directives) {
    if (d.kind == DirectiveKind.importDirective || d.kind == DirectiveKind.exportDirective) {
      uris.addAll(d.uris);
    }
  }
  return uris;
}
