import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'characterization_error_guard.dart';

Widget _overflowWidget(String label) {
  return SizedBox(
    width: 40,
    child: Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
      ],
    ),
  );
}

class _ThrowingBuildWidget extends StatelessWidget {
  final String message;
  const _ThrowingBuildWidget(this.message);

  @override
  Widget build(BuildContext context) {
    throw StateError(message);
  }
}

void main() {
  group('Fix 1.2 controls: characterization error guard', () {
    testWidgets(
      'mixed frame with one RenderFlex overflow and one StateError fails printing the StateError',
      (tester) async {
        final capture = CharacterizationErrorCapture();
        await capture.run(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  _overflowWidget('Overflowing label'),
                  const _ThrowingBuildWidget('boom-mixed-frame-state-error'),
                ],
              ),
            ),
          );

          Object? caughtFailure;
          try {
            expectNoCharacterizationErrors(tester, capture: capture);
          } on TestFailure catch (f) {
            caughtFailure = f;
          }
          expect(caughtFailure, isA<TestFailure>());
          expect(
            caughtFailure.toString(),
            contains('boom-mixed-frame-state-error'),
          );
        });
      },
    );

    testWidgets(
      'single StateError fails under both Choice 1 and Choice 2',
      (tester) async {
        // Choice 2
        final capture = CharacterizationErrorCapture();
        await capture.run(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: _ThrowingBuildWidget('boom-single-choice2'),
            ),
          );
          Object? caught2;
          try {
            expectNoCharacterizationErrors(tester, capture: capture);
          } on TestFailure catch (f) {
            caught2 = f;
          }
          expect(caught2, isA<TestFailure>());
          expect(caught2.toString(), contains('boom-single-choice2'));
        });

        // Choice 1 (no capture -> any exception fails)
        await tester.pumpWidget(
          const MaterialApp(
            home: _ThrowingBuildWidget('boom-single-choice1'),
          ),
        );
        Object? caught1;
        try {
          expectNoCharacterizationErrors(tester);
        } on TestFailure catch (f) {
          caught1 = f;
        }
        expect(caught1, isA<TestFailure>());
        expect(caught1.toString(), contains('boom-single-choice1'));
      },
    );

    testWidgets(
      'Choice 2 allows a single RenderFlex overflow and a batch of two RenderFlex overflows',
      (tester) async {
        final capture = CharacterizationErrorCapture();
        await capture.run(() async {
          // Single overflow
          await tester.pumpWidget(
            MaterialApp(
              home: _overflowWidget('Single overflow'),
            ),
          );
          expectNoCharacterizationErrors(tester, capture: capture);

          // Batch of two overflows in one frame
          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  _overflowWidget('Overflow one'),
                  _overflowWidget('Overflow two'),
                ],
              ),
            ),
          );
          expectNoCharacterizationErrors(tester, capture: capture);
        });
      },
    );
  });
}
