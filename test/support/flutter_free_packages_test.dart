import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'flutter_free_packages.dart';

void main() {
  group('FlutterPackageDetector Fixture Graph Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pkg_graph_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void writePackage({
      required String name,
      required List<String> dependencies,
      bool isFlutterSdk = false,
    }) {
      final pkgDir = Directory('${tempDir.path}/$name');
      pkgDir.createSync(recursive: true);
      final depsYaml = dependencies.map((d) => '  $d: any').join('\n');
      final pubspecContent = '''
name: $name
version: 1.0.0
dependencies:
$depsYaml
''';
      File('${pkgDir.path}/pubspec.yaml').writeAsStringSync(pubspecContent);
    }

    test('transitive two-steps-away package is Flutter-bound and pure package is not', () {
      // Setup graph:
      // pkg_a -> pkg_b -> flutter (SDK package)
      // pkg_pure -> (no deps)
      writePackage(name: 'pkg_a', dependencies: ['pkg_b']);
      writePackage(name: 'pkg_b', dependencies: ['flutter']);
      writePackage(name: 'pkg_pure', dependencies: []);

      // Fake flutter package
      final flutterDir = Directory('${tempDir.path}/flutter');
      flutterDir.createSync(recursive: true);
      File('${flutterDir.path}/pubspec.yaml').writeAsStringSync('''
name: flutter
version: 0.0.0
dependencies: {}
''');

      final packageConfig = {
        'configVersion': 2,
        'packages': [
          {
            'name': 'pkg_a',
            'rootUri': '${tempDir.uri}pkg_a',
            'packageUri': 'lib/',
          },
          {
            'name': 'pkg_b',
            'rootUri': '${tempDir.uri}pkg_b',
            'packageUri': 'lib/',
          },
          {
            'name': 'pkg_pure',
            'rootUri': '${tempDir.uri}pkg_pure',
            'packageUri': 'lib/',
          },
          {
            'name': 'flutter',
            'rootUri': '${tempDir.uri}flutter',
            'packageUri': 'lib/',
          },
        ],
      };

      final configFile = File('${tempDir.path}/package_config.json');
      configFile.writeAsStringSync(jsonEncode(packageConfig));

      final detector = FlutterPackageDetector.fromPackageConfig(configFile.path);

      // Two steps away: pkg_a depends on pkg_b, pkg_b depends on flutter
      expect(
        detector.isFlutterBoundPackage('pkg_a'),
        isTrue,
        reason: 'pkg_a is two steps away from flutter and must be Flutter-bound',
      );
      expect(
        detector.isFlutterBoundPackage('pkg_b'),
        isTrue,
        reason: 'pkg_b directly depends on flutter and must be Flutter-bound',
      );
      expect(
        detector.isFlutterBoundPackage('flutter'),
        isTrue,
        reason: 'flutter SDK package is Flutter-bound',
      );
      expect(
        detector.isFlutterBoundPackage('pkg_pure'),
        isFalse,
        reason: 'pkg_pure has no flutter dependencies and must not be Flutter-bound',
      );

      // URI checks
      expect(detector.isFlutterBoundUri('package:pkg_a/pkg_a.dart'), isTrue);
      expect(detector.isFlutterBoundUri('package:pkg_pure/pkg_pure.dart'), isFalse);
      expect(detector.isFlutterBoundUri('dart:ui'), isTrue);
      expect(detector.isFlutterBoundUri('dart:ui_web'), isTrue);
      expect(detector.isFlutterBoundUri('dart:async'), isFalse);
    });

    test('missing pubspec throws FileSystemException (fail closed)', () {
      final packageConfig = {
        'configVersion': 2,
        'packages': [
          {
            'name': 'pkg_missing_pubspec',
            'rootUri': '${tempDir.uri}pkg_missing_pubspec',
            'packageUri': 'lib/',
          },
        ],
      };
      // Do not create pkg_missing_pubspec/pubspec.yaml
      final configFile = File('${tempDir.path}/package_config.json');
      configFile.writeAsStringSync(jsonEncode(packageConfig));

      expect(
        () => FlutterPackageDetector.fromPackageConfig(configFile.path),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('missing package_config.json throws FileSystemException (fail closed)', () {
      expect(
        () => FlutterPackageDetector.fromPackageConfig('${tempDir.path}/nonexistent_config.json'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('FlutterPackageDetector Real App Package Tests', () {
    test('12 named packages: 4 Flutter-bound, 8 pure', () {
      final detector = FlutterPackageDetector.instance;

      const flutterBoundPackages = [
        'material_ui',
        'cupertino_ui',
        'flutter_webrtc',
        'hive_flutter',
      ];

      const purePackages = [
        'meta',
        'collection',
        'crypto',
        'uuid',
        'fast_immutable_collections',
        'mutex',
        'vtt_engine_core',
        'vtt_ruleset_dnd5e',
      ];

      stdout.writeln('=== Helper Answers for Named Packages ===');
      for (final pkg in flutterBoundPackages) {
        final answer = detector.isFlutterBoundPackage(pkg);
        stdout.writeln('HELPER_ANSWER: $pkg = $answer');
        expect(answer, isTrue, reason: '$pkg must be Flutter-bound');
      }

      for (final pkg in purePackages) {
        final answer = detector.isFlutterBoundPackage(pkg);
        stdout.writeln('HELPER_ANSWER: $pkg = $answer');
        expect(answer, isFalse, reason: '$pkg must be pure (not Flutter-bound)');
      }
    });
  });
}
