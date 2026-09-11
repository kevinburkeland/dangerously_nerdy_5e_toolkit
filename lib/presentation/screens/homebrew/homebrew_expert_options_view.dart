// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../application/services/homebrew_import_orchestrator.dart';
import '../../../domain/homebrew/models/homebrew_entity.dart';
import '../../../domain/homebrew/ports/i_github_ingestor_port.dart';
import '../../../domain/homebrew/value_objects/github_repo_source.dart';
import '../../../domain/homebrew/value_objects/ruleset_version.dart';
import '../../../infrastructure/adapters/remote/github_ingestor_adapter.dart';
import '../../../services/haptic_service.dart';
import '../../../services/persistence/homebrew_persistence_service.dart';

/// Isolated sub-view for Expert GitHub Homebrew Ingestion.
///
/// Mandates explicit ruleset pre-selection, single-ruleset repository confirmation,
/// and client-side licensing acknowledgement before ingestion.
class HomebrewExpertOptionsView extends StatefulWidget {
  final IGithubIngestorPort? customIngestorPort;
  final EntityPersister? customPersister;

  const HomebrewExpertOptionsView({
    super.key,
    this.customIngestorPort,
    this.customPersister,
  });

  @override
  State<HomebrewExpertOptionsView> createState() => _HomebrewExpertOptionsViewState();
}

