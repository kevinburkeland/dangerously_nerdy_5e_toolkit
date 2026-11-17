/// Shared Dart string literal reader that extracts string literals from Dart
/// source files and strings.
///
/// Handles:
/// - Single quotes ('...') and double quotes ("...")
/// - Raw strings (r'...', r"...", r''''...''', r"""...""")
/// - Triple-quoted strings ('''...''', """...""")
/// - Multi-line strings
/// - Adjacent literal joining ('a' 'b' -> 'ab')
/// - String interpolation (extracts literal parts; expressions inside are treated
///   as Dart code, not string contents)
/// - Skips single-line (//) and block (/* ... */, including nested) comments
/// - Unclosed strings fail with FormatException detailing byte position and message
library;

class DartStringLiteral {
  /// The literal text value (with adjacent string concatenation applied).
  final String value;

  /// 1-based line number where the literal (or its first concatenated segment) begins.
  final int lineNumber;

  /// 1-based column number where the literal begins.
  final int columnNumber;

  /// 0-based character offset in the source.
  final int offset;

  /// True if the string was marked with the raw (`r` or `R`) prefix.
  final bool isRaw;

  /// True if the string used triple-quote delimiters (`'''` or `"""`).
  final bool isMultiline;

  /// Optional path of the source file.
  final String filePath;

  const DartStringLiteral({
    required this.value,
    required this.lineNumber,
    required this.columnNumber,
    required this.offset,
    required this.isRaw,
    required this.isMultiline,
    this.filePath = '',
  });

  @override
  String toString() =>
      'DartStringLiteral("$value", line: $lineNumber, col: $columnNumber)';
}

/// Extracts all string literals from [source].
///
/// Throws [FormatException] if an unclosed string or comment is encountered.
List<DartStringLiteral> extractDartStringLiterals(
  String source, {
  String filePath = '',
}) {
  final scanner = _DartStringScanner(source, filePath: filePath);
  return scanner.scan();
}

class _DartStringScanner {
  final String source;
  final String filePath;
  final int len;

  int _offset = 0;
  int _line = 1;
  int _col = 1;

  final List<DartStringLiteral> _results = <DartStringLiteral>[];

  _DartStringScanner(this.source, {this.filePath = ''}) : len = source.length;

  int get offset => _offset;
  int get line => _line;
  int get col => _col;

  bool get isEof => _offset >= len;

  int peek([int ahead = 0]) {
    final idx = _offset + ahead;
    if (idx >= len) return -1;
    return source.codeUnitAt(idx);
  }

  void advance([int count = 1]) {
    for (int k = 0; k < count; k++) {
      if (_offset >= len) return;
      final c = source.codeUnitAt(_offset);
      _offset++;
      if (c == 0x0A) {
        // '\n'
        _line++;
        _col = 1;
      } else {
        _col++;
      }
    }
  }

  List<DartStringLiteral> scan() {
    // Temporary accumulation for adjacent string literal concatenation.
    _LiteralBuilder? currentBuilder;

    void flushCurrentBuilder() {
      if (currentBuilder != null && currentBuilder!.hasContent) {
        _results.add(currentBuilder!.build(filePath));
      }
      currentBuilder = null;
    }

    while (!isEof) {
      _skipWhitespaceAndComments();
      if (isEof) break;

      final startOffset = _offset;
      final startLine = _line;
      final startCol = _col;

      if (_isStringStart()) {
        final segments = _scanStringLiteral();
        // A single string token may produce multiple segments if it had interpolation.
        // E.g. "a $b c" produces literal segment "a " then interpolation, then " c".
        // Adjacent literals 'a' 'b' concatenate across tokens.
        for (int i = 0; i < segments.length; i++) {
          final seg = segments[i];
          if (i == 0) {
            // First segment of this token: joins with currentBuilder if exists.
            currentBuilder ??= _LiteralBuilder(
              startLine: startLine,
              startCol: startCol,
              startOffset: startOffset,
              isRaw: seg.isRaw,
              isMultiline: seg.isMultiline,
            );
            currentBuilder!.append(seg.text);
          } else {
            // Segment separated by interpolation: flush previous builder and start new one.
            flushCurrentBuilder();
            currentBuilder = _LiteralBuilder(
              startLine: seg.line,
              startCol: seg.col,
              startOffset: seg.offset,
              isRaw: seg.isRaw,
              isMultiline: seg.isMultiline,
            );
            currentBuilder!.append(seg.text);
          }
        }

        // Check if the next token is an adjacent string literal.
        // If not, flush currentBuilder.
        final savedOffset = _offset;
        final savedLine = _line;
        final savedCol = _col;
        _skipWhitespaceAndComments();
        final hasNextString = !isEof && _isStringStart();
        // Restore scanner position to right after the current string token
        _offset = savedOffset;
        _line = savedLine;
        _col = savedCol;

        if (!hasNextString) {
          flushCurrentBuilder();
        }
      } else {
        // Non-string token: flush any accumulated literal and advance.
        flushCurrentBuilder();
        advance();
      }
    }

    flushCurrentBuilder();
    return _results;
  }

