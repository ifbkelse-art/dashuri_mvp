import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// One destination of a top-level shell (Discover, Chats, Wallet, Profile…).
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
}

/// The app's role shells (customer and host, design FL06). Bottom navigation
/// bar on compact windows; navigation rail on medium; extended rail on
/// expanded windows. Content keeps its own scroll and width constraints.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.body,
    this.overlayBar = false,
    super.key,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  /// Compact windows only: the bottom bar goes transparent (light icons over
  /// a soft dark scrim) and the body is drawn behind it, edge to edge. Used
  /// by full-screen video such as Reels, which keeps its own controls clear
  /// of the bar through the inset the Scaffold reports.
  final bool overlayBar;

  Widget _icon(IconData icon, int badge) =>
      badge > 0 ? Badge.count(count: badge, child: Icon(icon)) : Icon(icon);

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size.isCompact) {
      final bar = NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: _icon(d.icon, d.badgeCount),
              selectedIcon: _icon(d.selectedIcon, d.badgeCount),
              label: d.label,
            ),
        ],
      );
      if (!overlayBar) {
        return Scaffold(body: body, bottomNavigationBar: bar);
      }
      const onVideo = Colors.white;
      final theme = Theme.of(context);
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.black,
        body: body,
        bottomNavigationBar: DecoratedBox(
          key: const Key('overlay-nav-bar'),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x99000000)],
            ),
          ),
          child: Theme(
            data: theme.copyWith(
              navigationBarTheme: theme.navigationBarTheme.copyWith(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                indicatorColor: Colors.white24,
                iconTheme: WidgetStateProperty.all(
                  const IconThemeData(color: onVideo),
                ),
                labelTextStyle: WidgetStateProperty.all(
                  (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
                    color: onVideo,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            child: bar,
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        right: false,
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              extended: size.isExpanded,
              labelType: size.isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: _icon(d.icon, d.badgeCount),
                    selectedIcon: _icon(d.selectedIcon, d.badgeCount),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
