import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/dm_screen_data.dart';
import '../providers/settings_provider.dart';
import '../services/haptic_service.dart';
import '../widgets/fx/critical_effect_overlay.dart';
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
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<DmRulesEdition>(
                        segments: const [
                          ButtonSegment(
                            value: DmRulesEdition.v2024,
                            label: Text('2024 Revised'),
                            icon: Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment(
                            value: DmRulesEdition.v2014,
                            label: Text('2014 5e RAW'),
                            icon: Icon(Icons.history_edu),
                          ),
                        ],
                        selected: {s.rulesEdition},
                        onSelectionChanged: (set) {
                          HapticService.selectionTick(context);
                          settingsProvider.setRulesEdition(set.first);
                        },
                      ),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _testCritController.trigger(CritEffectType.critSuccess);
                          },
                          icon: const Icon(Icons.auto_awesome, color: Color(0xFFFFD54F), size: 18),
                          label: const Text('Test Nat 20'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _testCritController.trigger(CritEffectType.critFumble);
                          },
                          icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 18),
                          label: const Text('Test Nat 1'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
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
