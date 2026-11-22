import 'package:flutter/material.dart';

/// Design tokens from the 19 Nov 2026 design handoff
/// (`design/_build/ds.css`, sheets DS01–DS04).
///
/// Rule: pages and components read tokens through the theme or these
/// constants. No hard-coded colours, sizes or durations in feature code.
abstract final class DashuriTokens {
  // Burgundy (primary).
  static const Color burgundy50 = Color(0xFFFBF2F4);
  static const Color burgundy100 = Color(0xFFF5E1E7);
  static const Color burgundy200 = Color(0xFFEBC3CF);
  static const Color burgundy300 = Color(0xFFDB97AB);
  static const Color burgundy400 = Color(0xFFC26481);
  static const Color burgundy500 = Color(0xFFA33A5C);
  static const Color burgundy600 = Color(0xFF8A2546);
  static const Color burgundy700 = Color(0xFF761C3B);
  static const Color burgundy800 = Color(0xFF5E1630);
  static const Color burgundy900 = Color(0xFF451024);
  static const Color burgundy950 = Color(0xFF2B0A17);

  // Warm neutrals.
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFFCFAF7);
  static const Color neutral50 = Color(0xFFF7F3EE);
  static const Color neutral100 = Color(0xFFEFE9E2);
  static const Color neutral200 = Color(0xFFE3DBD2);
  static const Color neutral300 = Color(0xFFCFC5BA);
  static const Color neutral400 = Color(0xFFABA096);
  static const Color neutral500 = Color(0xFF857A71);
  static const Color neutral600 = Color(0xFF655B54);
  static const Color neutral700 = Color(0xFF4A423D);
  static const Color neutral800 = Color(0xFF2F2926);
  static const Color neutral900 = Color(0xFF1C1816);
  static const Color neutral950 = Color(0xFF110E0D);

  // Supporting.
  static const Color gold = Color(0xFFB98A3E);
  static const Color goldDark = Color(0xFF8F6A2C);
  static const Color gold100 = Color(0xFFF6EBD6);
  static const Color success = Color(0xFF2E8B62);
  static const Color success100 = Color(0xFFE3F3EB);
  static const Color warning = Color(0xFFC27A12);
  static const Color warning100 = Color(0xFFFBEFD9);
  static const Color error = Color(0xFFB4322A);
  static const Color error100 = Color(0xFFF9E4E1);
  static const Color info = Color(0xFF2F6690);
  static const Color info100 = Color(0xFFE2ECF4);
  static const Color online = Color(0xFF34C77B);

  /// Text on the warning/success tints (warning100, success100). The base
  /// colours measure 3.0:1 and 3.7:1 there, below WCAG AA (4.5:1) for body
  /// text; these measure 5.5:1 and 5.6:1. Icons keep the base colours.
  static const Color warningText = Color(0xFF8A5408);
  static const Color successText = Color(0xFF1F6B4A);

  /// Kept for compatibility with the scaffold: the brand seed.
  static const Color seedColor = burgundy700;

  // Spacing scale (logical pixels).
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;

  // Corner radii.
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 28;
  static const double radiusPill = 999;

  // Sizes.
  static const double minTapTarget = 48;
  static const double buttonHeight = 52;

  /// Max width of single-column content (forms, settings, chat) on large
  /// screens, so lines stay readable on tablets and foldables.
  static const double maxContentWidth = 560;

  /// Max width of wide content (grids, dashboards).
  static const double maxWideContentWidth = 1200;

  // Motion.
  static const Duration motionShort = Duration(milliseconds: 150);
  static const Duration motionMedium = Duration(milliseconds: 250);
  static const Duration motionLong = Duration(milliseconds: 400);

  // Elevation shadows.
  static const List<BoxShadow> shadow1 = [
    BoxShadow(color: Color(0x0F1C1816), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadow2 = [
    BoxShadow(color: Color(0x141C1816), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0D1C1816), blurRadius: 3, offset: Offset(0, 1)),
  ];
}
