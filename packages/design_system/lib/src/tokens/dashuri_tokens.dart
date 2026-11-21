import 'package:flutter/material.dart';

/// Design tokens. These are NEUTRAL STARTING VALUES so the app compiles;
/// the founder owns the visual identity and replaces them.
///
/// Rule: pages and components read tokens through the theme or these
/// constants. No hard-coded colours, sizes or durations in feature code.
abstract final class DashuriTokens {
  // TODO(founder): set the brand seed colour.
  static const Color seedColor = Color(0xFF6750A4);

  // Spacing scale (logical pixels).
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  // Corner radii.
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;

  // Motion.
  static const Duration motionShort = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 250);
}
