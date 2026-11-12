import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Helper that inspects the Dart package dependency graph from
/// `.dart_tool/package_config.json` and package pubspecs to determine
/// whether a package or URI is Flutter-bound.
class FlutterPackageDetector {
  final Map<String, Uri> _packageRoots = {};
  final Map<String, List<String>> _packageDependencies = {};
  final Map<String, bool> _flutterBoundCache = {};
  final Set<String> _directSdkPackageNames = {
    'flutter',
    'flutter_test',
    'flutter_localizations',
    'flutter_web_plugins',
    'sky_engine',
  };
  Uri? _flutterSdkRoot;

  FlutterPackageDetector._();

  static FlutterPackageDetector? _instance;

  /// Default detector instance backed by `.dart_tool/package_config.json`.
  static FlutterPackageDetector get instance {
    return _instance ??= fromPackageConfig('.dart_tool/package_config.json');
  }

  /// Resets the default detector instance (e.g. for testing).
  static void resetDefaultInstance() {
    _instance = null;
  }

  /// Constructs a detector from the specified `package_config.json` path.
  ///
  /// Throws [FileSystemException] or [StateError] if the configuration file
  /// or any constituent package pubspec cannot be found or read (failing closed).
  static FlutterPackageDetector fromPackageConfig(String packageConfigPath) {
    final configFile = File(packageConfigPath);
    if (!configFile.existsSync()) {
      throw FileSystemException(
        'Cannot read package_config.json: file does not exist',
        packageConfigPath,
      );
    }

    final String jsonContent;
    try {
      jsonContent = configFile.readAsStringSync();
    } catch (e) {
      throw FileSystemException(
        'Cannot read package_config.json: $e',
        packageConfigPath,
      );
    }

    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonContent);
    } catch (e) {
      throw FormatException(
        'Invalid JSON in package_config.json at $packageConfigPath: $e',
      );
    }

    if (parsed is! Map<String, dynamic> || parsed['packages'] is! List) {
      throw FormatException(
        'Malformed package_config.json at $packageConfigPath: missing packages list',
      );
    }

    final detector = FlutterPackageDetector._();
    final configUri = configFile.absolute.uri;
    final packagesList = parsed['packages'] as List;

    for (final rawEntry in packagesList) {
      if (rawEntry is! Map) {
        throw FormatException(
          'Malformed package entry in $packageConfigPath',
        );
      }
      final name = rawEntry['name'] as String?;
      final rootUriStr = rawEntry['rootUri'] as String?;
      if (name == null || rootUriStr == null) {
        throw FormatException(
          'Package entry missing name or rootUri in $packageConfigPath',
        );
      }

      final normalizedRootUriStr = rootUriStr.endsWith('/') ? rootUriStr : '$rootUriStr/';
      final resolvedRootUri = configUri.resolve(normalizedRootUriStr);
      detector._packageRoots[name] = resolvedRootUri;

      if (name == 'flutter') {
        final path = resolvedRootUri.path;
        final idx = path.indexOf('/packages/flutter');
        if (idx != -1) {
          detector._flutterSdkRoot = Uri(
            scheme: resolvedRootUri.scheme,
            path: path.substring(0, idx),
          );
        }
      }
    }

    // Now read each package's pubspec.yaml from its rootUri.
    for (final entry in detector._packageRoots.entries) {
      final name = entry.key;
      final rootUri = entry.value;

      final pubspecUri = rootUri.resolve('pubspec.yaml');
      final pubspecFile = File.fromUri(pubspecUri);
      if (!pubspecFile.existsSync()) {
        throw FileSystemException(
          'Cannot read pubspec.yaml for package "$name": file does not exist',
          pubspecFile.path,
        );
      }

      final String pubspecContent;
      try {
        pubspecContent = pubspecFile.readAsStringSync();
      } catch (e) {
        throw FileSystemException(
          'Cannot read pubspec.yaml for package "$name": $e',
          pubspecFile.path,
        );
      }

      final dynamic yaml;
      try {
        yaml = loadYaml(pubspecContent);
      } catch (e) {
        throw FormatException(
          'Invalid YAML in pubspec.yaml for package "$name" at ${pubspecFile.path}: $e',
        );
      }

      final depsList = <String>[];
      if (yaml is Map) {
        final deps = yaml['dependencies'];
        if (deps is Map) {
          for (final depKey in deps.keys) {
            depsList.add(depKey.toString());
          }
        }
      }
      detector._packageDependencies[name] = depsList;
    }

    return detector;
  }

  /// Determines whether [name] is a direct Flutter SDK package.
  bool _isDirectFlutterSdkPackage(String name) {
    if (_directSdkPackageNames.contains(name)) {
      return true;
    }
    final root = _packageRoots[name];
    if (root != null) {
      final path = root.path;
      if (path.contains('/packages/flutter/') ||
          path.contains('/bin/cache/pkg/')) {
        return true;
      }
      if (_flutterSdkRoot != null && path.startsWith(_flutterSdkRoot!.path)) {
        return true;
      }
    }
    return false;
  }

  /// Checks whether [packageName] is Flutter-bound transitively.
  bool isFlutterBoundPackage(String packageName) {
    if (_flutterBoundCache.containsKey(packageName)) {
      return _flutterBoundCache[packageName]!;
    }
    if (!_packageRoots.containsKey(packageName)) {
      throw StateError('Unknown package in package graph: $packageName');
    }
    final visited = <String>{};
    final bound = _resolveFlutterBound(packageName, visited);
    _flutterBoundCache[packageName] = bound;
    return bound;
  }

  bool _resolveFlutterBound(String name, Set<String> visited) {
    if (!visited.add(name)) {
      return false; // Cycle guard
    }
    if (_isDirectFlutterSdkPackage(name)) {
      return true;
    }
    final deps = _packageDependencies[name] ?? const [];
    for (final dep in deps) {
      if (_isDirectFlutterSdkPackage(dep)) {
        return true;
      }
      if (_packageRoots.containsKey(dep)) {
        if (_resolveFlutterBound(dep, visited)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Determines whether [uri] is Flutter-bound.
  ///
  /// - `dart:ui` and `dart:ui_web` are always Flutter-bound.
  /// - Other `dart:` URIs are not Flutter-bound.
  /// - `package:<name>/...`: resolves from the package graph.
  ///   The app package itself (`dangerously_nerdy_5e_toolkit`) returns false
  ///   (its imports are governed by internal folder layer rules).
  /// - Relative URIs return false (governed by internal folder layer rules).
  bool isFlutterBoundUri(String uri) {
    if (uri == 'dart:ui' ||
        uri.startsWith('dart:ui/') ||
        uri == 'dart:ui_web' ||
        uri.startsWith('dart:ui_web/')) {
      return true;
    }
    if (uri.startsWith('dart:')) {
      return false;
    }
    if (uri.startsWith('package:')) {
      final slashIdx = uri.indexOf('/', 8);
      final pkgName = slashIdx == -1 ? uri.substring(8) : uri.substring(8, slashIdx);
      if (pkgName == 'dangerously_nerdy_5e_toolkit') {
        return false;
      }
      return isFlutterBoundPackage(pkgName);
    }
    return false;
  }
}

/// Convenience top-level function that delegates to [FlutterPackageDetector.instance].
bool isFlutterBoundUri(String uri) =>
    FlutterPackageDetector.instance.isFlutterBoundUri(uri);

/// Convenience top-level function that delegates to [FlutterPackageDetector.instance].
bool isFlutterBoundPackage(String packageName) =>
    FlutterPackageDetector.instance.isFlutterBoundPackage(packageName);

/// Strips block and line comments from [source] preserving newline characters.
String stripCommentsPreservingNewlines(String source) {
  final sb = StringBuffer();
  int i = 0;
  final n = source.length;
  bool inBlock = false;
  while (i < n) {
    if (inBlock) {
      if (i + 1 < n && source[i] == '*' && source[i + 1] == '/') {
        inBlock = false;
        i += 2;
      } else {
        if (source[i] == '\n') sb.write('\n');
        i++;
      }
    } else {
      if (i + 1 < n && source[i] == '/' && source[i + 1] == '*') {
        inBlock = true;
        i += 2;
      } else if (i + 1 < n && source[i] == '/' && source[i + 1] == '/') {
        while (i < n && source[i] != '\n') {
          i++;
        }
      } else {
        sb.write(source[i]);
        i++;
      }
    }
  }
  return sb.toString();
}

final _directiveRegex = RegExp(
  r'''(?:import|export)\s+(?:deferred\s+as\s+[a-zA-Z0-9_]+\s+)?(?:as\s+[a-zA-Z0-9_]+\s+)?['"]([^'"]+)['"]''',
);

/// Extracts all import and export URIs from [source], ignoring comments.
List<String> extractImportExportUris(String source) {
  final stripped = stripCommentsPreservingNewlines(source);
  final uris = <String>[];
  for (final match in _directiveRegex.allMatches(stripped)) {
    final uri = match.group(1);
    if (uri != null && uri.isNotEmpty) {
      uris.add(uri);
    }
  }
  return uris;
}
