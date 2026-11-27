import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Text that marks the start of each individual error record dumped by
/// Flutter's `FlutterError.dumpErrorToConsole`.
const String kFlutterErrorRecordHeader = '══╡ EXCEPTION CAUGHT BY ';

/// Captures printed Flutter error dumps during a widget test via a child
/// `ZoneSpecification(print: ...)` (so even when `TestWidgetsFlutterBinding`
/// resets `debugPrint = debugPrintOverride` on a multi-exception batch, every
/// dumped error record is still captured without overriding
/// `FlutterError.onError`).
class CharacterizationErrorCapture {
  final StringBuffer _buffer = StringBuffer();

  /// Runs [body] inside a child zone that tees `print` output into this
  /// capture buffer while preserving normal console output.
  Future<T> run<T>(Future<T> Function() body) {
    final prevDebugPrint = debugPrint;
    return runZoned(
      () async {
        try {
          return await body();
        } finally {
          debugPrint = prevDebugPrint;
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          _buffer.writeln(line);
          parent.print(zone, line);
        },
      ),
    );
  }

  /// Splits captured output into individual error records and clears the buffer.
  List<String> drainRecords() {
    final text = _buffer.toString();
    _buffer.clear();
    if (text.trim().isEmpty) return const [];
    final parts = text.split(kFlutterErrorRecordHeader);
    final records = <String>[];
    for (var i = 1; i < parts.length; i++) {
      final rec = '$kFlutterErrorRecordHeader${parts[i]}'.trimRight();
      if (rec.isNotEmpty) {
        records.add(rec);
      }
    }
    return records;
  }
}

final RegExp _kMultipleExceptionsRe =
    RegExp(r'Multiple exceptions \(\d+\) were detected');

bool _isRenderFlexOverflowText(String text) {
  return text.contains('RenderFlex overflowed');
}

/// Verifies no unexpected exceptions occurred during a characterization test.
///
/// When [capture] is null (Choice 1), **any** exception from
/// `tester.takeException()` fails the test.
///
/// When [capture] is provided (Choice 2, for screens with known RenderFlex
/// overflows at constrained dimensions), every captured error record is
/// inspected individually: any record other than a `RenderFlex` overflow fails
/// and prints that error, and any `Multiple exceptions` rollup with zero
/// captured records fails closed.
void expectNoCharacterizationErrors(
  WidgetTester tester, {
  CharacterizationErrorCapture? capture,
  String? reason,
}) {
  final taken = <Object>[];
  for (Object? ex = tester.takeException();
      ex != null;
      ex = tester.takeException()) {
    taken.add(ex);
  }

  if (capture == null) {
    expect(
      taken,
      isEmpty,
      reason: reason ??
          'Expected zero exceptions, got:\n${taken.map((e) => e.toString()).join('\n---\n')}',
    );
    return;
  }

  final records = capture.drainRecords();
  final nonOverflowRecords =
      records.where((r) => !_isRenderFlexOverflowText(r)).toList();
  if (nonOverflowRecords.isNotEmpty) {
    fail(
      '${reason != null ? '$reason: ' : ''}'
      'Unexpected non-overflow error(s) in characterization test:\n'
      '${nonOverflowRecords.join('\n\n')}',
    );
  }

  for (final ex in taken) {
    final msg = ex.toString();
    if (_isRenderFlexOverflowText(msg)) continue;
    if (_kMultipleExceptionsRe.hasMatch(msg)) {
      if (records.isEmpty) {
        fail(
          '${reason != null ? '$reason: ' : ''}'
          'Encountered batched exceptions without captured individual error records: $msg',
        );
      }
      continue;
    }
    fail(
      '${reason != null ? '$reason: ' : ''}'
      'Unexpected non-overflow exception: $msg',
    );
  }
}
