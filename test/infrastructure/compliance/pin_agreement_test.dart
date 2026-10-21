import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

List<String> checkPinAgreement({
  required String appPubspecYaml,
  required String appPubspecLock,
  required String rulesetPubspecYaml,
}) {
  final problems = <String>[];

  final appPubspec = loadYaml(appPubspecYaml);
  final appLock = loadYaml(appPubspecLock);
  final rulesetPubspec = loadYaml(rulesetPubspecYaml);

  if (appPubspec is! YamlMap) {
    return ['app pubspec.yaml is not a valid YAML mapping'];
  }
  if (appLock is! YamlMap) {
    return ['app pubspec.lock is not a valid YAML mapping'];
  }
  if (rulesetPubspec is! YamlMap) {
    return ['ruleset pubspec.yaml is not a valid YAML mapping'];
  }

  const monitoredPackages = ['vtt_engine_core', 'vtt_ruleset_dnd5e'];
  final hexRegex = RegExp(r'^[0-9a-f]{40}$');
  final hexRegexAnyCase = RegExp(r'^[0-9a-fA-F]{40}$');
  final upperRegex = RegExp(r'[A-F]');

  // 1. Check dependency_overrides in app pubspec
  if (appPubspec.containsKey('dependency_overrides')) {
    final overrides = appPubspec['dependency_overrides'];
    if (overrides is YamlMap) {
      for (final pkg in monitoredPackages) {
        if (overrides.containsKey(pkg)) {
          problems.add('dependency_overrides in app pubspec.yaml contains $pkg');
        }
      }
    }
  }

  // 2. Check dependency_overrides in ruleset pubspec
  if (rulesetPubspec.containsKey('dependency_overrides')) {
    final overrides = rulesetPubspec['dependency_overrides'];
    if (overrides is YamlMap && overrides.containsKey('vtt_engine_core')) {
      problems.add('dependency_overrides in ruleset pubspec.yaml contains vtt_engine_core');
    }
  }

  // 3. Inspect app pubspec dependencies
  final appDeps = appPubspec['dependencies'];
  final appPubspecRefs = <String, String>{};

  if (appDeps is! YamlMap) {
    problems.add('dependencies missing or invalid in app pubspec.yaml');
  } else {
    for (final pkg in monitoredPackages) {
      if (!appDeps.containsKey(pkg)) {
        problems.add('app pubspec.yaml missing dependency $pkg');
        continue;
      }
      final dep = appDeps[pkg];
      if (dep is! YamlMap) {
        problems.add('$pkg in app pubspec.yaml is not a map');
        continue;
      }
      if (dep.containsKey('path')) {
        problems.add('$pkg is specified as a path dependency instead of git in app pubspec.yaml');
        continue;
      }
      if (!dep.containsKey('git')) {
        problems.add('$pkg is not specified as a git dependency in app pubspec.yaml');
        continue;
      }
      final git = dep['git'];
      if (git is! YamlMap || !git.containsKey('ref')) {
        problems.add('$pkg git dependency missing ref in app pubspec.yaml');
        continue;
      }
      final ref = git['ref']?.toString();
      if (ref == null) {
        problems.add('$pkg git dependency ref is null in app pubspec.yaml');
        continue;
      }

      if (hexRegexAnyCase.hasMatch(ref) && upperRegex.hasMatch(ref)) {
        problems.add('$pkg pubspec ref has uppercase characters: $ref');
      } else if (!hexRegex.hasMatch(ref)) {
        problems.add('$pkg pubspec ref is not a 40-character lowercase SHA: $ref');
      } else {
        appPubspecRefs[pkg] = ref;
      }
    }
  }

  // 4. Inspect ruleset pubspec dependencies (pins vtt_engine_core)
  final rulesetDeps = rulesetPubspec['dependencies'];
  String? rulesetCoreRef;

  if (rulesetDeps is! YamlMap) {
    problems.add('dependencies missing or invalid in ruleset pubspec.yaml');
  } else if (!rulesetDeps.containsKey('vtt_engine_core')) {
    problems.add('ruleset pubspec.yaml missing dependency vtt_engine_core');
  } else {
    final dep = rulesetDeps['vtt_engine_core'];
    if (dep is! YamlMap) {
      problems.add('vtt_engine_core in ruleset pubspec.yaml is not a map');
    } else if (dep.containsKey('path')) {
      problems.add('vtt_engine_core is specified as a path dependency instead of git in ruleset pubspec.yaml');
    } else if (!dep.containsKey('git')) {
      problems.add('vtt_engine_core is not specified as a git dependency in ruleset pubspec.yaml');
    } else {
      final git = dep['git'];
      if (git is! YamlMap || !git.containsKey('ref')) {
        problems.add('vtt_engine_core git dependency missing ref in ruleset pubspec.yaml');
      } else {
        final ref = git['ref']?.toString();
        if (ref == null) {
          problems.add('vtt_engine_core git dependency ref is null in ruleset pubspec.yaml');
        } else if (hexRegexAnyCase.hasMatch(ref) && upperRegex.hasMatch(ref)) {
          problems.add('vtt_engine_core ruleset pubspec ref has uppercase characters: $ref');
        } else if (!hexRegex.hasMatch(ref)) {
          problems.add('vtt_engine_core ruleset pubspec ref is not a 40-character lowercase SHA: $ref');
        } else {
          rulesetCoreRef = ref;
        }
      }
    }
  }

  // Check agreement between ruleset's core pin and app's core pin
  if (rulesetCoreRef != null && appPubspecRefs.containsKey('vtt_engine_core')) {
    final appCoreRef = appPubspecRefs['vtt_engine_core']!;
    if (rulesetCoreRef != appCoreRef) {
      problems.add(
        'ruleset pins a different core SHA ($rulesetCoreRef) than the app ($appCoreRef)',
      );
    }
  }

  // 5. Inspect app pubspec.lock packages
  final lockPackages = appLock['packages'];
  if (lockPackages is! YamlMap) {
    problems.add('packages missing or invalid in app pubspec.lock');
  } else {
    for (final pkg in monitoredPackages) {
      if (!lockPackages.containsKey(pkg)) {
        problems.add('$pkg missing from app pubspec.lock');
        continue;
      }
      final lockEntry = lockPackages[pkg];
      if (lockEntry is! YamlMap) {
        problems.add('$pkg in app pubspec.lock is not a map');
        continue;
      }
      final source = lockEntry['source']?.toString();
      if (source != 'git') {
        problems.add('$pkg lockfile source is not git: $source');
        continue;
      }
      final description = lockEntry['description'];
      if (description is! YamlMap) {
        problems.add('$pkg lockfile description is not a map');
        continue;
      }
      final lockRef = description['ref']?.toString();
      final lockResolvedRef = description['resolved-ref']?.toString();

      if (lockRef == null) {
        problems.add('$pkg lockfile description missing ref');
      } else if (hexRegexAnyCase.hasMatch(lockRef) && upperRegex.hasMatch(lockRef)) {
        problems.add('$pkg lockfile ref has uppercase characters: $lockRef');
      } else if (!hexRegex.hasMatch(lockRef)) {
        problems.add('$pkg lockfile ref is not a 40-character lowercase SHA: $lockRef');
      }

      if (lockResolvedRef == null) {
        problems.add('$pkg lockfile description missing resolved-ref');
      } else if (hexRegexAnyCase.hasMatch(lockResolvedRef) && upperRegex.hasMatch(lockResolvedRef)) {
        problems.add('$pkg lockfile resolved-ref has uppercase characters: $lockResolvedRef');
      } else if (!hexRegex.hasMatch(lockResolvedRef)) {
        problems.add('$pkg lockfile resolved-ref is not a 40-character lowercase SHA: $lockResolvedRef');
      }

      // Agreement between app pubspec ref and lockfile ref
      if (appPubspecRefs.containsKey(pkg) && lockRef != null) {
        final expectedRef = appPubspecRefs[pkg]!;
        if (lockRef != expectedRef) {
          problems.add(
            '$pkg lockfile ref ($lockRef) differs from pubspec ref ($expectedRef)',
          );
        }
      }

      // Agreement between lockfile resolved-ref and lockfile ref
      if (lockRef != null && lockResolvedRef != null && lockResolvedRef != lockRef) {
        problems.add(
          '$pkg lockfile resolved-ref ($lockResolvedRef) differs from ref ($lockRef)',
        );
      }
    }
  }

  return problems;
}

