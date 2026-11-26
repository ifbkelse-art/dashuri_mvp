import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography from DS03: Instrument Serif for display, Manrope for UI.
///
/// Fonts are fetched by `google_fonts` and cached on first use; offline first
/// launches fall back to the platform font. To ship fully offline, bundle the
/// TTFs under `assets/google_fonts/` (see google_fonts docs).
abstract final class DashuriText {
  /// Set to false in tests (no network) to use local font fallbacks.
  static bool useGoogleFonts = true;

  static TextStyle display(double size, double height, Color color) {
    final base = TextStyle(
      fontSize: size,
      height: height / size,
      color: color,
      letterSpacing: -0.2,
    );
    return useGoogleFonts
        ? GoogleFonts.instrumentSerif(textStyle: base)
        : base.copyWith(fontFamily: 'serif');
  }

  static TextTheme textTheme(Color ink, Color ink2) {
    TextStyle s(
      double size,
      double lh,
      FontWeight w, {
      Color? c,
      double ls = 0,
    }) {
      final base = TextStyle(
        fontSize: size,
        height: lh / size,
        fontWeight: w,
        color: c ?? ink,
        letterSpacing: ls,
      );
      return useGoogleFonts ? GoogleFonts.manrope(textStyle: base) : base;
    }

    return TextTheme(
      displayLarge: display(46, 48, ink),
      displayMedium: display(38, 42, ink),
      displaySmall: display(30, 34, ink),
      headlineLarge: display(30, 34, ink),
      headlineMedium: display(24, 28, ink),
      headlineSmall: s(22, 28, FontWeight.w700, ls: -0.2),
      titleLarge: s(18, 24, FontWeight.w700, ls: -0.1),
      titleMedium: s(16, 22, FontWeight.w700),
      titleSmall: s(14, 20, FontWeight.w700),
      bodyLarge: s(16, 24, FontWeight.w500),
      bodyMedium: s(14, 20, FontWeight.w500),
      bodySmall: s(13, 18, FontWeight.w500, c: ink2),
      labelLarge: s(15, 20, FontWeight.w700),
      labelMedium: s(12, 16, FontWeight.w700, ls: 0.24),
      labelSmall: s(11, 14, FontWeight.w600, ls: 0.22),
    );
  }
}
