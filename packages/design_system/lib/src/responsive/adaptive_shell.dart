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
    super.key,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget body;

  Widget _icon(IconData icon, int badge) =>
      badge > 0 ? Badge.count(count: badge, child: Icon(icon)) : Icon(icon);

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size.isCompact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
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
