import 'package:flutter/material.dart';
import 'codex_app_bar_title.dart';
import 'codex_header_config.dart';

/// Reusable page shell for codex and compendium screens.
///
/// Consistently orchestrates the layout hierarchy:
/// - AppBar with [CodexAppBarTitle], optional context [headerControl], and actions
/// - Optional [sessionContextBanner] (e.g. room or campaign connection context)
/// - Search header
/// - View mode selector
/// - Primary and secondary filter areas
/// - Optional status/attribution header
/// - Empty state or responsive grid content
class CodexPageShell extends StatelessWidget {
  /// Header configuration containing title, icon, count, and actions.
  final CodexHeaderConfig headerConfig;

  /// Optional custom AppBar if standard AppBar is overridden.
  final PreferredSizeWidget? customAppBar;

  /// Optional context or edition control widget placed in the AppBar actions
  /// (e.g. rules edition toggle, campaign selector, sync indicator).
  final Widget? headerControl;

  /// Optional banner widget displaying current room/session/campaign context.
  final Widget? sessionContextBanner;

  /// Custom banner widget displayed below the session context banner (if any).
  final Widget? customBanner;

  /// Search header widget (typically a search text field or search bar).
  final Widget searchHeader;

  /// View mode selector widget (typically [CodexModeSelector]).
  final Widget? modeSelector;

  /// Primary filter area (e.g. [CodexFilterStrip] for roles, categories, or CR bands).
  final Widget? filterArea;

  /// Optional secondary filter area or chip row.
  final Widget? secondaryFilterArea;

  /// Optional status/attribution header placed above the content grid.
  final Widget? statusHeader;

  /// Whether the current filtered list is empty.
  final bool isEmpty;

  /// Widget displayed when [isEmpty] is true (typically [EmptyStateCard]).
  final Widget? emptyState;

  /// Main content widget when [isEmpty] is false (typically [ResponsiveCardGrid] or sliver view).
  final Widget content;

  /// Optional FloatingActionButton (e.g. for quick roll or action triggers).
  final Widget? floatingActionButton;

  /// Spacing between filters and content (default: 6).
  final double contentSpacing;

  const CodexPageShell({
    super.key,
    required this.headerConfig,
    required this.searchHeader,
    required this.content,
    this.customAppBar,
    this.headerControl,
    this.sessionContextBanner,
    this.customBanner,
    this.modeSelector,
    this.filterArea,
    this.secondaryFilterArea,
    this.statusHeader,
    this.isEmpty = false,
    this.emptyState,
    this.floatingActionButton,
    this.contentSpacing = 6.0,
  });

  @override
  Widget build(BuildContext context) {
    final PreferredSizeWidget appBar = customAppBar ??
        AppBar(
          title: CodexAppBarTitle(config: headerConfig),
          actions: [
            if (headerControl != null) headerControl!,
            if (headerConfig.actions != null) ...headerConfig.actions!,
            const SizedBox(width: 8),
          ],
        );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            // Session Context Banner (e.g. Room Connection)
            if (sessionContextBanner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: sessionContextBanner!,
              ),

            // Optional Custom Banner
            if (customBanner != null) customBanner!,

            // Search Header
            searchHeader,

            // View Mode Selector
            if (modeSelector != null) modeSelector!,

            // Filter Areas
            if (filterArea != null) filterArea!,
            if (secondaryFilterArea != null) secondaryFilterArea!,

            // Status or Attribution Header
            if (statusHeader != null) statusHeader!,

            if (contentSpacing > 0) SizedBox(height: contentSpacing),

            // Content Area (Grid or Empty State)
            Expanded(
              child: isEmpty
                  ? (emptyState ?? const SizedBox.shrink())
                  : content,
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
