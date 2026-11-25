/// Shared normalization and field-by-field diff helpers for Step 6 goldens.
library;

/// Normalizes volatile fields in a serialized [Character.toMap] payload so
/// golden comparisons are deterministic across runs.
///
/// Normalized keys:
/// - Top-level `id.slug` -> `'<normalized-id>'`
/// - Each `inventory[i].instanceId` -> `'inv-$i'`
/// - Any recursive map key named `updatedAt`, `createdAt`, `timestamp`,
///   `hlc`, or `replicaId` -> `'<normalized>'`
Map<String, dynamic> normalizeCharacterMap(Map<String, dynamic> raw) {
  final result = _normalizeNode(raw) as Map<String, dynamic>;
  final id = result['id'];
  if (id is Map<String, dynamic> && id.containsKey('slug')) {
    id['slug'] = '<normalized-id>';
  }
  final inventory = result['inventory'];
  if (inventory is List) {
    for (var i = 0; i < inventory.length; i++) {
      final item = inventory[i];
      if (item is Map<String, dynamic> && item.containsKey('instanceId')) {
        item['instanceId'] = 'inv-$i';
      }
    }
  }
  return result;
}

const _volatileKeys = {
  'updatedAt',
  'createdAt',
  'timestamp',
  'hlc',
  'replicaId',
};

Object? _normalizeNode(Object? node) {
  if (node is Map) {
    final sortedKeys = node.keys.map((k) => k.toString()).toList()..sort();
    final out = <String, dynamic>{};
    for (final key in sortedKeys) {
      if (_volatileKeys.contains(key)) {
        out[key] = '<normalized>';
      } else {
        out[key] = _normalizeNode(node[key]);
      }
    }
    return out;
  }
  if (node is List) {
    return node.map(_normalizeNode).toList();
  }
  return node;
}

/// Returns a human-readable description of the first difference between
/// [expected] and [actual], or `null` if they are deeply equal.
String? firstJsonDiff(Object? expected, Object? actual, [String path = r'$']) {
  if (expected == null && actual == null) return null;
  if (expected is Map && actual is Map) {
    final expKeys = expected.keys.map((k) => k.toString()).toSet();
    final actKeys = actual.keys.map((k) => k.toString()).toSet();
    final missing = expKeys.difference(actKeys).toList()..sort();
    if (missing.isNotEmpty) {
      return '$path: missing key(s) $missing';
    }
    final extra = actKeys.difference(expKeys).toList()..sort();
    if (extra.isNotEmpty) {
      return '$path: unexpected extra key(s) $extra';
    }
    final sorted = expKeys.toList()..sort();
    for (final k in sorted) {
      final diff = firstJsonDiff(expected[k], actual[k], '$path.$k');
      if (diff != null) return diff;
    }
    return null;
  }
  if (expected is List && actual is List) {
    if (expected.length != actual.length) {
      return '$path: list length expected ${expected.length}, got ${actual.length}';
    }
    for (var i = 0; i < expected.length; i++) {
      final diff = firstJsonDiff(expected[i], actual[i], '$path[$i]');
      if (diff != null) return diff;
    }
    return null;
  }
  if (expected is num && actual is num) {
    if ((expected - actual).abs() <= 1e-12) return null;
    return '$path: expected $expected, got $actual';
  }
  if (expected.runtimeType != actual.runtimeType || expected != actual) {
    return '$path: expected ${expected.runtimeType}($expected), got ${actual.runtimeType}($actual)';
  }
  return null;
}
