/// Logging contract. The app wires a concrete implementation at bootstrap.
/// Never log tokens, phone numbers, KYC data, message bodies or video frames.
abstract interface class AppLogger {
  void debug(String message, {Map<String, Object?> context});
  void info(String message, {Map<String, Object?> context});
  void warning(String message, {Object? error, Map<String, Object?> context});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context,
  });
}
