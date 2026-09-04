import 'package:flutter/material.dart';

class AccessibleActionTile extends StatelessWidget {
  final String title;
  final String mathematicalFormula;
  final String narrativeSpeech;
  final VoidCallback onTap;

  const AccessibleActionTile({
    super.key,
    required this.title,
    required this.mathematicalFormula,
    required this.narrativeSpeech,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isReducedMotion = mediaQuery.disableAnimations;

    return Semantics(
      button: true,
      onTap: onTap,
      label: "$title. $narrativeSpeech",
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 48.0,
          minHeight: 48.0,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: isReducedMotion
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        mathematicalFormula,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
