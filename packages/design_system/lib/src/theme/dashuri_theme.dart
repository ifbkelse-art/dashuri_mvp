import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';

/// Builds the Material 3 themes from tokens. Customise typography and
/// component themes here, not in pages.
abstract final class DashuriTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: DashuriTokens.seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // TODO(founder): typography, component themes (buttons, cards, inputs).
    );
  }
}
