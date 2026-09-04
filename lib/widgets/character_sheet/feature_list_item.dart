import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../common/formatted_markdown_text.dart';

/// Interactive feature item for Traits, Features, and Feats with deep reference modal bottom sheets.
class FeatureListItem extends StatelessWidget {
  final String name;
  final String source;
  final String descriptionMarkdown;
  final IconData? icon;
  final Widget? glyphWidget;
  final Color? badgeColor;

  const FeatureListItem({
    super.key,
    required this.name,
    required this.source,
    required this.descriptionMarkdown,
    this.icon,
    this.glyphWidget,
    this.badgeColor,
  });

  void _showFeatureDetailsModal(BuildContext context) {
    HapticService.lightImpact(context);
    final theme = Theme.of(context);
    final effectiveColor = badgeColor ?? theme.colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Semantics node
                  Semantics(
                    header: true,
                    label: 'Feature Details: $name',
                    child: Row(
                      children: [
                        if (glyphWidget != null)
                          SizedBox(width: 40, height: 40, child: glyphWidget)
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: effectiveColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
                            ),
                            child: Icon(icon ?? Icons.auto_awesome, color: effectiveColor, size: 22),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                source,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: effectiveColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Feature Description Body
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: descriptionMarkdown.trim().isNotEmpty
                          ? FormattedMarkdownText(
                              descriptionMarkdown,
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                              fontSize: 14,
                              defaultColor: theme.colorScheme.onSurface,
                              boldColor: theme.colorScheme.primary,
                            )
                          : Text(
                              'No detailed description available for this feature.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = badgeColor ?? theme.colorScheme.primary;

    return Semantics(
      button: true,
      label: 'Feature: $name, $source. Tap to open details.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showFeatureDetailsModal(context),
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  if (glyphWidget != null)
                    SizedBox(width: 22, height: 22, child: glyphWidget)
                  else
                    Icon(icon ?? Icons.auto_awesome, size: 16, color: effectiveColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (source.isNotEmpty)
                          Text(
                            source,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
