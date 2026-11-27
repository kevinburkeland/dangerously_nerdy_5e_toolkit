import '../../../models/dm_screen_data.dart';
import '../../../models/domain/homebrew_extended_entities.dart';
import '../../../models/domain/homebrew_other_category.dart';
import '../../../models/tables/rollable_table.dart';
import '../../ingestion/compendium_json_ingestion_pipeline.dart';

/// Pure mappers converting [HomebrewCompendiumEntry] into [RollableTable] and
/// [DmReferenceItem] instances for runtime registries.
class HomebrewCompendiumMappers {
  HomebrewCompendiumMappers._();

  /// Converts a generic [HomebrewCompendiumEntry] to a rollable [RollableTable].
  static RollableTable compendiumEntryToRollableTable(
      HomebrewCompendiumEntry entry) {
    final raw = entry.customProperties;
    final entries = <TableEntry>[];

    String cleanTableLabel(String text) {
      return CompendiumJsonIngestionPipeline.cleanRawTags(text)
          .replaceAllMapped(
              RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '')
          .replaceAll(RegExp(r'\*\*|`'), '')
          .trim();
    }

    final rawRows = raw['rows'] is List ? (raw['rows'] as List) : null;
    final colLabels =
        raw['colLabels'] is List ? (raw['colLabels'] as List) : null;

    String? inferredDice;
    if (colLabels != null && colLabels.isNotEmpty) {
      final expr = DiceExpression.tryParse(colLabels.first.toString().trim()) ??
          DiceExpression.findAll(colLabels.first.toString())
              .firstOrNull
              ?.expression;
      if (expr != null && expr.hasDice) inferredDice = expr.format();
    }

    if (rawRows != null && rawRows.isNotEmpty) {
      int currentRollIndex = 1;
      for (final r in rawRows) {
        if (r is List && r.isNotEmpty) {
          final rangeCol = r[0];
          int min = currentRollIndex;
          int max = currentRollIndex;
          String label = '';

          if (rangeCol is List && rangeCol.isNotEmpty) {
            min = int.tryParse(rangeCol[0].toString()) ?? currentRollIndex;
            max = rangeCol.length > 1
                ? (int.tryParse(rangeCol[1].toString()) ?? min)
                : min;
            label =
                r.length > 1 ? r.sublist(1).join(' - ') : rangeCol.join(' - ');
          } else if (rangeCol is int) {
            min = max = rangeCol;
            label = r.length > 1 ? r.sublist(1).join(' - ') : '$rangeCol';
          } else if (rangeCol is String) {
            final trimmed = rangeCol.trim();
            final match = RegExp(r'^(\d+)(?:[-–—](\d+))?$').firstMatch(trimmed);
            if (match != null) {
              min = int.tryParse(match.group(1)!) ?? currentRollIndex;
              max = match.group(2) != null
                  ? (int.tryParse(match.group(2)!) ?? min)
                  : min;
              label = r.length > 1 ? r.sublist(1).join(' - ') : trimmed;
            } else {
              label = r.join(' - ');
            }
          } else {
            label = r.join(' - ');
          }

          entries.add(TableEntry(
            minRoll: min,
            maxRoll: max,
            label: cleanTableLabel(label),
          ));
          currentRollIndex = max + 1;
        } else if (r != null) {
          entries.add(TableEntry(
            minRoll: currentRollIndex,
            maxRoll: currentRollIndex,
            label: cleanTableLabel(r.toString()),
          ));
          currentRollIndex++;
        }
      }
    }

    // Fallback: parse markdown table rows from descriptionMarkdown if entries is empty
    if (entries.isEmpty && entry.descriptionMarkdown.isNotEmpty) {
      final lines = entry.descriptionMarkdown.split('\n');
      int rowIdx = 1;
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) continue;
        final cells = trimmed
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
        if (cells.isEmpty) continue;
        if (cells.any((c) => c.contains('---'))) continue;
        final expr = DiceExpression.tryParse(cells[0].trim()) ??
            DiceExpression.findAll(cells[0]).firstOrNull?.expression;
        if (rowIdx == 1 &&
            (cells[0].toLowerCase().contains('roll') ||
                (expr != null && expr.hasDice))) {
          if (inferredDice == null && expr != null && expr.hasDice) {
            inferredDice = expr.format();
          }
          continue;
        }

        final firstCell = cells[0];
        final match = RegExp(r'^(\d+)(?:[-–—](\d+))?$').firstMatch(firstCell);
        if (match != null) {
          final min = int.tryParse(match.group(1)!) ?? rowIdx;
          final max = match.group(2) != null
              ? (int.tryParse(match.group(2)!) ?? min)
              : min;
          final label =
              cells.length > 1 ? cells.sublist(1).join(' - ') : firstCell;
          entries.add(TableEntry(
              minRoll: min, maxRoll: max, label: cleanTableLabel(label)));
          rowIdx = max + 1;
        } else {
          entries.add(TableEntry(
              minRoll: rowIdx,
              maxRoll: rowIdx,
              label: cleanTableLabel(cells.join(' - '))));
          rowIdx++;
        }
      }
    }

    if (entries.isEmpty) {
      entries.add(TableEntry(
        minRoll: 1,
        maxRoll: 1,
        label: cleanTableLabel(entry.name),
        description: entry.descriptionMarkdown.isNotEmpty
            ? CompendiumJsonIngestionPipeline.cleanRawTags(
                entry.descriptionMarkdown)
            : null,
      ));
    }

    int maxRoll = 1;
    for (final e in entries) {
      if (e.maxRoll > maxRoll) maxRoll = e.maxRoll;
    }
    int sides = maxRoll;
    if (inferredDice != null) {
      final expr = DiceExpression.tryParse(inferredDice.trim()) ??
          DiceExpression.findAll(inferredDice).firstOrNull?.expression;
      if (expr != null && expr.largestDie > 0) sides = expr.largestDie;
    }
    if (sides < 1) sides = 1;
    final formula = inferredDice ?? '1d$sides';

    return RollableTable(
      id: entry.id.slug,
      name: CompendiumJsonIngestionPipeline.cleanRawTags(entry.name),
      category: TableCategory.custom,
      diceFormula: formula,
      diceSides: sides,
      diceCount: 1,
      description: entry.descriptionMarkdown.isNotEmpty
          ? CompendiumJsonIngestionPipeline.cleanRawTags(
              entry.descriptionMarkdown)
          : 'Homebrew rollable table.',
      entries: entries,
    );
  }

  /// Converts a generic [HomebrewCompendiumEntry] to a [DmReferenceItem].
  static DmReferenceItem compendiumEntryToDmReferenceItem(
      HomebrewCompendiumEntry entry) {
    final cat = HomebrewOtherCategory.classify(
      category: entry.category,
      name: entry.name,
      customProperties: entry.customProperties,
    );

    DmCategory dmCat;
    String subCategory;

    switch (cat) {
      case HomebrewOtherCategory.trapsAndHazards:
        dmCat = DmCategory.environment;
        subCategory =
            entry.category.toLowerCase().contains('trap') ? 'Traps' : 'Hazards';
      case HomebrewOtherCategory.conditionsAndDiseases:
        dmCat = DmCategory.conditions;
        subCategory = entry.category.toLowerCase().contains('disease')
            ? 'Diseases'
            : 'Conditions';
      case HomebrewOtherCategory.deities:
        dmCat = DmCategory.exploration;
        subCategory = 'Pantheon & Deities';
      case HomebrewOtherCategory.vehicles:
        dmCat = DmCategory.exploration;
        subCategory = 'Vehicles & Travel';
      case HomebrewOtherCategory.charmsAndRewards:
        dmCat = DmCategory.magicAndResting;
        subCategory = 'Charms & Rewards';
      case HomebrewOtherCategory.characterOptions:
      case HomebrewOtherCategory.invocationsAndPacts:
      case HomebrewOtherCategory.infusions:
        dmCat = DmCategory.actions;
        subCategory = entry.category;
      case HomebrewOtherCategory.tables:
        dmCat = DmCategory.tables;
        subCategory = 'Rollable Tables';
      case HomebrewOtherCategory.dataTables:
        dmCat = DmCategory.tables;
        subCategory = 'Data & Reference Tables';
      case HomebrewOtherCategory.rulesAndReference:
        final catLower = entry.category.toLowerCase();
        if (catLower.contains('action') || catLower.contains('combat')) {
          dmCat = DmCategory.actions;
          subCategory = 'Combat Actions';
        } else {
          dmCat = DmCategory.exploration;
          subCategory = 'Rules & Variants';
        }
    }

    final rawLines =
        CompendiumJsonIngestionPipeline.cleanRawTags(entry.descriptionMarkdown)
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();

    String summary;
    if (cat == HomebrewOtherCategory.tables ||
        cat == HomebrewOtherCategory.dataTables) {
      final caption = entry.customProperties['caption']?.toString();
      final rowCount = entry.customProperties['rows'] is List
          ? (entry.customProperties['rows'] as List).length
          : 0;
      if (caption != null && caption.isNotEmpty) {
        summary = CompendiumJsonIngestionPipeline.cleanRawTags(caption);
      } else {
        final nonTableLines =
            rawLines.where((l) => !l.startsWith('|')).toList();
        if (nonTableLines.isNotEmpty) {
          summary = nonTableLines.first;
        } else if (cat == HomebrewOtherCategory.tables) {
          summary = rowCount > 0
              ? 'Rollable dice table with $rowCount outcomes.'
              : 'Rollable random table.';
        } else {
          summary = rowCount > 0
              ? 'Data and reference table with $rowCount rows.'
              : 'Reference data table.';
        }
      }
    } else {
      summary = rawLines.isNotEmpty ? rawLines.first : entry.name;
    }

    final rules = rawLines.isNotEmpty ? rawLines : [entry.name];
    final isRollableTable = cat == HomebrewOtherCategory.tables;

    return DmReferenceItem(
      id: entry.id.slug,
      title: CompendiumJsonIngestionPipeline.cleanRawTags(entry.name),
      category: dmCat,
      subCategory: subCategory,
      summary: summary,
      rules2014: rules,
      rules2024: rules,
      tags: ['Homebrew', entry.category, subCategory],
      isChangedIn2024: false,
      linkedTableQuery: isRollableTable ? entry.name : null,
      linkedTableLabel: isRollableTable ? 'Roll on Table' : null,
      extraData: entry.customProperties,
    );
  }
}
