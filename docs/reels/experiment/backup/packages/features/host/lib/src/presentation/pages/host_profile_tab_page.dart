import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_profile_tab_cubit.dart';
import '../../domain/ports/host_photo_picker.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H23 host profile tab (RoutePaths.hostProfileTab, Profile tab).
///
/// "Switch to customer mode" needs the app shell's persisted mode, which the
/// host feature does not own. The route passes a [HostModeSwitch] from the
/// route `extra` or from GetIt; when neither exists the action is hidden.
class HostProfileTabPage extends StatelessWidget {
  const HostProfileTabPage({super.key, this.modeSwitch});

  final HostModeSwitch? modeSwitch;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocConsumer<HostProfileTabCubit, HostProfileTabState>(
        listenWhen: (a, b) => a.failure != b.failure && b.failure != null,
        listener: (context, state) {
          if (state.status == HostProfileTabStatus.loaded) {
            showHostSnack(context, hostFailureMessage(state.failure!));
          }
        },
        builder: (context, state) {
          final cubit = context.read<HostProfileTabCubit>();
          if (state.status == HostProfileTabStatus.loading) {
            return const LoadingView();
          }
          if (state.status == HostProfileTabStatus.failed) {
            return ErrorStateView(
              message: hostFailureMessage(state.failure!),
              onRetry: cubit.load,
            );
          }
          final profile = state.profile!;
          final host = state.host!;
          final theme = Theme.of(context);
          final header = HostCard(
            padding: const EdgeInsets.all(DashuriTokens.space5),
            child: Column(
              children: [
                UserAvatar(
                  name: profile.displayName,
                  url: profile.coverPhotoUrl,
                  radius: 44,
                ),
                const SizedBox(height: DashuriTokens.space3),
                Text(
                  profile.displayName,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: DashuriTokens.space2),
                Wrap(
                  spacing: DashuriTokens.space2,
                  runSpacing: DashuriTokens.space2,
                  alignment: WrapAlignment.center,
                  children: [
                    if (host.kycApproved)
                      const StatusTag(
                        label: 'Verified host',
                        tone: StatusTone.success,
                      ),
                    StatusTag(
                      label: 'Level ${profile.level}',
                      tone: StatusTone.neutral,
                    ),
                    StatusTag(
                      label: host.isAvailable ? 'Online' : 'Offline',
                      tone: host.isAvailable
                          ? StatusTone.online
                          : StatusTone.offline,
                      dot: true,
                    ),
                  ],
                ),
                const SizedBox(height: DashuriTokens.space4),
                HostStatCard(
                  label: 'Rate',
                  value: CurrencyAmount.diamonds(
                    host.ratePerMinute,
                    suffix: ' / min',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: DashuriTokens.space3),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.withParams(RoutePaths.hostProfile, {
                      'userId': profile.userId,
                    }),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Preview as customer'),
                ),
              ],
            ),
          );
          final links = HostLinkGroup(
            tiles: [
              HostLinkTile(
                icon: Icons.photo_library_outlined,
                title: 'Photos & bio',
                onTap: () => context.push(RoutePaths.hostProfileSetup),
              ),
              HostLinkTile(
                icon: Icons.diamond_outlined,
                title: 'My rate',
                onTap: () async {
                  await context.push(RoutePaths.hostRate);
                  await cubit.load();
                },
              ),
              HostLinkTile(
                icon: Icons.translate_rounded,
                title: 'Languages',
                trailingText: profile.languages.map(languageName).join(', '),
                onTap: () => context.push(RoutePaths.hostProfileSetup),
              ),
              HostLinkTile(
                icon: Icons.account_balance_outlined,
                title: 'Payout method',
                onTap: () => context.push(RoutePaths.hostPayoutMethod),
              ),
              HostLinkTile(
                icon: Icons.tune_rounded,
                title: 'Availability & free calls',
                onTap: () => context.go(HostPaths.availability),
              ),
              HostLinkTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () => context.push(RoutePaths.hostSettings),
              ),
            ],
          );
          final switchButton = modeSwitch == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: DashuriTokens.space5),
                  child: PrimaryButton(
                    label: 'Switch to customer mode',
                    icon: Icons.swap_horiz_rounded,
                    busy: state.status == HostProfileTabStatus.switching,
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Switch to customer mode?',
                        message: host.isAvailable
                            ? "We'll take you offline first, so customers "
                                  "can't call you while you browse."
                            : 'You can switch back to hosting any time from '
                                  'your profile.',
                        confirmLabel: 'Switch',
                      );
                      if (ok) {
                        await cubit.switchToCustomer(
                          modeSwitch!.switchToCustomer,
                        );
                      }
                    },
                  ),
                );
          return HostWideBody(
            onRefresh: cubit.load,
            children: [
              const HostLargeTitle('Profile'),
              HostCardGrid(
                columns: context.windowSize.isCompact ? 1 : 2,
                children: [
                  header,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [links, ?switchButton],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