void main() {
  const validCoreSha = '0be55e80d1f4a862d386777fbd0df85f1aafd8e3';
  const validRulesetSha = 'd92ab6ae477a36c6af8299ecb22d37710f6d9861';
  const otherValidSha = '9899376a7992e359aa1f3abae72a0291524e4fa7';

  String buildAppPubspec({
    String coreRef = validCoreSha,
    String rulesetRef = validRulesetSha,
    bool coreAsPath = false,
    bool withOverride = false,
  }) {
    return '''
name: dangerously_nerdy_5e_toolkit
dependencies:
  vtt_engine_core:
    ${coreAsPath ? 'path: packages/vtt_engine_core' : 'git:\n      url: https://github.com/kevinburkeland/vtt-engine-core.git\n      ref: $coreRef'}
  vtt_ruleset_dnd5e:
    git:
      url: https://github.com/kevinburkeland/vtt-ruleset-dnd5e.git
      ref: $rulesetRef
${withOverride ? 'dependency_overrides:\n  vtt_engine_core:\n    path: packages/vtt_engine_core' : ''}
''';
  }

  String buildRulesetPubspec({
    String coreRef = validCoreSha,
    bool withOverride = false,
  }) {
    return '''
name: vtt_ruleset_dnd5e
dependencies:
  vtt_engine_core:
    git:
      url: https://github.com/kevinburkeland/vtt-engine-core.git
      ref: $coreRef
${withOverride ? 'dependency_overrides:\n  vtt_engine_core:\n    path: packages/vtt_engine_core' : ''}
''';
  }

  String buildAppLock({
    String coreRef = validCoreSha,
    String coreResolvedRef = validCoreSha,
    String rulesetRef = validRulesetSha,
    String rulesetResolvedRef = validRulesetSha,
  }) {
    return '''
packages:
  vtt_engine_core:
    dependency: "direct main"
    description:
      path: "."
      ref: "$coreRef"
      resolved-ref: "$coreResolvedRef"
      url: "https://github.com/kevinburkeland/vtt-engine-core.git"
    source: git
    version: "1.0.0"
  vtt_ruleset_dnd5e:
    dependency: "direct main"
    description:
      path: "."
      ref: "$rulesetRef"
      resolved-ref: "$rulesetResolvedRef"
      url: "https://github.com/kevinburkeland/vtt-ruleset-dnd5e.git"
    source: git
    version: "1.0.0"
''';
  }

  group('Pin Agreement Invariants (Inline Tests)', () {
    test('all agree: no problems', () {
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(),
        appPubspecLock: buildAppLock(),
        rulesetPubspecYaml: buildRulesetPubspec(),
      );
      expect(problems, isEmpty);
    });

    test('lockfile resolved-ref differs from ref: one problem naming package and both SHAs', () {
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(),
        appPubspecLock: buildAppLock(coreResolvedRef: otherValidSha),
        rulesetPubspecYaml: buildRulesetPubspec(),
      );
      expect(problems.length, 1);
      final p = problems.first;
      expect(p, contains('vtt_engine_core'));
      expect(p, contains(validCoreSha));
      expect(p, contains(otherValidSha));
    });

    test('lockfile ref differs from pubspec ref: problem', () {
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(),
        appPubspecLock: buildAppLock(coreRef: otherValidSha, coreResolvedRef: otherValidSha),
        rulesetPubspecYaml: buildRulesetPubspec(),
      );
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('differs from pubspec ref')), isTrue);
    });

    test('ruleset pins a different core SHA than the app: problem', () {
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(),
        appPubspecLock: buildAppLock(),
        rulesetPubspecYaml: buildRulesetPubspec(coreRef: otherValidSha),
      );
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('ruleset pins a different core SHA')), isTrue);
    });

    test('a pubspec ref that is a branch name, a tag, or a short SHA: problem', () {
      final problemsBranch = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(coreRef: 'main'),
        appPubspecLock: buildAppLock(coreRef: 'main', coreResolvedRef: 'main'),
        rulesetPubspecYaml: buildRulesetPubspec(coreRef: 'main'),
      );
      expect(problemsBranch.any((p) => p.contains('not a 40-character lowercase SHA')), isTrue);

      final problemsShort = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(coreRef: '0be55e8'),
        appPubspecLock: buildAppLock(coreRef: '0be55e8', coreResolvedRef: '0be55e8'),
        rulesetPubspecYaml: buildRulesetPubspec(coreRef: '0be55e8'),
      );
      expect(problemsShort.any((p) => p.contains('not a 40-character lowercase SHA')), isTrue);
    });

    test('an uppercase SHA: problem', () {
      final upperSha = validCoreSha.toUpperCase();
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(coreRef: upperSha),
        appPubspecLock: buildAppLock(coreRef: upperSha, coreResolvedRef: upperSha),
        rulesetPubspecYaml: buildRulesetPubspec(coreRef: upperSha),
      );
      expect(problems, isNotEmpty);
      expect(problems.any((p) => p.contains('uppercase')), isTrue);
    });

    test('dependency_overrides naming either package: problem', () {
      final problemsApp = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(withOverride: true),
        appPubspecLock: buildAppLock(),
        rulesetPubspecYaml: buildRulesetPubspec(),
      );
      expect(problemsApp.any((p) => p.contains('dependency_overrides in app pubspec.yaml')), isTrue);

      final problemsRuleset = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(),
        appPubspecLock: buildAppLock(),
        rulesetPubspecYaml: buildRulesetPubspec(withOverride: true),
      );
      expect(problemsRuleset.any((p) => p.contains('dependency_overrides in ruleset pubspec.yaml')), isTrue);
    });

    test('either package given as a path: dependency instead of git:: problem', () {
      final problems = checkPinAgreement(
        appPubspecYaml: buildAppPubspec(coreAsPath: true),
        appPubspecLock: buildAppLock(),
        rulesetPubspecYaml: buildRulesetPubspec(),
      );
      expect(problems.any((p) => p.contains('path dependency instead of git')), isTrue);
    });
  });

  group('Live Pin Agreement Test', () {
    test('real pubspec.yaml, pubspec.lock, and ruleset pubspec agree with zero problems', () {
      final appPubspecFile = File('pubspec.yaml');
      final appLockFile = File('pubspec.lock');
      final packageConfigFile = File('.dart_tool/package_config.json');

      expect(appPubspecFile.existsSync(), isTrue);
      expect(appLockFile.existsSync(), isTrue);
      expect(packageConfigFile.existsSync(), isTrue);

      final appPubspecContent = appPubspecFile.readAsStringSync();
      final appLockContent = appLockFile.readAsStringSync();

      // Read rootUri for vtt_ruleset_dnd5e from package_config.json
      final packageConfigJson = jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
      final packages = packageConfigJson['packages'] as List<dynamic>;
      final rulesetEntry = packages.firstWhere(
        (pkg) => pkg['name'] == 'vtt_ruleset_dnd5e',
        orElse: () => throw StateError('vtt_ruleset_dnd5e not found in package_config.json'),
      );
      final rootUriStr = rulesetEntry['rootUri'] as String;
      final rootUri = Uri.parse(rootUriStr);
      final rulesetPubspecPath = rootUri.resolve('pubspec.yaml').toFilePath();
      final rulesetPubspecFile = File(rulesetPubspecPath);
      expect(rulesetPubspecFile.existsSync(), isTrue, reason: 'Ruleset pubspec must exist at $rulesetPubspecPath');

      final rulesetPubspecContent = rulesetPubspecFile.readAsStringSync();

      final problems = checkPinAgreement(
        appPubspecYaml: appPubspecContent,
        appPubspecLock: appLockContent,
        rulesetPubspecYaml: rulesetPubspecContent,
      );

      expect(
        problems,
        isEmpty,
        reason: 'Pin agreement verification failed with problems:\n${problems.join('\n')}',
      );
    });
  });
}
