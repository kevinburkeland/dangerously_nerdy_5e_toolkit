import 'package:flutter/material.dart';

/// Presentation configuration for a codex screen's AppBar title and actions.
///
/// Decoupled from specific D&D entity semantics.
@immutable
class CodexHeaderConfig {
  /// Primary title of the codex (e.g., 'Class Catalogue', 'Feats Compendium').
  final String title;

  /// Optional icon representing the entity family.
  final IconData? icon;

  /// Optional custom icon or glyph widget (overrides [icon] if provided).
  final Widget? iconWidget;

  /// Accent color for the icon container and badge highlights.
  final Color? accentColor;

  /// Current visible count of filtered items.
  final int? visibleCount;

  /// Accessibility / screen reader label for the header.
  final String? semanticsLabel;

  /// Additional action widgets for the AppBar (excluding edition toggle).
  final List<Widget>? actions;

  const CodexHeaderConfig({
    required this.title,
    this.icon,
    this.iconWidget,
    this.accentColor,
    this.visibleCount,
    this.semanticsLabel,
    this.actions,
  });

  CodexHeaderConfig copyWith({
    String? title,
    IconData? icon,
    Widget? iconWidget,
    Color? accentColor,
    int? visibleCount,
    String? semanticsLabel,
    List<Widget>? actions,
  }) {
    return CodexHeaderConfig(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      iconWidget: iconWidget ?? this.iconWidget,
      accentColor: accentColor ?? this.accentColor,
      visibleCount: visibleCount ?? this.visibleCount,
      semanticsLabel: semanticsLabel ?? this.semanticsLabel,
      actions: actions ?? this.actions,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexHeaderConfig &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          icon == other.icon &&
          accentColor == other.accentColor &&
          visibleCount == other.visibleCount &&
          semanticsLabel == other.semanticsLabel;

  @override
  int get hashCode => Object.hash(
        title,
        icon,
        accentColor,
        visibleCount,
        semanticsLabel,
      );
}
