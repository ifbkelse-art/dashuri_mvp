// Enforces Dashuri's dependency rules (docs/architecture/dependency-rules.md).
// Run: melos run deps:check   (exit code 1 on any violation)
import 'dart:io';

final violations = <String>[];

void main() {
  final root = Directory.current;
  final features = Directory(
    '${root.path}/packages/features',
  ).listSync().whereType<Directory>();

  // R1: only packages/supabase may depend on or import supabase_flutter.
  for (final pubspec in _pubspecs(root)) {
    final text = pubspec.readAsStringSync();
    final isSupabaseAdapter = pubspec.path.endsWith(
      'packages/supabase/pubspec.yaml',
    );
    if (!isSupabaseAdapter &&
        RegExp(r'^\s+supabase_flutter:', multiLine: true).hasMatch(text)) {
      violations.add(
        'R1 ${_rel(pubspec)} depends on supabase_flutter (only packages/supabase may).',
      );
    }
  }

  // R2: features must not depend on other features.
  for (final f in features) {
    final pubspec = File('${f.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    for (final m in RegExp(
      r'^\s+(feature_\w+):',
      multiLine: true,
    ).allMatches(pubspec.readAsStringSync())) {
      violations.add(
        'R2 ${_rel(pubspec)} depends on ${m.group(1)}; navigate with RoutePaths instead.',
      );
    }
  }

  // R3–R6: layer import rules inside every feature.
  for (final f in features) {
    final src = Directory('${f.path}/lib/src');
    if (!src.existsSync()) continue;
    for (final file
        in src
            .listSync(recursive: true)
            .whereType<File>()
            .where((x) => x.path.endsWith('.dart'))) {
      final path = file.path;
      final imports = RegExp(
        r'''^import\s+['"]([^'"]+)['"]''',
        multiLine: true,
      ).allMatches(file.readAsStringSync()).map((m) => m.group(1)!).toList();
      bool any(bool Function(String) test) => imports.any(test);
      if (path.contains('/domain/') &&
          any(
            (i) =>
                i.startsWith('package:flutter/') ||
                i.contains('dashuri_network') ||
                i.contains('/data/'),
          )) {
        violations.add(
          'R3 ${_rel(file)}: domain must be pure Dart (no Flutter, network or data imports).',
        );
      }
      if (path.contains('/application/') &&
          any((i) => i.contains('dashuri_network') || i.contains('/data/'))) {
        violations.add(
          'R4 ${_rel(file)}: BLoCs use use cases, not data sources or the API client.',
        );
      }
      if (path.contains('/presentation/') &&
          any(
            (i) =>
                i.contains('dashuri_network') ||
                i.contains('/data/') ||
                i.contains('get_it'),
          )) {
        violations.add(
          'R5 ${_rel(file)}: pages read BLoC state; no data layer, API or service-locator imports.',
        );
      }
      if (any((i) => i.startsWith('package:dio/'))) {
        violations.add(
          'R6 ${_rel(file)}: only packages/network may import dio.',
        );
      }
    }
  }

  // R7: core stays pure Dart.
  final core = Directory('${root.path}/packages/core/lib');
  for (final file
      in core
          .listSync(recursive: true)
          .whereType<File>()
          .where((x) => x.path.endsWith('.dart'))) {
    if (file.readAsStringSync().contains("import 'package:flutter/")) {
      violations.add('R7 ${_rel(file)}: dashuri_core must not import Flutter.');
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Dependency rules: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  stderr.writeln('${violations.length} dependency rule violation(s).');
  exitCode = 1;
}

Iterable<File> _pubspecs(Directory root) =>
    [
      ...Directory('${root.path}/packages').listSync(recursive: true),
      ...Directory('${root.path}/apps').listSync(recursive: true),
    ].whereType<File>().where(
      (f) =>
          f.path.endsWith('/pubspec.yaml') &&
          !f.path.contains('/.dart_tool/') &&
          !f.path.contains('/build/'),
    );

String _rel(FileSystemEntity e) =>
    e.path.replaceFirst('${Directory.current.path}/', '');
