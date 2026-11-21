import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/settings_cubit.dart';
import '../widgets/settings_list.dart';

/// S03 settings hub. Destructive actions sit at the bottom.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final cubit = context.read<SettingsCubit>();
    final ok = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You can log back in any time with your phone number.',
      confirmLabel: 'Log out',
    );
    if (ok) await cubit.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<SettingsCubit, SettingsState>(
      listenWhen: (a, b) =>
          (b.export != null && a.export != b.export) ||
          (b.failure != null && a.failure != b.failure),
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.failure != null
                  ? failureMessage(state.failure!)
                  : "We're preparing a copy of your data. We'll notify you "
                        'when it is ready to download.',
            ),
          ),
        );
      },
      builder: (context, state) {
        final cubit = context.read<SettingsCubit>();
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SettingsList(
            children: [
              SettingsGroup(
                title: 'Account',
                children: [
                  SettingsTile(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Edit profile',
                    onTap: () => context.go(RoutePaths.editProfile),
                  ),
                  SettingsTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet & purchases',
                    onTap: () => context.go(RoutePaths.wallet),
                  ),
                  SettingsTile(
                    icon: Icons.history,
                    title: 'Call history',
                    onTap: () => context.push(RoutePaths.callHistory),
                  ),
                  if (state.hostModeAvailable)
                    SettingsTile(
                      icon: Icons.swap_horiz,
                      title: 'Host mode',
                      trailing: Switch(
                        value: state.mode == ExperienceMode.host,
                        onChanged: (on) async {
                          await cubit.setMode(
                            on ? ExperienceMode.host : ExperienceMode.customer,
                          );
                          if (context.mounted) {
                            context.go(
                              on
                                  ? RoutePaths.hostDashboard
                                  : RoutePaths.discovery,
                            );
                          }
                        },
                      ),
                    )
                  else
                    SettingsTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Become a host',
                      onTap: () => context.push(RoutePaths.hostOnboarding),
                    ),
                ],
              ),
              SettingsGroup(
                title: 'Privacy & safety',
                children: [
                  SettingsTile(
                    icon: Icons.mark_chat_read_outlined,
                    title: 'Who can message me',
                    value: state.whoCanMessage?.label,
                    onTap: () => context.push(RoutePaths.privacyMessaging),
                  ),
                  SettingsTile(
                    icon: Icons.block,
                    title: 'Blocked users',
                    onTap: () => context.push(RoutePaths.blockedUsers),
                  ),
                  SettingsTile(
                    icon: Icons.gpp_maybe_outlined,
                    title: 'Account status',
                    onTap: () => context.push(RoutePaths.enforcement),
                  ),
                  SettingsTile(
                    icon: Icons.download_outlined,
                    title: 'Download my data',
                    subtitle: 'Request a copy of your personal data',
                    trailing: state.exporting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: state.exporting ? null : cubit.requestDataExport,
                  ),
                ],
              ),
              SettingsGroup(
                title: 'App',
                children: [
                  SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    onTap: () => context.push(RoutePaths.notificationSettings),
                  ),
                  SettingsTile(
                    icon: Icons.support_outlined,
                    title: 'Help & support',
                    onTap: () => context.push(RoutePaths.helpSupport),
                  ),
                  SettingsTile(
                    icon: Icons.balance_outlined,
                    title: 'Legal',
                    onTap: () => context.push(RoutePaths.legal),
                  ),
                ],
              ),
              const SizedBox(height: DashuriTokens.space6),
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.logout,
                    title: 'Log out',
                    trailing: state.signingOut
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: state.signingOut ? null : () => _signOut(context),
                  ),
                  SettingsTile(
                    icon: Icons.delete_outline,
                    title: 'Delete account',
                    destructive: true,
                    onTap: () => context.push(RoutePaths.deleteAccount),
                  ),
                ],
              ),
              const SizedBox(height: DashuriTokens.space4),
              Text(
                'Dashuri',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
