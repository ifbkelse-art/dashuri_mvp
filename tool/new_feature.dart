// Scaffolds an empty feature package with the standard layer folders.
// Usage: dart run tool/new_feature.dart <snake_case_name>
import 'dart:io';

void main(List<String> args) {
  if (args.length != 1 || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(args.single)) {
    stderr.writeln('usage: dart run tool/new_feature.dart <snake_case_name>');
    exitCode = 64;
    return;
  }
  final name = args.single;
  final cls = name
      .split('_')
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join();
  final dir = Directory('packages/features/$name');
  if (dir.existsSync()) {
    stderr.writeln('${dir.path} already exists');
    exitCode = 1;
    return;
  }
  void write(String path, String content) => (File(
    '${dir.path}/$path',
  )..createSync(recursive: true)).writeAsStringSync(content);

  for (final d in [
    'lib/src/domain/entities',
    'lib/src/domain/repositories',
    'lib/src/domain/usecases',
    'lib/src/data/models',
    'lib/src/data/datasources',
    'lib/src/data/repositories',
    'lib/src/application',
    'lib/src/presentation/pages',
    'lib/src/presentation/widgets',
    'test/application',
    'test/domain',
  ]) {
    write('$d/.gitkeep', '');
  }
  write('pubspec.yaml', '''
name: feature_$name
description: TODO describe the $name feature.
publish_to: none
version: 0.1.0
resolution: workspace

environment:
  sdk: ^3.9.0
  flutter: ">=3.35.0"

dependencies:
  bloc: ^9.0.0
  dashuri_core:
    path: ../../core
  dashuri_design_system:
    path: ../../design_system
  dashuri_navigation:
    path: ../../navigation
  dashuri_network:
    path: ../../network
  equatable: ^2.0.7
  flutter:
    sdk: flutter
  flutter_bloc: ^9.1.1
  get_it: ^9.2.1

dev_dependencies:
  bloc_test: ^10.0.0
  dashuri_lints:
    path: ../../lints
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
''');
  write(
    'analysis_options.yaml',
    'include: package:dashuri_lints/analysis_options.yaml\n',
  );
  write('lib/src/di/${name}_module.dart', '''
import 'package:get_it/get_it.dart';

/// Registers the $name feature: data sources and repositories as lazy
/// singletons, use cases and BLoCs as factories.
void register${cls}Feature(GetIt sl) {
  // TODO: register data source, repository, use cases, BLoCs.
}
''');
  write('lib/src/routes/${name}_routes.dart', '''
import 'package:dashuri_navigation/dashuri_navigation.dart';

final class ${cls}Routes implements FeatureRoutes {
  const ${cls}Routes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
''');
  write('lib/feature_$name.dart', '''
/// TODO describe the $name feature.
library;

export 'src/di/${name}_module.dart';
export 'src/routes/${name}_routes.dart';
''');
  write(
    'README.md',
    '# feature_$name\n\nTODO: responsibility, endpoints, business rules, pages.\n',
  );
  write('test/application/.gitkeep', '');
  stdout.writeln('''
Created ${dir.path}. Next:
  1. Add "  - packages/features/$name" to the workspace list in the root pubspec.yaml.
  2. Add feature_$name (path dependency) to apps/mobile/pubspec.yaml.
  3. Call register${cls}Feature(sl) in apps/mobile/lib/app/di/injector.dart.
  4. Add const ${cls}Routes() to apps/mobile/lib/app/router/app_router.dart.
  5. Run: dart pub get && melos run analyze && melos run deps:check
''');
}
