import 'package:flutter/material.dart';
import '../../widgets/room_banner_widget.dart';
import 'codex_app_bar_title.dart';
import 'codex_header_config.dart';

/// Reusable page shell for codex and compendium screens.
///
/// Consistently orchestrates the layout hierarchy:
/// - AppBar with [CodexAppBarTitle], rules edition toggle, and screen actions
/// - Room broadcast banner
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

  /// Optional rules edition toggle widget placed in the AppBar actions.
  final Widget? rulesEditionToggle;

  /// Whether to display the room broadcast banner at the top of the body.
  final bool showRoomBanner;

  /// Custom banner widget displayed below the room banner (if any).
  final Widget? customBanner;

  /// Search header widget (typically [CompendiumSearchHeader]).
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

  /// Main content widget when [isEmpty] is false (typically [ResponsiveCardGrid]).
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
    this.rulesEditionToggle,
    this.showRoomBanner = true,
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
            if (rulesEditionToggle != null) rulesEditionToggle!,
            if (headerConfig.actions != null) ...headerConfig.actions!,
            const SizedBox(width: 8),
          ],
        );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: Column(
          children: [
            // Room Broadcast Banner
            if (showRoomBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: RoomBannerWidget(compact: true),
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
