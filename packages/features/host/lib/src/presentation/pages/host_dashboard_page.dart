import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_dashboard_cubit.dart';
import '../../domain/entities/host_earnings.dart';
import '../../domain/entities/host_status.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H11/H12 host home (RoutePaths.hostDashboard, Home tab). Incoming calls are
/// handled app-wide by the video-call feature.
class HostDashboardPage extends StatefulWidget {
  const HostDashboardPage({super.key});

  @override
  State<HostDashboardPage> createState() => _HostDashboardPageState();
}

class _HostDashboardPageState extends State<HostDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Heartbeats pause while the app is in the background.
    context.read<HostDashboardCubit>().attachLifecycle();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HostDashboardCubit, HostDashboardState>(
    listenWhen: (a, b) =>
        b is HostDashboardStateLoaded &&
        b.actionFailure != null &&
        (a is! HostDashboardStateLoaded || a.actionFailure != b.actionFailure),
    listener: (context, state) => showHostSnack(
      context,
      hostFailureMessage((state as HostDashboardStateLoaded).actionFailure!),
    ),
    builder: (context, state) {
      final cubit = context.read<HostDashboardCubit>();
      return Scaffold(
        body: SafeArea(
          child: switch (state) {
            HostDashboardStateInitial() ||
            HostDashboardStateLoading() => const LoadingView(),
            HostDashboardStateFailed(:final failure) => ErrorStateView(
              message: hostFailureMessage(failure),
              onRetry: cubit.load,
            ),
            final HostDashboardStateLoaded loaded => HostWideBody(
              onRefresh: cubit.refresh,
              children: [
                _Header(state: loaded),
                if (!loaded.data.isApproved)
                  _ApplicationCard(host: loaded.data)
                else
                  HostCardGrid(
                    children: [
                      _AvailabilityCard(state: loaded),
                      _TodayCard(host: loaded.data),
                      _QuickLinks(host: loaded.data),
                    ],
                  ),
              ],
            ),
          },
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final HostDashboardStateLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = state.profile?.displayName ?? '';
    final online = state.data.isAvailable;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space4),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(
                name: name.isEmpty ? 'Host' : name,
                url: state.profile?.coverPhotoUrl,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: online
                        ? DashuriTokens.online
                        : DashuriTokens.neutral400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: DashuriTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: theme.textTheme.bodySmall),
                Text(
                  name.isEmpty ? 'Host home' : name,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton.outlined(
            tooltip: 'Earnings',
            onPressed: () => context.go(RoutePaths.hostEarnings),
            icon: const BeanIcon(size: 20),
          ),
          const SizedBox(width: DashuriTokens.space2),
          IconButton.outlined(
            tooltip: 'Notifications',
            onPressed: () => context.push(RoutePaths.notifications),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.host});

  final HostStatus host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body, label, route) = switch (host) {
      HostStatus(hasApplied: false) => (
        'Become a host',
        'Apply to host, get verified and start earning Beans.',
        'Start application',
        RoutePaths.hostOnboarding,
      ),
      HostStatus(isSuspended: true) => (
        'Hosting is suspended',
        "You can't go online while your host account is suspended.",
        'View account status',
        RoutePaths.enforcement,
      ),
      HostStatus(kycRejected: true) => (
        'Verification needs attention',
        "Our team couldn't complete your identity check.",
        'See what to do',
        RoutePaths.hostVerification,
      ),
      _ => (
        'Your application is in review',
        "We'll notify you as soon as you can go online.",
        'View status',
        RoutePaths.hostVerification,
      ),
    };
    return ResponsiveCenter(
      padding: EdgeInsets.zero,
      child: HostCard(
        padding: const EdgeInsets.all(DashuriTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: DashuriTokens.space2),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: DashuriTokens.space5),
            PrimaryButton(label: label, onPressed: () => context.push(route)),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.state});

  final HostDashboardStateLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HostDashboardCubit>();
    final host = state.data;
    final online = host.isAvailable;
    return HostCard(
      color: online ? DashuriTokens.success100 : null,
      borderColor: online ? DashuriTokens.success.withValues(alpha: .3) : null,
      padding: const EdgeInsets.all(DashuriTokens.space5),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? Colors.white : theme.colorScheme.surfaceContainer,
              border: online
                  ? Border.all(color: DashuriTokens.success, width: 2)
                  : null,
            ),
            child: Icon(
              online ? Icons.videocam_rounded : Icons.bedtime_outlined,
              size: 36,
              color: online
                  ? DashuriTokens.success
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(
            online ? "You're online" : "You're offline",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: online ? DashuriTokens.success : null,
            ),
          ),
          const SizedBox(height: DashuriTokens.space1),
          Text(
            online
                ? 'Waiting for calls · visible in Discover'
                : "Customers can't see or call you.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (online) ...[
            const SizedBox(height: DashuriTokens.space3),
            Wrap(
              spacing: DashuriTokens.space2,
              runSpacing: DashuriTokens.space2,
              alignment: WrapAlignment.center,
              children: [
                Chip(
                  avatar: const DiamondIcon(size: 14),
                  label: Text(
                    '${DashuriFormat.count(host.ratePerMinute)} / min',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.card_giftcard_rounded, size: 16),
                  label: Text(
                    host.freeCallOptIn ? 'Free calls on' : 'Free calls off',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DashuriTokens.space5),
          Semantics(
            toggled: online,
            child: SizedBox(
              width: double.infinity,
              child: online
                  ? OutlinedButton(
                      onPressed: state.updating
                          ? null
                          : () => cubit.setAvailable(available: false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.white,
                      ),
                      child: Text(state.updating ? 'Updating…' : 'Go offline'),
                    )
                  : FilledButton.icon(
                      onPressed: state.updating
                          ? null
                          : () => cubit.setAvailable(available: true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: DashuriTokens.success,
                        foregroundColor: Colors.white,
                      ),
                      icon: state.updating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.radio_button_checked_rounded),
                      label: const Text('Go online'),
                    ),
            ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          SwitchListTile(
            value: host.freeCallOptIn,
            onChanged: state.updating
                ? null
                : (v) => cubit.setFreeCallOptIn(optIn: v),
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.card_giftcard_rounded),
            title: const Text('Free Call Card calls'),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.host});

  final HostStatus host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beans = host.todayEarnedBeans;
    final calls = host.todayCalls;
    return HostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabelValueRow(
            label: Text('Today', style: theme.textTheme.titleLarge),
            value: TextButton(
              onPressed: () => context.go(RoutePaths.hostEarnings),
              child: const Text(
                'Earnings',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          HostCardGrid(
            columns: 2,
            children: [
              HostStatCard(
                label: 'Earned',
                value: beans == null
                    ? const Text('—')
                    : CurrencyAmount.beans(
                        beans,
                        style: theme.textTheme.headlineSmall,
                      ),
                caption: beans == null
                    ? 'Not available yet'
                    : HostFormat.approxRupees(BeanRules.beansToPaise(beans)),
              ),
              HostStatCard(
                label: 'Calls',
                value: Text(calls == null ? '—' : '$calls'),
                caption: calls == null ? 'Not available yet' : 'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks({required this.host});

  final HostStatus host;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HostDashboardCubit>();
    return HostLinkGroup(
      tiles: [
        HostLinkTile(
          icon: Icons.manage_accounts_outlined,
          title: 'Edit profile & photos',
          onTap: () => context.push(RoutePaths.hostProfileSetup),
        ),
        HostLinkTile(
          icon: Icons.diamond_outlined,
          title: 'Change my rate',
          trailingText: '${DashuriFormat.count(host.ratePerMinute)} / min',
          onTap: () async {
            await context.push(RoutePaths.hostRate);
            await cubit.refresh();
          },
        ),
        HostLinkTile(
          icon: Icons.tune_rounded,
          title: 'Availability settings',
          onTap: () async {
            await context.push(HostPaths.availability);
            await cubit.refresh();
          },
        ),
      ],
    );
  }
}
