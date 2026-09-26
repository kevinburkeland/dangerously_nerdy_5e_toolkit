import 'package:flutter/material.dart';
import '../../application/storage/storage_durability_coordinator.dart';
import 'package:vtt_engine_core/storage/models/storage_telemetry_report.dart';

/// Ambient, non-intrusive banner informing users of browser storage eviction risks,
/// quota saturation, and PWA installation safeguards.
class StorageDurabilityBanner extends StatefulWidget {
  final StorageDurabilityCoordinator coordinator;
  final VoidCallback? onExportColdStorage;
  final VoidCallback? onDismiss;

  const StorageDurabilityBanner({
    super.key,
    required this.coordinator,
    this.onExportColdStorage,
    this.onDismiss,
  });

  @override
  State<StorageDurabilityBanner> createState() =>
      _StorageDurabilityBannerState();
}

class _StorageDurabilityBannerState extends State<StorageDurabilityBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StorageTelemetryReport>(
      stream: widget.coordinator.telemetryStream,
      initialData: widget.coordinator.currentTelemetry,
      builder: (context, snapshot) {
        final report = snapshot.data;
        if (report == null) {
          return const SizedBox.shrink();
        }

        // Condition 3: Critical storage pressure (>= 80% quota saturation)
        if (report.isCriticalPressure) {
          return _buildCriticalPressureAlert(context, report);
        }

        // Zero-Friction Invariant: completely hidden if storage is persisted or inside a standalone PWA
        if (report.isPersisted || report.profile.isStandalonePwa) {
          return const SizedBox.shrink();
        }

        // If user dismissed this session's warning, remain hidden
        if (_dismissed) {
          return const SizedBox.shrink();
        }

        // Condition 1: WebKit 7-day ITP eviction risk in browser tab
        if (report.isWebKitEvictionRisk) {
          return _buildSafariRiskBanner(context);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCriticalPressureAlert(
    BuildContext context,
    StorageTelemetryReport report,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      label:
          'Critical storage warning: Quota is ${report.quotaUsagePercent.toStringAsFixed(0)} percent full. Export cold storage backup now.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: colorScheme.error,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8.0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 240, maxWidth: 600),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colorScheme.error,
                        size: 28.0,
                      ),
                      const SizedBox(width: 12.0),
                      Flexible(
                        child: Text(
                          'Storage capacity is reaching critical limits (${report.quotaUsagePercent.toStringAsFixed(0)}% used). Export a cold-storage backup immediately to prevent data loss.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: ElevatedButton.icon(
                    onPressed: widget.onExportColdStorage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Export Backup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafariRiskBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label:
          'Storage durability notice: Running in temporary browser mode. Add to Home Screen to ensure campaign data is never cleared by iOS.',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6.0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.primary,
                  size: 24.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Text(
                    'Running in temporary browser mode. Add to Home Screen to ensure campaign data is never cleared by iOS.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Dismiss storage warning',
                    onPressed: () {
                      setState(() {
                        _dismissed = true;
                      });
                      widget.onDismiss?.call();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accessible inline action rendered inside character and campaign management menus
/// to fulfill Firefox permission fences ("Lock Data Offline").
class StorageLockOfflineAction extends StatefulWidget {
  final StorageDurabilityCoordinator coordinator;
  final VoidCallback? onSuccess;

  const StorageLockOfflineAction({
    super.key,
    required this.coordinator,
    this.onSuccess,
  });

  @override
  State<StorageLockOfflineAction> createState() =>
      _StorageLockOfflineActionState();
}

class _StorageLockOfflineActionState extends State<StorageLockOfflineAction> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StorageTelemetryReport>(
      stream: widget.coordinator.telemetryStream,
      initialData: widget.coordinator.currentTelemetry,
      builder: (context, snapshot) {
        final report = snapshot.data;
        // Condition 2: Firefox Desktop pending gesture or unpersisted browser
        final requiresGesture = widget.coordinator.requiresContextualPrompt ||
            (report != null &&
                !report.isPersisted &&
                !report.profile.isStandalonePwa);

        if (!requiresGesture) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Semantics(
          button: true,
          label:
              'Lock Data Offline: Grant persistent storage to ensure campaign data is retained permanently without browser eviction.',
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      try {
                        final success = await widget.coordinator
                            .requestContextualPersistence();
                        if (success && mounted) {
                          widget.onSuccess?.call();
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isLoading = false);
                        }
                      }
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                side: BorderSide(color: colorScheme.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.offline_pin_rounded, size: 20),
              label: Text(
                'Lock Data Offline',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
