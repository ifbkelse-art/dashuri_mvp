import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';
import 'dashuri_text.dart';

/// Material 3 themes built from the design tokens (light is the designed
/// mode; dark is derived for system dark mode and the in-call screens).
abstract final class DashuriTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: light ? DashuriTokens.burgundy700 : DashuriTokens.burgundy300,
      onPrimary: light ? DashuriTokens.neutral0 : DashuriTokens.burgundy950,
      primaryContainer: light
          ? DashuriTokens.burgundy50
          : DashuriTokens.burgundy800,
      onPrimaryContainer: light
          ? DashuriTokens.burgundy800
          : DashuriTokens.burgundy50,
      secondary: light ? DashuriTokens.goldDark : DashuriTokens.gold,
      onSecondary: DashuriTokens.neutral0,
      secondaryContainer: light
          ? DashuriTokens.gold100
          : const Color(0xFF3A2C14),
      onSecondaryContainer: light
          ? DashuriTokens.goldDark
          : DashuriTokens.gold100,
      tertiary: DashuriTokens.info,
      onTertiary: DashuriTokens.neutral0,
      error: light ? DashuriTokens.error : const Color(0xFFF2B8B5),
      onError: light ? DashuriTokens.neutral0 : const Color(0xFF601410),
      errorContainer: light ? DashuriTokens.error100 : const Color(0xFF8C1D18),
      onErrorContainer: light ? DashuriTokens.error : const Color(0xFFF9DEDC),
      surface: light ? DashuriTokens.neutral25 : DashuriTokens.neutral950,
      onSurface: light ? DashuriTokens.neutral900 : DashuriTokens.neutral50,
      onSurfaceVariant: light
          ? DashuriTokens.neutral600
          : DashuriTokens.neutral300,
      surfaceContainerLowest: light
          ? DashuriTokens.neutral0
          : const Color(0xFF0B0908),
      surfaceContainerLow: light
          ? DashuriTokens.neutral0
          : DashuriTokens.neutral900,
      surfaceContainer: light
          ? DashuriTokens.neutral50
          : DashuriTokens.neutral900,
      surfaceContainerHigh: light
          ? DashuriTokens.neutral100
          : DashuriTokens.neutral800,
      surfaceContainerHighest: light
          ? DashuriTokens.neutral200
          : DashuriTokens.neutral700,
      outline: light ? DashuriTokens.neutral300 : DashuriTokens.neutral600,
      outlineVariant: light
          ? DashuriTokens.neutral200
          : DashuriTokens.neutral800,
      inverseSurface: light
          ? DashuriTokens.neutral900
          : DashuriTokens.neutral50,
      onInverseSurface: light
          ? DashuriTokens.neutral50
          : DashuriTokens.neutral900,
      shadow: const Color(0xFF000000),
      scrim: const Color(0xFF000000),
    );
    final text = DashuriText.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
    );
    const minSize = Size(64, DashuriTokens.buttonHeight);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: text.titleMedium?.copyWith(fontSize: 17),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? DashuriTokens.neutral0 : DashuriTokens.neutral900,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: shape,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.bodyMedium,
        selectedColor: scheme.inverseSurface,
        secondaryLabelStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        unselectedLabelTextStyle: text.labelMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DashuriTokens.radiusXLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: null,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DashuriTokens.space5,
        ),
        minVerticalPadding: 12,
        titleTextStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }
}
