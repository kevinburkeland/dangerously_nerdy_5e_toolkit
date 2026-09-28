import '../../../../domain/ingestion/descriptors/ingestion_field_descriptor.dart';
import '../../../../domain/ingestion/descriptors/ingestion_target_descriptor.dart';
import '../../../../domain/ingestion/engine/field_extractor.dart';
import '../../../../domain/ingestion/models/field_state.dart';
import '../../../../domain/ingestion/models/ingestion_field.dart';
import '../../../../domain/ingestion/models/source_block.dart';
import '../../../../domain/ingestion/models/source_span.dart';

/// 5e-specific field extractor for Magic Items and Equipment.
class Dnd5eItemFieldExtractor implements FieldExtractor {
  const Dnd5eItemFieldExtractor();

  // Pattern: "Weapon (longsword), rare (requires attunement by a spellcaster)"
  // or "Wondrous Item, uncommon"
  static final _combinedSubtitlePattern = RegExp(
    r'^([^,]+),\s*(common|uncommon|rare|very\s+rare|legendary|artifact|varies)(?:\s*\((requires\s+attunement[^\)]*)\))?$',
    caseSensitive: false,
  );

  static final _bareCategoryPattern = RegExp(
    r'^(?:wondrous\s+item|weapon(?:\s*\([^\)]*\))?|armor(?:\s*\([^\)]*\))?|potion|ring|rod|staff|wand|scroll)$',
    caseSensitive: false,
  );

  static final _itemTypePattern = RegExp(
    r'^(?:item\s+type|type)\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _rarityPattern = RegExp(
    r'^rarity\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );
  static final _attunementPattern = RegExp(
    r'^attunement\s*[:]?\s*(.+)$',
    caseSensitive: false,
  );

  @override
  FieldExtractionResult extract({
    required List<SourceBlock> blocks,
    required IngestionTargetDescriptor descriptor,
    SourceSpan? span,
  }) {
    final fields = <String, IngestionField<dynamic>>{};
    final consumedBlockIds = <String>{};

    if (blocks.isEmpty) {
      _populateMissingFields(fields, descriptor);
      return FieldExtractionResult(fields: fields);
    }

    int blockIndex = 0;

    // 1. Name: First block
    final firstBlock = blocks[0];
    final titleText = firstBlock.headingText ?? firstBlock.normalizedText;
    if (titleText.isNotEmpty) {
      fields['name'] = IngestionField<String>.extracted(
        key: 'name',
        label: 'Name',
        value: titleText,
        rawText: firstBlock.rawText,
        span: firstBlock.span,
        isRequired: true,
      );
      consumedBlockIds.add(firstBlock.id);
      blockIndex++;
    }

    // 2. Subtitle or Line-by-line checks
    if (blockIndex < blocks.length) {
      final subBlock = blocks[blockIndex];
      final line = subBlock.normalizedText;

      final combinedMatch = _combinedSubtitlePattern.firstMatch(line);
      if (combinedMatch != null) {
        final type = combinedMatch.group(1)!.trim();
        final rarityRaw = combinedMatch.group(2)!.trim();
        final attunementStr = combinedMatch.group(3)?.trim();

        fields['itemType'] = IngestionField<String>.extracted(
          key: 'itemType',
          label: 'Item Type',
          value: type,
          rawText: type,
          span: subBlock.span,
          isRequired: true,
        );

        fields['rarity'] = IngestionField<String>.extracted(
          key: 'rarity',
          label: 'Rarity',
          value: _capitalizeWords(rarityRaw),
          rawText: rarityRaw,
          span: subBlock.span,
          isRequired: true,
        );

        final requiresAttunement = attunementStr != null && attunementStr.isNotEmpty;
        fields['requiresAttunement'] = IngestionField<bool>.extracted(
          key: 'requiresAttunement',
          label: 'Requires Attunement',
          value: requiresAttunement,
          rawText: attunementStr ?? 'false',
          span: subBlock.span,
          isRequired: false,
        );

        if (requiresAttunement) {
          fields['attunementDetails'] = IngestionField<String>.extracted(
            key: 'attunementDetails',
            label: 'Attunement Details',
            value: attunementStr,
            rawText: attunementStr,
            span: subBlock.span,
            isRequired: false,
          );
        }

        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      } else if (_bareCategoryPattern.hasMatch(line)) {
        fields['itemType'] = IngestionField<String>.extracted(
          key: 'itemType',
          label: 'Item Type',
          value: _capitalizeWords(line),
          rawText: line,
          span: subBlock.span,
          isRequired: true,
        );
        consumedBlockIds.add(subBlock.id);
        blockIndex++;
      }
    }

    // 3. Scan remaining blocks for discrete stat lines or description prose
    final descBlocks = <SourceBlock>[];
    for (int i = blockIndex; i < blocks.length; i++) {
      final block = blocks[i];
      final text = block.normalizedText;

      final typeMatch = _itemTypePattern.firstMatch(text);
      if (typeMatch != null && !fields.containsKey('itemType')) {
        final val = typeMatch.group(1)!.trim();
        fields['itemType'] = IngestionField<String>.extracted(
          key: 'itemType',
          label: 'Item Type',
          value: val,
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final rarityMatch = _rarityPattern.firstMatch(text);
      if (rarityMatch != null && !fields.containsKey('rarity')) {
        final val = rarityMatch.group(1)!.trim();
        fields['rarity'] = IngestionField<String>.extracted(
          key: 'rarity',
          label: 'Rarity',
          value: _capitalizeWords(val),
          rawText: block.rawText,
          span: block.span,
          isRequired: true,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      final attuneMatch = _attunementPattern.firstMatch(text);
      if (attuneMatch != null && !fields.containsKey('requiresAttunement')) {
        final val = attuneMatch.group(1)!.trim();
        final req = !val.toLowerCase().contains('no') && !val.toLowerCase().contains('false');
        fields['requiresAttunement'] = IngestionField<bool>.extracted(
          key: 'requiresAttunement',
          label: 'Requires Attunement',
          value: req,
          rawText: block.rawText,
          span: block.span,
          isRequired: false,
        );
        consumedBlockIds.add(block.id);
        continue;
      }

      descBlocks.add(block);
    }

    // 4. Description
    if (descBlocks.isNotEmpty) {
      final fullDesc = descBlocks.map((b) => b.rawText).join('\n\n');
      fields['descriptionMarkdown'] = IngestionField<String>.extracted(
        key: 'descriptionMarkdown',
        label: 'Description',
        value: fullDesc,
        rawText: fullDesc,
        span: SourceSpan(
          startOffset: descBlocks.first.span.startOffset,
          endOffset: descBlocks.last.span.endOffset,
          startLine: descBlocks.first.span.startLine,
          startColumn: descBlocks.first.span.startColumn,
          endLine: descBlocks.last.span.endLine,
          endColumn: descBlocks.last.span.endColumn,
          text: fullDesc,
        ),
        isRequired: true,
      );
      for (final b in descBlocks) {
        consumedBlockIds.add(b.id);
      }
    }

    _populateMissingFields(fields, descriptor);
    return FieldExtractionResult(fields: fields);
  }

  void _populateMissingFields(
    Map<String, IngestionField<dynamic>> fields,
    IngestionTargetDescriptor descriptor,
  ) {
    for (final fd in descriptor.fields) {
      if (!fields.containsKey(fd.key)) {
        fields[fd.key] = IngestionField<dynamic>(
          key: fd.key,
          label: fd.label,
          state: IngestionFieldState.missing,
          value: null,
          isRequired: fd.expectation == SourceFieldExpectation.requiredForRecognition,
        );
      }
    }
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
