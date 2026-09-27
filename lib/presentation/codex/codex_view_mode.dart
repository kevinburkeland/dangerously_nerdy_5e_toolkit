import 'package:flutter/material.dart';

/// Generic presentation model for a codex view mode tab/segment.
///
/// Encapsulates the visual representation (label, icon, count, accent) while
/// remaining decoupled from domain-specific enum semantics.
@immutable
class CodexViewMode<T> {
  /// The underlying identifier or enum value for this mode.
  final T key;

  /// User-facing label (e.g., 'All Spells', 'Bookmarks', '2024 Diffs').
  final String label;

  /// Icon representing this view mode.
  final IconData icon;

  /// Optional item count associated with this mode.
  final int? count;

  /// Optional custom accent color for this specific mode tab.
  final Color? accentColor;

  /// Optional screen reader semantics label.
  final String? semanticsLabel;

  const CodexViewMode({
    required this.key,
    required this.label,
    required this.icon,
    this.count,
    this.accentColor,
    this.semanticsLabel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexViewMode<T> &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          label == other.label &&
          icon == other.icon &&
          count == other.count &&
          accentColor == other.accentColor &&
          semanticsLabel == other.semanticsLabel;

  @override
  int get hashCode => Object.hash(
        key,
        label,
        icon,
        count,
        accentColor,
        semanticsLabel,
      );
}