class _HomebrewExpertOptionsViewState extends State<HomebrewExpertOptionsView> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  RulesetVersion? _selectedRuleset;
  bool _agreedToSingleRuleset = false;
  bool _isIngesting = false;
  String? _urlError;

  HomebrewImportTelemetry? _telemetry;
  StreamSubscription<HomebrewImportTelemetry>? _subscription;
  late final HomebrewImportOrchestrator _orchestrator;

  @override
  void initState() {
    super.initState();
    final port = widget.customIngestorPort ?? GithubIngestorAdapter();
    _orchestrator = HomebrewImportOrchestrator(
      ingestorPort: port,
      persister: widget.customPersister ?? _defaultPersister,
    );

    _urlController.addListener(_validateUrlLive);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _urlController.removeListener(_validateUrlLive);
    _urlController.dispose();
    super.dispose();
  }

  static Future<void> _defaultPersister(HomebrewEntity entity) async {
    // Persist to local persistence layer if applicable
    // Generic compendium entries can be retained through the persistence service
    final persistence = HomebrewPersistenceService();
    try {
      await persistence.saveCustomRawPayload(
        'dn_homebrew_github_${entity.ruleset.name}',
        entity.id,
        entity.rawPayload,
      );
    } catch (_) {
      // Non-fatal persistence logging
    }
  }

  void _validateUrlLive() {
    final text = _urlController.text.trim();
    if (text.isEmpty) {
      if (_urlError != null) setState(() => _urlError = null);
      return;
    }

    try {
      GithubRepoSource.parse(text);
      if (_urlError != null) {
        setState(() => _urlError = null);
      }
    } on FormatException catch (e) {
      setState(() => _urlError = e.message);
    }
  }

  bool get _canSubmit =>
      _selectedRuleset != null &&
      _agreedToSingleRuleset &&
      !_isIngesting &&
      _urlController.text.trim().isNotEmpty &&
      _urlError == null;

  Future<void> _startIngestion() async {
    if (!_canSubmit) return;

    HapticService.selectionTick(context);
    FocusScope.of(context).unfocus();

    final source = GithubRepoSource.parse(_urlController.text.trim());
    final ruleset = _selectedRuleset!;

    setState(() {
      _isIngesting = true;
      _telemetry = const HomebrewImportTelemetry();
    });

    _subscription?.cancel();
    final stream = _orchestrator.runImport(
      source: source,
      ruleset: ruleset,
    );

    _subscription = stream.listen(
      (telemetry) {
        if (mounted) {
          setState(() {
            _telemetry = telemetry;
            if (telemetry.isCompleted) {
              _isIngesting = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isIngesting = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ingestion failed: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isIngesting = false;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Options: GitHub Ingestor'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWarningBanner(colorScheme),
                    const SizedBox(height: 16),
                    _buildLegalDisclaimer(colorScheme),
                    const SizedBox(height: 24),
                    _buildRulesetSelector(colorScheme),
                    const SizedBox(height: 20),
                    _buildConfirmationCheckbox(colorScheme),
                    const SizedBox(height: 20),
                    _buildUrlInput(colorScheme),
                    const SizedBox(height: 24),
                    _buildSubmitButton(colorScheme),
                    if (_telemetry != null) ...[
                      const SizedBox(height: 28),
                      _buildTelemetryCard(colorScheme),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningBanner(ColorScheme colorScheme) {
    return Card(
      color: Colors.amber.shade900.withOpacity(0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade600, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Warning icon',
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber.shade400,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOMOGENEOUS SINGLE-RULESET MANDATE',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Target repository must contain homogeneous JSON definitions conforming to one chosen ruleset. '
                    'Heuristic ruleset auto-detection is strictly disabled. The Anti-Corruption Layer will reject '
                    'cross-ruleset definitions (e.g. 2024 Weapon Masteries under 2014 rules, or Species-bound ASIs under 2024 rules) '
                    'to protect your local CRDT ledger.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalDisclaimer(ColorScheme colorScheme) {
    return Card(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: 'Legal icon',
              child: Icon(
                Icons.gavel_rounded,
                color: colorScheme.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Client-Side Ingestion & Licensing Disclaimer',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ingestion operates solely client-side on your local device via GitHub public APIs. '
                    'You are solely responsible for ensuring you hold appropriate IP rights, OGL 1.0a, or CC-BY-4.0 SRD '
                    'licenses for content ingested into this toolkit.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesetSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'Target Ruleset (Mandatory Pre-Selection)',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              '* Required',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the specific ruleset version to enforce during ACL validation.',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 460) {
              return Column(
                children: [
                  _buildRulesetOptionTile(
                    version: RulesetVersion.srd2014,
                    title: '2014 SRD 5.1',
                    subtitle: 'Legacy rules (Race ASIs, Discrete Exhaustion)',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildRulesetOptionTile(
                    version: RulesetVersion.srd2024,
                    title: '2024 SRD 5.2',
                    subtitle: 'Revised rules (Background ASIs, Masteries)',
                    colorScheme: colorScheme,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: _buildRulesetOptionTile(
                    version: RulesetVersion.srd2014,
                    title: '2014 SRD 5.1',
                    subtitle: 'Legacy rules (Race ASIs, Discrete Exhaustion)',
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRulesetOptionTile(
                    version: RulesetVersion.srd2024,
                    title: '2024 SRD 5.2',
                    subtitle: 'Revised rules (Background ASIs, Masteries)',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRulesetOptionTile({
    required RulesetVersion version,
    required String title,
    required String subtitle,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedRuleset == version;

    return Semantics(
      label: 'Select $title',
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isIngesting
              ? null
              : () {
                  HapticService.selectionTick(context);
                  setState(() => _selectedRuleset = version);
                },
          child: Container(
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<RulesetVersion>(
                  value: version,
                  groupValue: _selectedRuleset,
                  onChanged: _isIngesting
                      ? null
                      : (val) {
                          if (val != null) {
                            HapticService.selectionTick(context);
                            setState(() => _selectedRuleset = val);
                          }
                        },
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationCheckbox(ColorScheme colorScheme) {
    return Semantics(
      label: 'Single ruleset confirmation checkbox',
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: CheckboxListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'I confirm that the target repository contains homogeneous single-ruleset definitions matching my selection.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          value: _agreedToSingleRuleset,
          onChanged: _isIngesting
              ? null
              : (val) {
                  HapticService.selectionTick(context);
                  setState(() => _agreedToSingleRuleset = val ?? false);
                },
        ),
      ),
    );
  }

  Widget _buildUrlInput(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GitHub Repository URL',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _urlController,
          enabled: !_isIngesting,
          decoration: InputDecoration(
            hintText: 'https://github.com/owner/repository',
            prefixIcon: const Icon(Icons.link_rounded),
            errorText: _urlError,
            helperText: 'Accepts github.com/owner/repo or github.com/owner/repo/tree/branch',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ColorScheme colorScheme) {
    return Semantics(
      label: 'Start Repository Ingestion Button',
      enabled: _canSubmit,
      button: true,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _canSubmit ? _startIngestion : null,
        icon: _isIngesting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.cloud_download_rounded),
        label: Text(
          _isIngesting
              ? 'Ingesting Repository Payloads...'
              : 'Start Explicit-Ruleset Ingestion',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(ColorScheme colorScheme) {
    final t = _telemetry!;

    return Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingestion Telemetry',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (t.isCompleted)
                  Chip(
                    avatar: const Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
                    label: const Text('Complete', style: TextStyle(fontSize: 12)),
                    backgroundColor: Colors.green.withOpacity(0.15),
                  )
                else
                  Chip(
                    avatar: const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: const Text('Streaming...', style: TextStyle(fontSize: 12)),
                    backgroundColor: colorScheme.primary.withOpacity(0.15),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: t.filesDiscovered > 0 ? t.progressRatio : null,
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge(
                  label: 'Discovered',
                  value: '${t.filesDiscovered}',
                  color: colorScheme.primary,
                ),
                _buildStatBadge(
                  label: 'Imported (CRDT)',
                  value: '${t.filesImported}',
                  color: Colors.greenAccent.shade400,
                ),
                _buildStatBadge(
                  label: 'Skipped / Non-Compliant',
                  value: '${t.filesSkipped}',
                  color: Colors.amberAccent.shade400,
                ),
              ],
            ),
            if (t.currentFileName != null && !t.isCompleted) ...[
              const SizedBox(height: 12),
              Text(
                'Current: ${t.currentFileName}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (t.errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              Text(
                'Rejection & Skip Log (${t.errors.length} items)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: t.errors.length,
                  itemBuilder: (ctx, i) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.cancel_outlined, size: 14, color: Colors.amber.shade400),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.errors[i],
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: colorScheme.onSurface.withOpacity(0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
