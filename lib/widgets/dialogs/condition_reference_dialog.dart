import 'package:flutter/material.dart';
import '../../models/dm_screen_data.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../dm_reference/rules_edition_toggle.dart';
import '../glyphs/dnd_glyph.dart';
import '../glyphs/glyph_tokens.dart';

class ConditionReferenceDialog extends StatefulWidget {
  final DmRulesEdition? initialEdition;

  const ConditionReferenceDialog({super.key, this.initialEdition});

  static void show(BuildContext context, {DmRulesEdition? edition}) {
    showDialog(
      context: context,
      builder: (ctx) => ConditionReferenceDialog(initialEdition: edition),
    );
  }

  @override
  State<ConditionReferenceDialog> createState() => _ConditionReferenceDialogState();
}

class _ConditionReferenceDialogState extends State<ConditionReferenceDialog> {
  DmRulesEdition? _localEditionOverride;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  Widget _buildConditionIcon(DmReferenceItem item, Color itemColor, bool isDark) {
    final title = item.title.toLowerCase();
    GenericUiGlyphType? uiType;
    if (title.contains('concentration')) {
      uiType = GenericUiGlyphType.concentrating;
    } else if (title.contains('unconscious') ||
        title.contains('incapacitated') ||
        title.contains('death')) {
      uiType = GenericUiGlyphType.deathSave;
    } else if (title.contains('invisible')) {
      uiType = GenericUiGlyphType.advantage;
    } else if (title.contains('blind') ||
        title.contains('prone') ||
        title.contains('disadvantage')) {
      uiType = GenericUiGlyphType.disadvantage;
    }

    if (uiType != null) {
      return RepaintBoundary(
        child: SizedBox(
          width: 22,
          height: 22,
          child: FittedBox(
            fit: BoxFit.contain,
            child: DndGlyph.genericUi(
              uiType: uiType,
              size: 22,
              isDarkMode: isDark,
              glyphColor: itemColor,
            ),
          ),
        ),
      );
    }

    return Icon(item.icon, color: itemColor, size: 20);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialEdition != null) {
      _localEditionOverride = widget.initialEdition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = SettingsScope.maybeOf(context);
    final edition = _localEditionOverride ?? settingsProvider?.settings.rulesEdition ?? DmRulesEdition.v2024;

    final filtered = DmScreenLibrary.conditions.where((c) {
      if (_selectedCategory != 'All' && c.subCategory != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return c.matches(_searchQuery);
    }).toList();

    final theme = Theme.of(context);
    final tabletop = theme.extension<TabletopColors>();
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 750),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.medical_information_outlined, color: primary, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        '5e Status Effects & Conditions',
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: RulesEditionToggle(
                      currentEdition: edition,
                      isDense: true,
                      onEditionChanged: (newEdition) {
                        setState(() => _localEditionOverride = newEdition);
                        settingsProvider?.setRulesEdition(newEdition);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    tooltip: 'Close dialog',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search conditions (e.g., Blinded, Prone, Invisible, Exhaustion)...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: primary, size: 18),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF252236) : theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              ),
            ),

            // Category Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DmScreenLibrary.conditionCategories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: primary,
                        backgroundColor: isDark ? const Color(0xFF252236) : theme.colorScheme.surfaceContainerHighest,
                        checkmarkColor: theme.colorScheme.onPrimary,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

            // List of Conditions
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching conditions found.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final itemColor = item.getLegibleColor(isDark);
                        final bulletPoints = item.getRules(edition);
                        return Card(
                          color: tabletop?.cardBackground ?? (isDark ? const Color(0xFF252236) : theme.colorScheme.surfaceContainerHighest),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: itemColor.withValues(alpha: 0.35)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: _buildConditionIcon(item, itemColor, isDark),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: itemColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (item.subCategory != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.subCategory!,
                                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...bulletPoints.map(
                                  (pt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(color: itemColor, fontWeight: FontWeight.bold),
                                        ),
                                        Expanded(
                                          child: Text(
                                            pt,
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
