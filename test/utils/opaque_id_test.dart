import 'dart:math' as math;

import 'package:dangerously_nerdy_5e_toolkit/domain/opaque_id.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _kUuidV4Re = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  group('Fix 5.3 opaque_id property test', () {
    test('control: clock milliseconds + nextInt(9999) collides in a tight loop', () {
      final rng = math.Random(20261127);
      final seen = <String>{};
      String? collision;
      for (var i = 0; i < 10000; i++) {
        final id =
            'evt_${DateTime.now().millisecondsSinceEpoch}_${rng.nextInt(9999)}';
        if (!seen.add(id)) {
          collision = id;
          break;
        }
      }
      expect(collision, isNotNull, reason: 'Expected collision in tight loop');
    });

    test('10,000 ids from newOpaqueId are all UUID v4 shaped and unique', () {
      final seen = <String>{};
      for (var i = 0; i < 10000; i++) {
        final id = newOpaqueId();
        expect(_kUuidV4Re.hasMatch(id), isTrue, reason: 'Not UUID v4: $id');
        expect(seen.add(id), isTrue, reason: 'Duplicate id: $id');
      }
    });

    test('prefixed ids keep prefix followed by UUID v4', () {
      final id = newOpaqueId('evt_');
      expect(id.startsWith('evt_'), isTrue);
      expect(_kUuidV4Re.hasMatch(id.substring('evt_'.length)), isTrue);
    });
  });
}
