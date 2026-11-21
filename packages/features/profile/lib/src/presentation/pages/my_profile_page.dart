import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/my_profile_cubit.dart';
import '../../domain/entities/level_progress.dart';

/// S01 customer profile (Profile tab).
class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<MyProfileCubit, MyProfileState>(
          builder: (context, state) {
            final cubit = context.read<MyProfileCubit>();
            final header = Padding(
              padding: const EdgeInsets.only(
                top: DashuriTokens.space4,
                bottom: DashuriTokens.space4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Profile',
                        style: theme.textTheme.displaySmall,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Settings',
                    onPressed: () => context.push(RoutePaths.settings),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            );
            return switch (state) {
              MyProfileStateInitial() ||
              MyProfileStateLoading() => const LoadingView(),
              MyProfileStateFailed(:final failure) => ErrorStateView(
                message: failureMessage(failure),
                onRetry: cubit.load,
              ),
              final MyProfileStateLoaded s => RefreshIndicator(
                onRefresh: cubit.load,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final identity = [
                      _IdentityCard(state: s),
                      if (s.level != null) ...[
                        const SizedBox(height: DashuriTokens.space4),
                        _LevelCard(level: s.level!),
                      ],
                      const SizedBox(height: DashuriTokens.space4),
                      _DiamondsCard(diamonds: s.availableDiamonds),
                    ];
                    final menu = [_Menu(state: s)];
                    final wide = constraints.maxWidth >= 840;
                    return ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.pageGutter,
                        vertical: DashuriTokens.space2,
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: wide
                                  ? DashuriTokens.maxWideContentWidth
                                  : DashuriTokens.maxContentWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                header,
                                if (wide)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: identity,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: DashuriTokens.space6,
                                      ),
                                      Expanded(child: Column(children: menu)),
                                    ],
                                  )
                                else ...[
                                  ...identity,
                                  const SizedBox(height: DashuriTokens.space4),
                                  ...menu,
                                ],
                                const SizedBox(height: DashuriTokens.space6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.state});

  final MyProfileStateLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = state.data;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DashuriTokens.space5),
        child: Row(
          children: [
            UserAvatar(name: p.displayName, url: p.photoUrl, radius: 36),
            const SizedBox(width: DashuriTokens.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: theme.textTheme.headlineSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.city != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.city!.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: DashuriTokens.space2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${state.level?.level ?? p.level}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level});

  final LevelProgress level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = level.nextLevelXp;
    // Progress inside the current level, from server values only.
    final double? fraction = next == null || next <= level.currentLevelXp
        ? null
        : ((level.lifetimeXp - level.currentLevelXp) /
                  (next - level.currentLevelXp))
              .clamp(0, 1)
              .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DashuriTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Level ${level.level}',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  fraction == null
                      ? 'Top level'
                      : '${(fraction * 100).round()}% to Level ${level.level + 1}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: DashuriTokens.space3),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: fraction ?? 1,
                minHeight: 8,
                semanticsLabel: 'Level progress',
              ),
            ),
            const SizedBox(height: DashuriTokens.space3),
            Text(
              'Earn XP when you buy Diamonds.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiamondsCard extends StatelessWidget {
  const _DiamondsCard({required this.diamonds});

  final int? diamonds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: diamonds == null
          ? 'Wallet'
          : 'Wallet, ${DashuriFormat.count(diamonds!)} Diamonds',
      child: Material(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusXLarge),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [DashuriTokens.burgundy900, DashuriTokens.burgundy600],
            ),
          ),
          child: InkWell(
            onTap: () => context.go(RoutePaths.wallet),
            child: Padding(
              padding: const EdgeInsets.all(DashuriTokens.space5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DIAMONDS',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: DashuriTokens.burgundy200,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: CurrencyAmount.diamonds(
                              diamonds ?? 0,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: DashuriTokens.neutral0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: DashuriTokens.neutral0,
                      foregroundColor: DashuriTokens.neutral900,
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: () => context.push(RoutePaths.buyDiamonds),
                    icon: const Icon(Icons.add),
                    label: const Text('Buy'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.state});

  final MyProfileStateLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MyProfileCubit>();
    return Column(
      children: [
        SettingsGroup(
          children: [
            SettingsTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Edit profile',
              onTap: () => context.go(RoutePaths.editProfile),
            ),
            SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () => context.push(RoutePaths.notifications),
            ),
            SettingsTile(
              icon: Icons.lock_outline,
              title: 'Privacy & safety',
              onTap: () => context.push(RoutePaths.privacyMessaging),
            ),
            SettingsTile(
              icon: Icons.history,
              title: 'Call history',
              onTap: () => context.push(RoutePaths.callHistory),
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
        const SizedBox(height: DashuriTokens.space4),
        SettingsGroup(
          children: [
            if (state.hostModeAvailable)
              SettingsTile(
                icon: Icons.swap_horiz,
                title: 'Host mode',
                subtitle: 'Use the host dashboard to take calls',
                trailing: Switch(
                  value: state.mode == ExperienceMode.host,
                  onChanged: (on) async {
                    await cubit.setMode(
                      on ? ExperienceMode.host : ExperienceMode.customer,
                    );
                    if (context.mounted) {
                      context.go(
                        on ? RoutePaths.hostDashboard : RoutePaths.discovery,
                      );
                    }
                  },
                ),
              )
            else
              SettingsTile(
                icon: Icons.workspace_premium_outlined,
                title: 'Become a host',
                subtitle: 'Earn Beans for your time on video calls',
                onTap: () => context.push(RoutePaths.hostOnboarding),
              ),
          ],
        ),
      ],
    );
  }
}