  void _skipWhitespaceAndComments() {
    while (!isEof) {
      final c = peek();
      // Whitespace
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        advance();
        continue;
      }

      // Single-line comment //
      if (c == 0x2F && peek(1) == 0x2F) {
        advance(2);
        while (!isEof && peek() != 0x0A) {
          advance();
        }
        if (!isEof) advance(); // consume \n
        continue;
      }

      // Multi-line comment /* ... */ (nested supported)
      if (c == 0x2F && peek(1) == 0x2A) {
        final commentStartOffset = _offset;
        final commentStartLine = _line;
        final commentStartCol = _col;
        advance(2);
        int depth = 1;
        while (!isEof && depth > 0) {
          if (peek() == 0x2F && peek(1) == 0x2A) {
            depth++;
            advance(2);
          } else if (peek() == 0x2A && peek(1) == 0x2F) {
            depth--;
            advance(2);
          } else {
            advance();
          }
        }
        if (depth > 0) {
          throw FormatException(
            'Unclosed block comment starting at line $commentStartLine, col $commentStartCol (byte $commentStartOffset)',
            source,
            commentStartOffset,
          );
        }
        continue;
      }

      break;
    }
  }

  bool _isStringStart() {
    final c = peek();
    if (c == 0x27 || c == 0x22) {
      // ' or "
      return true;
    }
    if ((c == 0x72 || c == 0x52) && (peek(1) == 0x27 || peek(1) == 0x22)) {
      // r' or r" or R' or R"
      return true;
    }
    return false;
  }

  List<_Segment> _scanStringLiteral() {
    final startOffset = _offset;
    final startLine = _line;
    final startCol = _col;

    bool isRaw = false;
    final c = peek();
    if (c == 0x72 || c == 0x52) {
      isRaw = true;
      advance();
    }

    final quote = peek();
    advance(); // consume quote

    bool isMultiline = false;
    if (peek() == quote && peek(1) == quote) {
      isMultiline = true;
      advance(2); // consume remaining two quotes
    }

    final segments = <_Segment>[];
    final buf = StringBuffer();
    int currentSegLine = startLine;
    int currentSegCol = startCol;
    int currentSegOffset = startOffset;

    void flushSegment() {
      segments.add(_Segment(
        text: buf.toString(),
        line: currentSegLine,
        col: currentSegCol,
        offset: currentSegOffset,
        isRaw: isRaw,
        isMultiline: isMultiline,
      ));
      buf.clear();
    }

    while (true) {
      if (isEof) {
        throw FormatException(
          'Unclosed string literal starting at line $startLine, col $startCol (byte $startOffset)',
          source,
          startOffset,
        );
      }

      final ch = peek();

      // Check for closing delimiter
      if (isMultiline) {
        if (ch == quote && peek(1) == quote && peek(2) == quote) {
          advance(3);
          flushSegment();
          break;
        }
      } else {
        if (ch == quote) {
          advance();
          flushSegment();
          break;
        }
        if (ch == 0x0A && !isRaw) {
          throw FormatException(
            'Unclosed single-line string literal at newline, starting at line $startLine, col $startCol (byte $startOffset)',
            source,
            startOffset,
          );
        }
        if (ch == 0x0A && isRaw) {
          throw FormatException(
            'Unclosed raw single-line string literal at newline, starting at line $startLine, col $startCol (byte $startOffset)',
            source,
            startOffset,
          );
        }
      }

      if (isRaw) {
        buf.writeCharCode(ch);
        advance();
        continue;
      }

      // Non-raw string handling: escapes & interpolations
      if (ch == 0x5C) {
        // backslash \
        advance(); // consume \
        if (isEof) {
          throw FormatException(
            'Incomplete escape sequence at EOF in string starting at line $startLine, col $startCol',
            source,
            startOffset,
          );
        }
        final escaped = peek();
        advance();
        switch (escaped) {
          case 0x6E: // n
            buf.write('\n');
          case 0x72: // r
            buf.write('\r');
          case 0x74: // t
            buf.write('\t');
          case 0x62: // b
            buf.write('\b');
          case 0x66: // f
            buf.write('\f');
          case 0x76: // v
            buf.write('\v');
          case 0x5C: // \
            buf.write('\\');
          case 0x24: // $
            buf.write('\$');
          case 0x27: // '
            buf.write("'");
          case 0x22: // "
            buf.write('"');
          case 0x0A: // newline (escaped newline in multiline or single line)
            // Escaped newline: line continuation
            break;
          default:
            // For other escapes (e.g. \d in regex strings, \xHH, \uHHHH),
            // preserve the backslash and character so regex tokens remain intact!
            buf.write('\\');
            buf.writeCharCode(escaped);
        }
        continue;
      }

      // Check for interpolation: $
      if (ch == 0x24) {
        // $
        if (peek(1) == 0x7B) {
          // ${expression}
          flushSegment();
          advance(2); // consume ${
          _skipInterpolationExpression();
          currentSegLine = _line;
          currentSegCol = _col;
          currentSegOffset = _offset;
          continue;
        } else if (_isIdentifierStart(peek(1))) {
          // $identifier
          flushSegment();
          advance(); // consume $
          while (!isEof && _isIdentifierPart(peek())) {
            advance();
          }
          currentSegLine = _line;
          currentSegCol = _col;
          currentSegOffset = _offset;
          continue;
        }
      }

      buf.writeCharCode(ch);
      advance();
    }

    return segments;
  }

  void _skipInterpolationExpression() {
    int depth = 1;
    final exprStartOffset = _offset;
    final exprStartLine = _line;

    while (!isEof && depth > 0) {
      _skipWhitespaceAndComments();
      if (isEof) break;

      if (_isStringStart()) {
        final innerStartOffset = _offset;
        final innerStartLine = _line;
        final innerStartCol = _col;
        final innerSegments = _scanStringLiteral();
        for (final seg in innerSegments) {
          _results.add(DartStringLiteral(
            value: seg.text,
            lineNumber: innerStartLine,
            columnNumber: innerStartCol,
            offset: innerStartOffset,
            isRaw: seg.isRaw,
            isMultiline: seg.isMultiline,
            filePath: filePath,
          ));
        }
        continue;
      }

      final ch = peek();
      if (ch == 0x7B) {
        // {
        depth++;
        advance();
      } else if (ch == 0x7D) {
        // }
        depth--;
        advance();
      } else {
        advance();
      }
    }

    if (depth > 0) {
      throw FormatException(
        'Unclosed interpolation expression in string starting at line $exprStartLine (byte $exprStartOffset)',
        source,
        exprStartOffset,
      );
    }
  }

  bool _isIdentifierStart(int c) {
    if (c >= 0x61 && c <= 0x7A) return true; // a-z
    if (c >= 0x41 && c <= 0x5A) return true; // A-Z
    if (c == 0x5F) return true; // _
    return false;
  }

  bool _isIdentifierPart(int c) {
    if (_isIdentifierStart(c)) return true;
    if (c >= 0x30 && c <= 0x39) return true; // 0-9
    return false;
  }
}

class _Segment {
  final String text;
  final int line;
  final int col;
  final int offset;
  final bool isRaw;
  final bool isMultiline;

  _Segment({
    required this.text,
    required this.line,
    required this.col,
    required this.offset,
    required this.isRaw,
    required this.isMultiline,
  });
}

class _LiteralBuilder {
  final int startLine;
  final int startCol;
  final int startOffset;
  final bool isRaw;
  final bool isMultiline;
  final StringBuffer _buf = StringBuffer();

  _LiteralBuilder({
    required this.startLine,
    required this.startCol,
    required this.startOffset,
    required this.isRaw,
    required this.isMultiline,
  });

  bool get hasContent => true;

  void append(String text) {
    _buf.write(text);
  }

  DartStringLiteral build(String filePath) {
    return DartStringLiteral(
      value: _buf.toString(),
      lineNumber: startLine,
      columnNumber: startCol,
      offset: startOffset,
      isRaw: isRaw,
      isMultiline: isMultiline,
      filePath: filePath,
    );
  }
}
