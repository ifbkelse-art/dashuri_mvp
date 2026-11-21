import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/widgets.dart';

import '../app/app.dart';
import '../app/di/injector.dart';
import '../app/observers/app_bloc_observer.dart';
import '../app/observers/debug_logger.dart';

/// Startup sequence: config → logging/error hooks → DI → runApp.
Future<void> bootstrap() async {
  final logger = DebugLogger();
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) => logger.error(
        'Flutter error',
        error: details.exception,
        stackTrace: details.stack,
      );
      Bloc.observer = AppBlocObserver(logger);

      final config = AppConfig.fromEnvironment();
      final missing = config.validate();
      if (missing.isNotEmpty) {
        logger.warning(
          'Missing configuration: ${missing.join(', ')}. Network features will fail.',
        );
      }

      await configureDependencies(config, logger);
      runApp(const DashuriApp());
    },
    (error, stack) =>
        logger.error('Uncaught error', error: error, stackTrace: stack),
  );
}
