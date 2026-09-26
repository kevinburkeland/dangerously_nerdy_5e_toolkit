/// Pure Dart, vendor-agnostic Anti-Corruption Layer (ACL) utility for scrubbing
/// inline markup tags (e.g. `{@damage 1d6 + 2}`, `{@spell misty step|source}`, `{@condition poisoned}`)
/// from any tabletop RPG homebrew source without coupling to specific vendor platforms.
class GenericTagScrubber {
  GenericTagScrubber._();

  /// Universal inline tag pattern: `{@<tagName> <payload>}`
  ///
  /// Matches any alphanumeric or hyphenated tag name followed by optional content
  /// before the closing curly brace.
  static final RegExp _tagPattern =
      RegExp(r'\{@([a-zA-Z0-9_-]+)(?:\s+([^{}]+))?\}');

  /// Scrubs all inline markup tags from [input], extracting clean human-readable text.
  ///
  /// Iterates up to 10 passes to ensure nested tags are fully resolved.
  static String scrub(String input) {
    if (!input.contains('{@')) return input;

    var current = input;
    var passes = 0;

    while (_tagPattern.hasMatch(current) && passes < 10) {
      final prev = current;
      current = current.replaceAllMapped(_tagPattern, _processTagMatch);
      passes++;
      if (current == prev) break;
    }

    return current;
  }

  static String _processTagMatch(Match match) {
    final tag = match.group(1)?.toLowerCase() ?? '';
    final rawContent = match.group(2)?.trim() ?? '';

    if (rawContent.isEmpty) {
      switch (tag) {
        case 'h':
          return 'Hit: ';
        case 'hom':
          return 'Hit or Miss: ';
        case 'recharge':
          return '(Recharge 5–6)';
        default:
          return '';
      }
    }

    final parts = rawContent.split('|').map((p) => p.trim()).toList();
    final primary = parts.isNotEmpty ? parts[0] : '';

    // Handle generic mechanical tags
    switch (tag) {
      case 'dc':
        return primary.toUpperCase().startsWith('DC') ? primary : 'DC $primary';
      case 'recharge':
        return primary.startsWith('(') ? primary : '(Recharge $primary)';
      case 'hit':
        return primary.startsWith('+') || primary.startsWith('-')
            ? primary
            : '+$primary';
      case 'h':
        return 'Hit: $primary';
      case 'hom':
        return 'Hit or Miss: $primary';
      default:
        break;
    }

    // Pipe-delimited structural resolution:
    // In multi-part tags (e.g. {@tag name|source|displayText}), if a 3rd segment
    // is present and non-empty, it represents an explicit display text override.
    if (parts.length >= 3 && parts[2].isNotEmpty) {
      return parts[2];
    }

    // For 1 or 2 parts, return the primary content name/formula
    return primary;
  }

  /// Recursively scrubs all string values in [map], preserving all original keys
  /// and structure so unparsed/extra fields remain intact.
  ///
  /// Utilizes copy-on-write semantics: if no nested string contains markup tags,
  /// the original [map] instance is returned directly without heap allocation.
  static Map<String, dynamic> scrubMap(Map<String, dynamic> map) {
    var changed = false;
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      final val = entry.value;
      final scrubbed = scrubValue(val);
      if (!identical(scrubbed, val)) {
        changed = true;
      }
      result[key] = scrubbed;
    }
    return changed ? result : map;
  }

  /// Recursively scrubs any nested String, List, or Map structure.
  ///
  /// Preserves identity when child elements are unmodified.
  static dynamic scrubValue(dynamic value) {
    if (value is String) {
      return scrub(value);
    } else if (value is Map) {
      var changed = false;
      final result = <String, dynamic>{};
      for (final entry in value.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        final scrubbed = scrubValue(v);
        if (!identical(scrubbed, v)) {
          changed = true;
        }
        result[k] = scrubbed;
      }
      return changed ? result : value;
    } else if (value is List) {
      var changed = false;
      final result = List<dynamic>.filled(value.length, null);
      for (var i = 0; i < value.length; i++) {
        final item = value[i];
        final scrubbed = scrubValue(item);
        if (!identical(scrubbed, item)) {
          changed = true;
        }
        result[i] = scrubbed;
      }
      return changed ? result : value;
    }
    return value;
  }
}
