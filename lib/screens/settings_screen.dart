import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../screens/homebrew_studio_screen.dart';
import '../services/haptic_service.dart';
import '../services/persistence/app_backup_service.dart';
import '../widgets/dm_reference/rules_edition_toggle.dart';
import '../widgets/fx/critical_effect_overlay.dart';
import '../widgets/homebrew/homebrew_bulk_deleter_dialog.dart';
import '../widgets/homebrew/homebrew_export_dialog.dart';
import '../widgets/homebrew/homebrew_import_preview_dialog.dart';
import '../widgets/homebrew/homebrew_refresher_dialog.dart';
import '../widgets/interactive/pressable_card.dart';
import '../widgets/meters/animated_resource_meter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CriticalEffectController _testCritController = CriticalEffectController();
  int _previewHp = 22;
  final int _previewMaxHp = 80;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.of(context);
    final s = settingsProvider.settings;
    final theme = Theme.of(context);

    return CriticalEffectOverlay(
      controller: _testCritController,
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            header: true,
            child: const Text('Preferences & Visual Polish'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _buildSectionHeader(context, '5e Rules Edition & Mechanics', Icons.menu_book),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Global Rulebook Edition', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Applies across the DM Screen, Tactical Guides, Condition References, and Combat Action Economy.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    RulesEditionToggle(
                      currentEdition: s.rulesEdition,
                      onEditionChanged: (newEdition) {
                        settingsProvider.setRulesEdition(newEdition);
                      },
                      isExpanded: true,
                      showIcons: true,
                      showSubtext: true,
                    ),
                    const Divider(height: 24),
                    const Text('Character Creation Step Flow', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Determines the default guided sequence for building characters in the Character Wizard.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<WizardOrderingPreset>(
                      initialValue: s.wizardOrderingPreset,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: WizardOrderingPreset.values
                          .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                          .toList(),
                      onChanged: (p) {
                        if (p != null) {
                          HapticService.selectionTick(context);
                          settingsProvider.setWizardOrderingPreset(p);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(context, 'Theme & Appearance', Icons.palette_outlined),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode),
                          ),
                        ],
                        selected: {s.themeMode},
                        onSelectionChanged: (set) {
                          HapticService.selectionTick(context);
                          settingsProvider.setThemeMode(set.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Fantasy Accent Palette', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FantasyAccent.values.map((accent) {
                        final isSelected = s.fantasyAccent == accent;
                        return ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: accent.primary,
                            radius: 7,
                          ),
                          label: Text(accent.label),
                          selected: isSelected,
                          onSelected: (_) {
                            HapticService.selectionTick(context);
                            settingsProvider.setFantasyAccent(accent);
                          },
                        );
                      }).toList(),
                    ),
                    if (s.themeMode != ThemeMode.light) ...[
                      const Divider(height: 28),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('OLED Pitch Black'),
                        subtitle: const Text('Pure #000000 background for AMOLED battery savings'),
                        value: s.oledPitchBlack,
                        onChanged: (val) {
                          HapticService.selectionTick(context);
                          settingsProvider.setOledMode(val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(context, 'RPG Micro-Interactions & FX', Icons.auto_awesome),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.bolt, color: Colors.amber),
                    title: const Text('Critical Hit & Fumble Effects'),
                    subtitle: const Text('Screen shake, rumble, and ember bursts on Nat 20 / Nat 1'),
                    value: s.enableCritFumbleFx,
                    onChanged: s.performanceMode
                        ? null
                        : (val) {
                            HapticService.selectionTick(context);
                            settingsProvider.setCritFumbleFx(val);
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.grain, color: Colors.cyanAccent),
                    title: const Text('Spell Particle Canvas FX'),
                    subtitle: const Text('Floating ambient mana and spell burst particles'),
                    value: s.enableSpellParticles,
                    onChanged: s.performanceMode
                        ? null
                        : (val) {
                            HapticService.selectionTick(context);
                            settingsProvider.setSpellParticles(val);
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.casino_outlined, color: Colors.greenAccent),
                    title: const Text('3D / Animated Dice Overlays'),
                    subtitle: const Text('Interactive rolling physics and dice tumbling'),
                    value: s.enable3dDiceOverlays,
                    onChanged: s.performanceMode
                        ? null
                        : (val) {
                            HapticService.selectionTick(context);
                            settingsProvider.set3dDiceOverlays(val);
                          },
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.blur_on, color: Colors.purpleAccent),
                    title: const Text('Creature & Spell Glyph Animations'),
                    subtitle: const Text('Rotating trait rings and holographic techno-rune pulses'),
                    value: s.enableGlyphAnimations,
                    onChanged: s.performanceMode
                        ? null
                        : (val) {
                            HapticService.selectionTick(context);
                            settingsProvider.setGlyphAnimations(val);
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(context, 'Haptics & Battery Optimization', Icons.vibration),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.touch_app),
                    title: const Text('Tactile Haptic Feedback'),
                    subtitle: Text(s.hapticLevel.label),
                    trailing: DropdownButton<HapticFeedbackLevel>(
                      value: s.hapticLevel,
                      underline: const SizedBox(),
                      items: HapticFeedbackLevel.values.map((lvl) {
                        return DropdownMenuItem(
                          value: lvl,
                          child: Text(lvl.label),
                        );
                      }).toList(),
                      onChanged: (lvl) {
                        if (lvl != null) {
                          settingsProvider.setHapticLevel(lvl);
                          HapticService.heavyImpact(context);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    activeThumbColor: Colors.orangeAccent,
                    secondary: const Icon(Icons.battery_saver, color: Colors.orangeAccent),
                    title: const Text('Performance / Battery Saver Mode'),
                    subtitle: const Text('Disables continuous tickers, particles, and heavy shaders'),
                    value: s.performanceMode,
                    onChanged: (val) {
                      HapticService.selectionTick(context);
                      settingsProvider.setPerformanceMode(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionHeader(context, 'Interactive Live Preview & Test Lab', Icons.science_outlined),
            PressableCard(
              padding: const EdgeInsets.all(16),
              onTap: () {
                HapticService.selectionTick(context);
                setState(() {
                  _previewHp = (_previewHp >= _previewMaxHp) ? 18 : _previewHp + 20;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Interactive Pressable Card',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to alter HP',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedResourceMeter(
                    currentValue: _previewHp,
                    maxValue: _previewMaxHp,
                    label: 'Hit Points (Pulsing below 25%)',
                    fillColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          _testCritController.trigger(CritEffectType.critSuccess);
                        },
                        icon: const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 18),
                        label: const Text('Test Nat 20'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _testCritController.trigger(CritEffectType.critFumble);
                        },
                        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 18),
                        label: const Text('Test Nat 1'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          _testCritController.trigger(CritEffectType.spellBurst);
                        },
                        icon: const Icon(Icons.grain, color: Color(0xFF00E5FF), size: 18),
                        label: const Text('Test Spell FX'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Data Management & Backup', Icons.storage_rounded),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Archive & Storage Hygiene',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Export your character builds, custom presets, and pinned compendium entries as a JSON file, or restore a backup.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HomebrewStudioScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                          label: const Text('Homebrew Studio'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const HomebrewImportPreviewDialog(),
                          ),
                          icon: const Icon(Icons.download_for_offline_outlined, size: 18),
                          label: const Text('Import Homebrew Pack'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const HomebrewExportDialog(),
                          ),
                          icon: const Icon(Icons.upload_file_outlined, size: 18),
                          label: const Text('Export Homebrew Pack'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const HomebrewRefresherDialog(),
                          ),
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Refresh / Reparse JSON'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => const HomebrewBulkDeleterDialog(),
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                          label: const Text('Bulk Delete Homebrew'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _exportAppBackup,
                          icon: const Icon(Icons.file_download_outlined, size: 18),
                          label: const Text('Export Full Backup'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _importAppBackup,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: const Text('Import Full Backup'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _confirmResetSettings,
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Reset Settings'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _confirmClearAllData,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                          ),
                          icon: const Icon(Icons.delete_forever_outlined, size: 18),
                          label: const Text('Clear All Data'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAppBackup() async {
    HapticService.selectionTick(context);
    final settings = SettingsScope.of(context).settings;
    final jsonStr = await AppBackupService().exportFullBackupJson(settings);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text('Backup JSON Payload'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy your full app backup JSON payload to save it safely or transfer to another device:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Container(
                height: 160,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _importAppBackup() async {
    HapticService.selectionTick(context);
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_upload_outlined, color: Colors.cyan),
            SizedBox(width: 8),
            Text('Import Backup JSON'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your exported backup JSON payload below to restore presets and character builds:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '{\n  "schemaVersion": 2,\n  ...\n}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore Backup'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.trim().isNotEmpty && mounted) {
      final restoreResult = await AppBackupService().importFullBackupJson(controller.text);
      if (!mounted) return;
      if (restoreResult.success) {
        HapticService.mediumImpact(context);
        final homebrewCount = restoreResult.restoredHomebrewSpellsCount +
            restoreResult.restoredHomebrewMonstersCount +
            restoreResult.restoredHomebrewItemsCount;
        final homebrewSuffix = homebrewCount > 0 ? ', and $homebrewCount homebrew entities' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored ${restoreResult.restoredPresetsCount} presets, ${restoreResult.restoredDprProfilesCount} character builds$homebrewSuffix!',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text(restoreResult.errorMessage ?? 'Failed to import backup'),
          ),
        );
      }
    }
  }

  Future<void> _confirmResetSettings() async {
    HapticService.selectionTick(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings?'),
        content: const Text(
          'This will reset your theme, haptics, animations, and pinned items to default values.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final settingsProvider = SettingsScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await settingsProvider.updateSettings(const AppSettings());
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Settings reset to defaults')),
        );
      }
    }
  }

  Future<void> _confirmClearAllData() async {
    HapticService.selectionTick(context);
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Local Data?'),
        content: const Text(
          'WARNING: This will permanently delete all saved custom dice presets, character builds, active minion sessions, and reset settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final settingsProvider = SettingsScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await AppBackupService().clearAllAppData();
      await settingsProvider.updateSettings(const AppSettings());
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('All local data cleared successfully')),
        );
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
