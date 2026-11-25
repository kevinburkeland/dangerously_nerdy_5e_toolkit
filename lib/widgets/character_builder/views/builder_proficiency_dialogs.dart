import 'package:material_ui/material_ui.dart';
import '../../../models/characters/srd_proficiencies_library.dart';

void showBuilderAddLanguageDialog(
  BuildContext context, {
  required Set<String> allBuilderLanguages,
  required ValueChanged<String> onAddLanguage,
}) {
    final customController = TextEditingController();
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final existing =
              allBuilderLanguages.map((l) => l.toLowerCase()).toSet();
          final availableStandard = SrdProficienciesLibrary.standardLanguages
              .where((l) => !existing.contains(l.toLowerCase()))
              .where((l) => l.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();
          final availableExotic = SrdProficienciesLibrary.exoticLanguages
              .where((l) => !existing.contains(l.toLowerCase()))
              .where((l) => l.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('Add Language'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Search or Custom Language',
                        hintText: 'Enter language...',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) =>
                          setDialogState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    if (availableStandard.isNotEmpty) ...[
                      const Text('Standard Languages',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.cyanAccent)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableStandard.map((lang) {
                          return ActionChip(
                            label: Text(lang),
                            onPressed: () {
                              onAddLanguage(lang);
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (availableExotic.isNotEmpty) ...[
                      const Text('Exotic Languages',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.purpleAccent)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableExotic.map((lang) {
                          return ActionChip(
                            label: Text(lang),
                            onPressed: () {
                              onAddLanguage(lang);
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final custom = customController.text.trim();
                  if (custom.isNotEmpty) {
                    onAddLanguage(custom);
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Custom'),
              ),
            ],
          );
        },
      ),
    );
  }

void showBuilderAddToolDialog(
  BuildContext context, {
  required Set<String> allBuilderTools,
  required ValueChanged<String> onAddTool,
}) {
    final customController = TextEditingController();
    ToolCategory selectedCategory = ToolCategory.artisansTools;
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final existing = allBuilderTools.map((t) => t.toLowerCase()).toSet();
          final allCategoryTools = switch (selectedCategory) {
            ToolCategory.artisansTools => SrdProficienciesLibrary.artisansTools,
            ToolCategory.gamingSets => SrdProficienciesLibrary.gamingSets,
            ToolCategory.musicalInstruments =>
              SrdProficienciesLibrary.musicalInstruments,
            ToolCategory.kits => SrdProficienciesLibrary.kitsAndSpecialized,
            ToolCategory.vehicles => SrdProficienciesLibrary.vehicles,
          };
          final availableTools = allCategoryTools
              .where((t) => !existing.contains(t.toLowerCase()))
              .where((t) => t.toLowerCase().contains(searchQuery.toLowerCase()))
              .toList();

          return AlertDialog(
            title: const Text('Add Tool Proficiency'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: customController,
                      decoration: const InputDecoration(
                        labelText: 'Search or Custom Tool',
                        hintText: 'Search or enter custom tool name...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) =>
                          setDialogState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ToolCategory.values.map((cat) {
                          final isSel = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat.displayName,
                                  style: const TextStyle(fontSize: 11)),
                              selected: isSel,
                              onSelected: (_) =>
                                  setDialogState(() => selectedCategory = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (availableTools.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: availableTools.map((tool) {
                          return ActionChip(
                            label: Text(tool),
                            onPressed: () {
                              onAddTool(tool);
                              Navigator.of(ctx).pop();
                            },
                          );
                        }).toList(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No matching tools in this category.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.white54)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final custom = customController.text.trim();
                  if (custom.isNotEmpty) {
                    onAddTool(custom);
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Add Custom'),
              ),
            ],
          );
        },
      ),
    );
  }


