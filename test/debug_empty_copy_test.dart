// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dangerously_nerdy_5e_toolkit/services/ingestion/compendium_json_ingestion_pipeline.dart';

void main() {
  test('inspect empty copy monsters', () async {
    final file = File('/home/kevin/homebrew.json');
    if (!file.existsSync()) return;

    final jsonStr = await file.readAsString();
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final pipeline = CompendiumJsonIngestionPipeline();
    final result = pipeline.ingestJsonMap(jsonMap);

    int emptyCopy = 0;
    final emptyList = <String>[];
    for (final m in result.monsters) {
      if (m.customProperties.containsKey('_copy')) {
        if (!m.actionsMarkdown.contains('###')) {
          emptyCopy++;
          emptyList.add('${m.name} (_copy: ${m.customProperties["_copy"]})');
        }
      }
    }
    print('Monsters with _copy still missing actions sections: $emptyCopy (was 116)');
    for (final e in emptyList) {
      print('  $e');
    }
  });
}
