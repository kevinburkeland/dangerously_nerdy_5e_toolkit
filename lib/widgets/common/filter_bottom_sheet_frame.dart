import 'package:flutter/material.dart';

/// Modal bottom sheet shell for compendium filters with drag handle, title, Reset All action,
/// scrollable content, and sticky Apply Filters button.
class FilterBottomSheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onResetAll;
  final VoidCallback? onApply;
  final List<Widget> children;

  const FilterBottomSheetFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.onResetAll,
    this.onApply,
    required this.children,
  });

  static Future<void> show(
    BuildContext context, {
    required WidgetBuilder builder,
    double initialChildSize = 0.75,
    double maxChildSize = 0.95,
    double minChildSize = 0.4,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        minChildSize: minChildSize,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: builder(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Drag Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header Row
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onResetAll,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset All'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(height: 24),

        // Filter Content
        ...children,

        const SizedBox(height: 24),

        // Bottom Apply Button
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onApply ?? () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}
