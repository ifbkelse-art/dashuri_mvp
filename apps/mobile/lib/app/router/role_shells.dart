import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

/// One root tab of a role shell (FL06).
final class ShellTab {
  const ShellTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const customerTabs = [
  ShellTab(
    path: RoutePaths.discovery,
    label: 'Discover',
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  ShellTab(
    path: RoutePaths.conversations,
    label: 'Chats',
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
  ),
  ShellTab(
    path: RoutePaths.wallet,
    label: 'Wallet',
    icon: Icons.diamond_outlined,
    selectedIcon: Icons.diamond,
  ),
  ShellTab(
    path: RoutePaths.myProfile,
    label: 'Profile',
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle,
  ),
];

/// EXPERIMENT — the Reels tab, inserted after Discover when Reels is on.
const reelsTab = ShellTab(
  path: RoutePaths.reels,
  label: 'Reels',
  icon: Icons.play_circle_outline,
  selectedIcon: Icons.play_circle,
);

/// Customer tabs, with the Reels tab only when [reels] is true.
List<ShellTab> customerTabsFor({required bool reels}) => reels
    ? [customerTabs.first, reelsTab, ...customerTabs.skip(1)]
    : customerTabs;

const hostTabs = [
  ShellTab(
    path: RoutePaths.hostDashboard,
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  ShellTab(
    path: RoutePaths.hostCalls,
    label: 'Calls',
    icon: Icons.videocam_outlined,
    selectedIcon: Icons.videocam,
  ),
  ShellTab(
    path: RoutePaths.hostEarnings,
    label: 'Earnings',
    icon: Icons.savings_outlined,
    selectedIcon: Icons.savings,
  ),
  ShellTab(
    path: RoutePaths.hostProfileTab,
    label: 'Profile',
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle,
  ),
];

bool _under(String path, String root) =>
    path == root || path.startsWith('$root/');

/// The composed route table: two shells plus full-screen routes.
final class ComposedRoutes {
  const ComposedRoutes({
    required this.routes,
    required this.hostShellPaths,
    required this.missingTabs,
  });

  /// Full-screen routes first, then the customer and host shells.
  final List<RouteBase> routes;

  /// Full paths of every route inside the host shell.
  final Set<String> hostShellPaths;

  /// Tab paths no feature provided (shown as an error page, never a crash).
  final List<String> missingTabs;

  bool isHostShellLocation(String location) =>
      hostShellPaths.contains(location) ||
      hostTabs
          .where((t) => t.path != RoutePaths.hostDashboard)
          .any((t) => _under(location, t.path));
}

/// Collects tab routes by path from every [TabFeatureRoutes] feature and
/// places each in the branch whose tab path is its longest prefix. Tab
/// routes that fit no tab become full-screen routes. A tab nobody provides
/// gets an [ErrorStateView] page.
ComposedRoutes composeRoutes(
  List<FeatureRoutes> features, {
  bool reelsTab = false,
}) {
  final customer = customerTabsFor(reels: reelsTab);
  final allTabs = [...customer, ...hostTabs];
  final branchRoutes = {for (final t in allTabs) t.path: <RouteBase>[]};
  final fullScreen = <RouteBase>[];

  for (final feature in features) {
    if (feature is! TabFeatureRoutes) continue;
    for (final route in feature.tabRoutes) {
      final path = route is GoRoute ? route.path : null;
      final tab = path == null
          ? null
          : (allTabs.where((t) => _under(path, t.path)).toList()
                  ..sort((a, b) => b.path.length.compareTo(a.path.length)))
                .firstOrNull;
      (tab == null ? fullScreen : branchRoutes[tab.path]!).add(route);
    }
  }

  final tabPaths = <String>{
    for (final routes in branchRoutes.values)
      for (final r in routes)
        if (r is GoRoute) r.path,
  };
  for (final feature in features) {
    for (final route in feature.routes) {
      // A tab path registered again as full-screen would shadow the tab.
      if (route is GoRoute && tabPaths.contains(route.path)) continue;
      fullScreen.add(route);
    }
  }

  final missing = <String>[];
  StatefulShellBranch branch(ShellTab tab) {
    final routes = branchRoutes[tab.path]!;
    if (!routes.any((r) => r is GoRoute && r.path == tab.path)) {
      missing.add(tab.path);
      routes.insert(
        0,
        GoRoute(
          path: tab.path,
          builder: (context, state) => MissingTabPage(label: tab.label),
        ),
      );
    }
    return StatefulShellBranch(initialLocation: tab.path, routes: routes);
  }

  final customerShell = StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => RoleShell(tabs: customer, shell: shell),
    branches: [for (final t in customer) branch(t)],
  );
  final hostShell = StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => RoleShell(tabs: hostTabs, shell: shell),
    branches: [for (final t in hostTabs) branch(t)],
  );

  final hostPaths = <String>{};
  void collect(RouteBase r, String parent) {
    if (r is GoRoute) {
      final full = r.path.startsWith('/')
          ? r.path
          : '${parent == '/' ? '' : parent}/${r.path}';
      hostPaths.add(full);
      for (final c in r.routes) {
        collect(c, full);
      }
    }
  }

  for (final t in hostTabs) {
    for (final r in branchRoutes[t.path]!) {
      collect(r, '');
    }
  }

  return ComposedRoutes(
    routes: [...fullScreen, customerShell, hostShell],
    hostShellPaths: hostPaths,
    missingTabs: missing,
  );
}

/// The role shell around a [StatefulNavigationShell]: bottom bar on phones,
/// navigation rail on tablets ([AdaptiveShell]).
class RoleShell extends StatelessWidget {
  const RoleShell({required this.tabs, required this.shell, super.key});

  final List<ShellTab> tabs;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => AdaptiveShell(
    destinations: [
      for (final t in tabs)
        ShellDestination(
          icon: t.icon,
          selectedIcon: t.selectedIcon,
          label: t.label,
        ),
    ],
    selectedIndex: shell.currentIndex,
    onSelected: (i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex),
    body: shell,
  );
}

/// Shown in a tab whose feature has not registered its page.
class MissingTabPage extends StatelessWidget {
  const MissingTabPage({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(label)),
    body: ErrorStateView(
      title: '$label is not available yet',
      message: 'This section is not part of this build yet.',
    ),
  );
}
