import 'package:flutter/material.dart';
import '../../../../domain/ingestion/models/ingestion_candidate.dart';

/// Card widget summarizing an individual detected object candidate.
class CandidateCard extends StatelessWidget {
  final IngestionCandidate candidate;
  final bool isSelected;
  final VoidCallback onSelect;

  const CandidateCard({
    super.key,
    required this.candidate,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ident = candidate.identification;

    final missingCount = candidate.missingRequiredFields.length;
    final invalidCount = candidate.invalidFields.length;
    final ambiguousCount = candidate.ambiguousFields.length;
    final extractedCount = candidate.validFields.length;

    final typeLabel = (candidate.targetTypeKey != null &&
            candidate.targetTypeKey!.isNotEmpty)
        ? candidate.targetTypeKey![0].toUpperCase() +
            candidate.targetTypeKey!.substring(1)
        : (candidate.identification.isAmbiguous ? 'Ambiguous' : 'Unknown');

    final confidencePercent = (ident.confidence * 100).toStringAsFixed(0);

    return Semantics(
      label: 'Candidate ${candidate.displayName}, type $typeLabel, $confidencePercent% confidence. '
          '$missingCount missing fields, $invalidCount invalid fields, $ambiguousCount ambiguous fields.',
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.4),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      candidate.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    '$confidencePercent% confidence',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (missingCount > 0)
                    _StatusBadge(
                      label: '$missingCount missing',
                      color: Colors.orangeAccent.shade400,
                    ),
                  if (invalidCount > 0)
                    _StatusBadge(
                      label: '$invalidCount invalid',
                      color: Colors.redAccent.shade400,
                    ),
                  if (ambiguousCount > 0)
                    _StatusBadge(
                      label: '$ambiguousCount ambiguous',
                      color: Colors.amberAccent.shade400,
                    ),
                  if (missingCount == 0 && invalidCount == 0 && ambiguousCount == 0)
                    _StatusBadge(
                      label: '$extractedCount extracted',
                      color: Colors.greenAccent.shade400,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
