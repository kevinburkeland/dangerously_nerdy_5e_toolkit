import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/domain/core_types.dart';
import '../../services/io/compendium_file_picker_service.dart';
import '../../services/persistence/homebrew_persistence_service.dart';
import '../dialogs/app_dialog_frame.dart';

/// Modal dialog allowing users to configure, select categories, and export their custom Homebrew
/// into a portable JSON HomebrewBundle.
class HomebrewExportDialog extends StatefulWidget {
  const HomebrewExportDialog({super.key});

  @override
  State<HomebrewExportDialog> createState() => _HomebrewExportDialogState();
}

class _HomebrewExportDialogState extends State<HomebrewExportDialog> {
  final _persistence = HomebrewPersistenceService();
  final _nameController = TextEditingController(text: 'My Homebrew Pack');
  final _authorController = TextEditingController();
  final _descController = TextEditingController();

  final Set<EntityType> _selectedCategories = {
    EntityType.spell,
    EntityType.monster,
    EntityType.equipment,
    EntityType.classDefinition,
    EntityType.subclass,
    EntityType.species,
    EntityType.feat,
    EntityType.background,
    EntityType.custom,
  };

  Map<EntityType, int> _categoryCounts = {};
  bool _isLoading = true;
  bool _isExporting = false;
  String? _exportedJson;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    final spells = await _persistence.loadCustomSpells();
    final monsters = await _persistence.loadCustomMonsters();
    final items = await _persistence.loadCustomItems();
    final classes = await _persistence.loadCustomClasses();
    final subclasses = await _persistence.loadCustomSubclasses();
    final races = await _persistence.loadCustomRaces();
    final feats = await _persistence.loadCustomFeats();
    final backgrounds = await _persistence.loadCustomBackgrounds();
    final others = await _persistence.loadCustomOtherEntries();

    if (mounted) {
      setState(() {
        _categoryCounts = {
          EntityType.spell: spells.length,
          EntityType.monster: monsters.length,
          EntityType.equipment: items.length,
          EntityType.classDefinition: classes.length,
          EntityType.subclass: subclasses.length,
          EntityType.species: races.length,
          EntityType.feat: feats.length,
          EntityType.background: backgrounds.length,
          EntityType.custom: others.length,
        };
        _isLoading = false;
      });
    }
  }

  Future<void> _generateExport() async {
    setState(() => _isExporting = true);

    try {
      final bundle = await _persistence.exportHomebrewBundle(
        bundleName: _nameController.text.trim(),
        author: _authorController.text.trim().isNotEmpty ? _authorController.text.trim() : null,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        categories: _selectedCategories,
      );

      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle.toMap());

      if (mounted) {
        setState(() {
          _exportedJson = jsonStr;
          _isExporting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate bundle: $e')),
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_exportedJson == null) return;
    Clipboard.setData(ClipboardData(text: _exportedJson!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Homebrew Bundle JSON copied to clipboard!')),
    );
  }

  Future<void> _saveToFile() async {
    final json = _exportedJson;
    if (json == null) return;
    final fileName = CompendiumFilePickerService.toSafeFileName(_nameController.text.trim());
    final savedUri = await CompendiumFilePickerService.saveCompendiumJsonFile(
      fileName: fileName,
      content: json,
      dialogTitle: 'Save Homebrew Bundle',
    );
    if (savedUri != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${savedUri.toFilePath()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppDialogFrame(
      icon: Icons.file_upload_outlined,
      iconColor: Colors.amberAccent,
      title: _exportedJson == null ? 'Export Homebrew Pack' : 'Bundle Generated',
      maxWidth: 620,
      content: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
          : _exportedJson == null
              ? _buildConfigView(theme)
              : _buildResultView(theme),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_exportedJson == null)
          ElevatedButton.icon(
            onPressed: _selectedCategories.isNotEmpty && !_isExporting ? _generateExport : null,
            icon: _isExporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.download),
            label: const Text('Generate Bundle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
          )
        else ...[
          TextButton.icon(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy JSON'),
          ),
          ElevatedButton.icon(
            onPressed: _saveToFile,
            icon: const Icon(Icons.save_alt),
            label: const Text('Save to File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Bundle Name',
              hintText: 'e.g. Grim Hollow Spells & Subclasses',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorController,
            decoration: const InputDecoration(
              labelText: 'Author / Creator (Optional)',
              hintText: 'e.g. Dungeon Master Kevin',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Include Categories:',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedCategories.length == _categoryCounts.length) {
                      _selectedCategories.clear();
                    } else {
                      _selectedCategories.addAll(_categoryCounts.keys);
                    }
                  });
                },
                child: Text(
                  _selectedCategories.length == _categoryCounts.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCategoryCheckbox(EntityType.spell, 'Spells', Icons.auto_awesome),
          _buildCategoryCheckbox(EntityType.monster, 'Monsters & NPCs', Icons.pest_control),
          _buildCategoryCheckbox(EntityType.equipment, 'Equipment & Magic Items', Icons.shield),
          _buildCategoryCheckbox(EntityType.classDefinition, 'Classes', Icons.school),
          _buildCategoryCheckbox(EntityType.subclass, 'Subclasses', Icons.alt_route),
          _buildCategoryCheckbox(EntityType.species, 'Races & Species', Icons.people),
          _buildCategoryCheckbox(EntityType.feat, 'Feats', Icons.military_tech),
          _buildCategoryCheckbox(EntityType.background, 'Backgrounds', Icons.history_edu),
          _buildCategoryCheckbox(EntityType.custom, 'Rules & Tables', Icons.table_chart),
        ],
      ),
    );
  }

  Widget _buildCategoryCheckbox(EntityType type, String label, IconData icon) {
    final count = _categoryCounts[type] ?? 0;
    final isSelected = _selectedCategories.contains(type);

    return CheckboxListTile(
      value: isSelected,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            _selectedCategories.add(type);
          } else {
            _selectedCategories.remove(type);
          }
        });
      },
      secondary: Icon(icon, size: 20, color: isSelected ? Colors.amberAccent : Colors.grey),
      title: Text('$label ($count)'),
      activeColor: Colors.amberAccent,
      checkColor: Colors.black,
      dense: true,
    );
  }

  Widget _buildResultView(ThemeData theme) {
    final json = _exportedJson ?? '';
    final fileSizeBytes = utf8.encode(json).length;
    final fileSize = CompendiumFilePickerService.formatBytes(fileSizeBytes);
    final fileName = CompendiumFilePickerService.toSafeFileName(_nameController.text.trim());

    // Count total entities for summary
    final totalEntities = _selectedCategories.fold<int>(
      0,
      (sum, type) => sum + (_categoryCounts[type] ?? 0),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Success banner ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$totalEntities entities bundled into $fileName',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Stats row ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatChip(Icons.data_object, 'File Size', fileSize),
            const SizedBox(width: 12),
            _buildStatChip(Icons.format_list_numbered, 'Entities', '$totalEntities'),
          ],
        ),
        const SizedBox(height: 12),
        // ── Preview snippet ──────────────────────────────────────────────
        Container(
          height: 160,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: Text(
              json.length > 1200 ? '${json.substring(0, 1200)}\n…  (${json.length} chars total)' : json,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.amberAccent),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
