import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

import '../host_paths.dart';
import '../widgets/host_widgets.dart';

/// H24 host settings (RoutePaths.hostSettings). Host-only rows plus links to
/// the shared settings sections owned by the settings feature.
class HostSettingsPage extends StatelessWidget {
  const HostSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    void push(String path) => context.push(path);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: HostFormBody(
        children: [
          HostLinkGroup(
            title: 'Hosting',
            tiles: [
              HostLinkTile(
                icon: Icons.tune_rounded,
                title: 'Availability & free calls',
                onTap: () => context.go(HostPaths.availability),
              ),
              HostLinkTile(
                icon: Icons.diamond_outlined,
                title: 'My rate',
                onTap: () => push(RoutePaths.hostRate),
              ),
              HostLinkTile(
                icon: Icons.account_balance_outlined,
                title: 'Payout method',
                onTap: () => push(RoutePaths.hostPayoutMethod),
              ),
              HostLinkTile(
                icon: Icons.receipt_long_outlined,
                title: 'Payout history',
                onTap: () => push(RoutePaths.hostPayoutHistory),
              ),
              HostLinkTile(
                icon: Icons.description_outlined,
                title: 'Host agreement',
                subtitle: 'Draft — pending legal review',
                onTap: () => push(
                  '${RoutePaths.hostAgreement}?${HostPaths.viewParam}=1',
                ),
              ),
            ],
          ),
          HostLinkGroup(
            title: 'Privacy & safety',
            tiles: [
              HostLinkTile(
                icon: Icons.mark_chat_read_outlined,
                title: 'Who can message me',
                onTap: () => push(RoutePaths.privacyMessaging),
              ),
              HostLinkTile(
                icon: Icons.block_rounded,
                title: 'Blocked users',
                onTap: () => push(RoutePaths.blockedUsers),
              ),
              HostLinkTile(
                icon: Icons.shield_outlined,
                title: 'Account status',
                onTap: () => push(RoutePaths.enforcement),
              ),
            ],
          ),
          HostLinkGroup(
            title: 'App',
            tiles: [
              HostLinkTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => push(RoutePaths.notificationSettings),
              ),
              HostLinkTile(
                icon: Icons.support_outlined,
                title: 'Help & support',
                onTap: () => push(RoutePaths.helpSupport),
              ),
              HostLinkTile(
                icon: Icons.gavel_rounded,
                title: 'Legal',
                onTap: () => push(RoutePaths.legal),
              ),
              HostLinkTile(
                icon: Icons.settings_outlined,
                title: 'Account & log out',
                onTap: () => push(RoutePaths.settings),
              ),
            ],
          ),
          const SizedBox(height: DashuriTokens.space5),
          TextButton(
            onPressed: () => push(RoutePaths.deleteAccount),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete account'),
          ),
          Text(
            "Accounts with Beans on hold, available or pending payout can't be "
            'deleted until those are settled.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
