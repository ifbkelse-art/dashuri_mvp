import 'package:dashuri_core/dashuri_core.dart';
import 'package:flutter/foundation.dart';

/// Development logger. Replace with a crash/telemetry sink before release
/// (vendor not chosen). Never log personal data.
final class DebugLogger implements AppLogger {
  @override
  void debug(String message, {Map<String, Object?> context = const {}}) =>
      _log('DEBUG', message, context);

  @override
  void info(String message, {Map<String, Object?> context = const {}}) =>
      _log('INFO', message, context);

  @override
  void warning(
    String message, {
    Object? error,
    Map<String, Object?> context = const {},
  }) => _log('WARN', '$message ${error ?? ''}', context);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) => _log('ERROR', '$message $error\n${stackTrace ?? ''}', context);

  void _log(String level, String message, Map<String, Object?> context) {
    if (kDebugMode) {
      debugPrint('[$level] $message ${context.isEmpty ? '' : context}');
    }
  }
}
