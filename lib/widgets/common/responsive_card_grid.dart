import 'package:flutter/material.dart';

/// Calculates the standard adaptive column count for 5e compendium cards.
int calculateCompendiumCrossAxisCount(double width) {
  if (width > 1000) return 3;
  if (width > 650) return 2;
  return 1;
}

/// A generic, responsive multi-column card grid widget.
///
/// Automatically determines the number of columns based on available width:
/// - Width > 1000: 3 columns
/// - Width > 650: 2 columns
/// - Width <= 650: 1 column
class ResponsiveCardGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? emptyState;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  const ResponsiveCardGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyState,
    this.spacing = 14.0,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 80),
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyState != null) {
      return emptyState!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = calculateCompendiumCrossAxisCount(constraints.maxWidth);
        final int rowCount = (items.length / crossAxisCount).ceil();

        return ListView.builder(
          controller: controller,
          physics: physics,
          padding: padding,
          itemCount: rowCount,
          itemBuilder: (context, rowIndex) {
            final startIndex = rowIndex * crossAxisCount;
            final rowItems = items.skip(startIndex).take(crossAxisCount).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int c = 0; c < crossAxisCount; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: c < rowItems.length
                          ? itemBuilder(context, rowItems[c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A generic, responsive multi-column sliver card grid for [CustomScrollView].
class SliverResponsiveCardGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const SliverResponsiveCardGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.spacing = 14.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount = calculateCompendiumCrossAxisCount(width);
    final int rowCount = (items.length / crossAxisCount).ceil();

    return SliverPadding(
      padding: padding,
      sliver: SliverList.builder(
        itemCount: rowCount,
        itemBuilder: (context, rowIndex) {
          final startIndex = rowIndex * crossAxisCount;
          final rowItems = items.skip(startIndex).take(crossAxisCount).toList();

          return Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int c = 0; c < crossAxisCount; c++) ...[
                  if (c > 0) SizedBox(width: spacing),
                  Expanded(
                    child: c < rowItems.length
                        ? RepaintBoundary(child: itemBuilder(context, rowItems[c]))
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
