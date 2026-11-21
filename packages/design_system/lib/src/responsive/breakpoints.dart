import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';

/// Material 3 window size classes. The designs are drawn at 390 pt
/// (compact); medium and expanded adapt them for large phones in landscape,
/// foldables, tablets and Chromebooks.
enum WindowSize {
  /// < 600 dp: phones in portrait. Bottom navigation bar, single column.
  compact,

  /// 600–839 dp: foldables, small tablets, phones in landscape. Navigation rail.
  medium,

  /// ≥ 840 dp: tablets, desktops. Extended navigation rail, two panes where useful.
  expanded;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) => width < 600
      ? WindowSize.compact
      : width < 840
      ? WindowSize.medium
      : WindowSize.expanded;

  bool get isCompact => this == WindowSize.compact;
  bool get isExpanded => this == WindowSize.expanded;
}

/// Responsive helpers derived from the window size.
extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => WindowSize.of(this);

  /// Horizontal page padding: 20 dp on phones (design gutter), more on larger windows.
  double get pageGutter => switch (windowSize) {
    WindowSize.compact => DashuriTokens.space5,
    WindowSize.medium => DashuriTokens.space8,
    WindowSize.expanded => DashuriTokens.space10,
  };

  /// Columns for card grids, from the available width (min card width 160 dp).
  int gridColumns(
    double availableWidth, {
    double minTileWidth = 160,
    int max = 6,
  }) => (availableWidth / minTileWidth).floor().clamp(2, max);
}

/// Centers [child] and caps its width so single-column layouts (forms,
/// settings, chat, payment) stay readable on tablets.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    required this.child,
    super.key,
    this.maxWidth = DashuriTokens.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;

  /// Defaults to horizontal [ResponsiveContext.pageGutter].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding:
            padding ?? EdgeInsets.symmetric(horizontal: context.pageGutter),
        child: child,
      ),
    ),
  );
}

/// Shows [primary] alone on compact/medium windows and side by side with
/// [secondary] on expanded windows (e.g. chat inbox + conversation).
class TwoPane extends StatelessWidget {
  const TwoPane({
    required this.primary,
    required this.secondary,
    super.key,
    this.primaryWidth = 360,
  });

  final Widget primary;
  final Widget? secondary;
  final double primaryWidth;

  @override
  Widget build(BuildContext context) {
    if (!context.windowSize.isExpanded || secondary == null) return primary;
    return Row(
      children: [
        SizedBox(width: primaryWidth, child: primary),
        const VerticalDivider(width: 1),
        Expanded(child: secondary!),
      ],
    );
  }
}
