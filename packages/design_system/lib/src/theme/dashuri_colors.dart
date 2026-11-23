import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';

/// One semantic status tone: a container (tinted background), the text
/// colour on it, and an icon/accent colour. [onContainer] meets WCAG AA
/// (4.5:1) on [container]; [icon] meets 3:1 on [container] and on the
/// theme surface. Verified in test/theme_contrast_test.dart.
@immutable
final class DashuriTone {
  const DashuriTone({
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final Color container;
  final Color onContainer;
  final Color icon;

  static DashuriTone lerp(DashuriTone a, DashuriTone b, double t) =>
      DashuriTone(
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
        icon: Color.lerp(a.icon, b.icon, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is DashuriTone &&
      other.container == container &&
      other.onContainer == onContainer &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(container, onContainer, icon);
}

/// Semantic colours the Material [ColorScheme] has no role for: status
/// tones, money-in text, the online dot, and the fixed "hero" and media
/// overlay palettes. Light and dark variants; read with
/// `DashuriColors.of(context)`.
///
/// Rule: feature code takes status/feedback colours from here and
/// surface/text colours from `Theme.of(context).colorScheme`. Raw
/// `DashuriTokens` colours are for fixed-background art only (brand hero
/// gradients, video/photo overlays), where the background does not change
/// with the theme.
@immutable
final class DashuriColors extends ThemeExtension<DashuriColors> {
  const DashuriColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.neutral,
    required this.positiveText,
    required this.onlineDot,
  });

  final DashuriTone success;
  final DashuriTone warning;
  final DashuriTone error;
  final DashuriTone info;

  /// Muted tags (offline, neutral).
  final DashuriTone neutral;

  /// Money-in amounts and other "good" text on the theme surface.
  final Color positiveText;

  /// The availability dot on the theme surface.
  final Color onlineDot;

  // Fixed palettes (identical in both themes: their backgrounds are fixed).

  /// Text and icons on the burgundy brand hero gradients.
  static const Color onHero = DashuriTokens.neutral0;

  /// Secondary text on the brand hero gradients (≥ 4.5:1 on burgundy-600+).
  static const Color onHeroMuted = DashuriTokens.burgundy100;

  /// Text and icons over video or photos; always paired with [mediaScrim]
  /// or a text shadow so it stays readable over bright frames.
  static const Color onMedia = Colors.white;
  static const Color onMediaMuted = Color(0xE6FFFFFF);
  static const Color mediaScrim = Color(0x99000000);

  static const light = DashuriColors(
    success: DashuriTone(
      container: DashuriTokens.success100,
      onContainer: DashuriTokens.successText,
      icon: DashuriTokens.success,
    ),
    warning: DashuriTone(
      container: DashuriTokens.warning100,
      onContainer: DashuriTokens.warningText,
      icon: DashuriTokens.warning,
    ),
    error: DashuriTone(
      container: DashuriTokens.error100,
      onContainer: DashuriTokens.error,
      icon: DashuriTokens.error,
    ),
    info: DashuriTone(
      container: DashuriTokens.info100,
      onContainer: DashuriTokens.info,
      icon: DashuriTokens.info,
    ),
    neutral: DashuriTone(
      container: DashuriTokens.neutral100,
      onContainer: DashuriTokens.neutral700,
      icon: DashuriTokens.neutral600,
    ),
    positiveText: DashuriTokens.successText,
    // The brand online green is 2.2:1 on white; the darker success green
    // keeps the dot visible (4.0:1).
    onlineDot: DashuriTokens.success,
  );

  static const dark = DashuriColors(
    success: DashuriTone(
      container: Color(0xFF12301F),
      onContainer: Color(0xFFA8E2C4),
      icon: Color(0xFF5CCB95),
    ),
    warning: DashuriTone(
      container: Color(0xFF3A2A0C),
      onContainer: Color(0xFFF5D8A0),
      icon: Color(0xFFE5A23A),
    ),
    error: DashuriTone(
      container: Color(0xFF4A1714),
      onContainer: Color(0xFFF9DEDC),
      icon: Color(0xFFF2B8B5),
    ),
    info: DashuriTone(
      container: Color(0xFF13283A),
      onContainer: Color(0xFFC7DDF0),
      icon: Color(0xFF8DBBE2),
    ),
    neutral: DashuriTone(
      container: DashuriTokens.neutral800,
      onContainer: DashuriTokens.neutral200,
      icon: DashuriTokens.neutral300,
    ),
    positiveText: Color(0xFF6FD3A0),
    onlineDot: DashuriTokens.online,
  );

  /// The colours of the current theme. Falls back to the variant matching
  /// the theme brightness when a test/app theme was built without it.
  static DashuriColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<DashuriColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  DashuriColors copyWith({
    DashuriTone? success,
    DashuriTone? warning,
    DashuriTone? error,
    DashuriTone? info,
    DashuriTone? neutral,
    Color? positiveText,
    Color? onlineDot,
  }) => DashuriColors(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    info: info ?? this.info,
    neutral: neutral ?? this.neutral,
    positiveText: positiveText ?? this.positiveText,
    onlineDot: onlineDot ?? this.onlineDot,
  );

  @override
  DashuriColors lerp(DashuriColors? other, double t) {
    if (other == null) return this;
    return DashuriColors(
      success: DashuriTone.lerp(success, other.success, t),
      warning: DashuriTone.lerp(warning, other.warning, t),
      error: DashuriTone.lerp(error, other.error, t),
      info: DashuriTone.lerp(info, other.info, t),
      neutral: DashuriTone.lerp(neutral, other.neutral, t),
      positiveText: Color.lerp(positiveText, other.positiveText, t)!,
      onlineDot: Color.lerp(onlineDot, other.onlineDot, t)!,
    );
  }
}
