import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/arrival_photo_cubit.dart';
import '../../application/host_dashboard_cubit.dart';
import '../../application/host_gifts_cubit.dart';
import '../../application/host_session_bloc.dart';
import '../../domain/entities/host_earnings.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/entities/host_verification.dart';
import '../host_paths.dart';
import '../session/arrival_flow.dart';
import '../session/home_session_widgets.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';
import 'host_rate_page.dart';

/// H11/H12 host home (RoutePaths.hostDashboard, Home tab). It owns the whole
/// online experience: go online (with the optional arrival photo), how long
/// you have been online, gifts received, notices after a call and
/// connection problems. Incoming calls are handled app-wide by the
/// video-call feature.
class HostDashboardPage extends StatefulWidget {
  const HostDashboardPage({
    super.key,
    this.arrivalEnabled = false,
    this.giftsEnabled = false,
    this.after = CallNotice.none,
  });

  /// An [ArrivalPhotoCubit] is provided (DASHURI_ARRIVAL_PHOTOS_ENABLED).
  final bool arrivalEnabled;

  /// A [HostGiftsCubit] is provided (DASHURI_GIFTS_ENABLED).
  final bool giftsEnabled;

  /// What just happened, from `?after=` when the call screen sends the host
  /// back (declined, missed).
  final CallNotice after;

  @override
  State<HostDashboardPage> createState() => _HostDashboardPageState();
}

bool _listed(HostSessionState s) =>
    s is HostSessionOnlineLike || s is HostSessionGoingOffline;

class _HostDashboardPageState extends State<HostDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Heartbeats pause while the app is in the background.
    context.read<HostDashboardCubit>().attachLifecycle();
    // Gifts are app-wide: load them whether or not the host is online.
    if (widget.giftsEnabled) unawaited(context.read<HostGiftsCubit>().load());
  }

  bool? _visible;

  // Host Home lives in an IndexedStack shell, so returning from a call
  // reuses this page: its blocs are NOT recreated. Without a re-sync the
  // session stayed on "Incoming call" after the ring was declined, missed
  // or answered, and the after-call notice never showed (2026-11-27).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (_visible == false &&
        visible &&
        context.read<HostSessionBloc>().state is HostSessionRinging) {
      _resync();
    }
    _visible = visible;
  }

  @override
  void didUpdateWidget(HostDashboardPage old) {
    super.didUpdateWidget(old);
    if (old.after != widget.after) _resync();
  }

  /// Re-reads the session from the server, with the after-call notice.
  void _resync() {
    context.read<HostSessionBloc>().add(
      HostSessionStarted(after: widget.after),
    );
    unawaited(context.read<HostDashboardCubit>().refresh());
  }

  /// Go online: the optional arrival photo first, then online. Skipping the
  /// photo never blocks going online.
  Future<void> _activate() async {
    final bloc = context.read<HostSessionBloc>();
    if (!widget.arrivalEnabled) {
      bloc.add(const HostSessionActivationProceed());
      return;
    }
    final arrival = context.read<ArrivalPhotoCubit>()..prompt();
    var done = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => BlocProvider.value(
        value: arrival,
        child: ArrivalPromptSheet(
          onDone: () {
            done = true;
            Navigator.of(sheet).pop();
          },
        ),
      ),
    );
    if (!mounted) return;
    bloc.add(
      done
          ? const HostSessionActivationProceed()
          : const HostSessionActivationCancelled(),
    );
  }

  Future<void> _retake() async {
    final arrival = context.read<ArrivalPhotoCubit>();
    await arrival.capture();
    if (!mounted || arrival.state is! ArrivalPreview) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => BlocProvider.value(
        value: arrival,
        child: ArrivalPromptSheet(onDone: () => Navigator.of(sheet).pop()),
      ),
    );
    if (arrival.state is ArrivalConfirmed) await arrival.upload();
    if (arrival.state is ArrivalSkipped || arrival.state is ArrivalPrompt) {
      await arrival.load();
    }
  }

  void _onSession(BuildContext context, HostSessionState s) {
    switch (s) {
      case HostSessionGoingOnline(activating: false):
        unawaited(_activate());
      case HostSessionOnline():
        if (widget.arrivalEnabled) {
          final arrival = context.read<ArrivalPhotoCubit>();
          if (arrival.state is ArrivalConfirmed) {
            unawaited(arrival.upload());
          } else if (arrival.state is ArrivalIdle ||
              arrival.state is ArrivalSkipped) {
            unawaited(arrival.load());
          }
        }
        if (s.failure != null) {
          showHostSnack(context, hostFailureMessage(s.failure!));
        }
      case HostSessionOffline(:final failure?):
        showHostSnack(context, hostFailureMessage(failure));
      default:
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<HostDashboardCubit, HostDashboardState>(
        listenWhen: (a, b) =>
            b is HostDashboardStateLoaded &&
            b.actionFailure != null &&
            (a is! HostDashboardStateLoaded ||
                a.actionFailure != b.actionFailure),
        listener: (context, state) => showHostSnack(
          context,
          hostFailureMessage(
            (state as HostDashboardStateLoaded).actionFailure!,
          ),
        ),
      ),
      BlocListener<HostSessionBloc, HostSessionState>(listener: _onSession),
      // Home's own retry succeeded after the session could not load: start
      // the session again so the availability card is not left on an error.
      BlocListener<HostDashboardCubit, HostDashboardState>(
        listenWhen: (a, b) =>
            a is! HostDashboardStateLoaded && b is HostDashboardStateLoaded,
        listener: (context, _) {
          if (context.read<HostSessionBloc>().state is HostSessionLoadFailed) {
            context.read<HostSessionBloc>().add(const HostSessionStarted());
          }
        },
      ),
      // Keep the header dot, pricing and earnings in step when the session
      // goes online or offline.
      BlocListener<HostSessionBloc, HostSessionState>(
        // "Going offline" still counts as online: the server has not
        // confirmed yet, so re-reading status then would show a stale dot.
        listenWhen: (a, b) => _listed(a) != _listed(b),
        listener: (context, _) =>
            unawaited(context.read<HostDashboardCubit>().refresh()),
      ),
    ],
    child: BlocBuilder<HostDashboardCubit, HostDashboardState>(
      builder: (context, state) {
        final cubit = context.read<HostDashboardCubit>();
        return Scaffold(
          body: SafeArea(
            child: switch (state) {
              HostDashboardStateInitial() ||
              HostDashboardStateLoading() => const LoadingView(),
              HostDashboardStateFailed(:final failure) => ErrorStateView(
                title: "Couldn't load Host Home",
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
                    BlocBuilder<HostSessionBloc, HostSessionState>(
                      builder: (context, session) => HostCardGrid(
                        children: [
                          HomeAvailabilityCard(
                            session: session,
                            dashboard: loaded,
                          ),
                          if (widget.arrivalEnabled &&
                              session is HostSessionOnlineLike)
                            HomeArrivalCard(
                              onRetake: () => unawaited(_retake()),
                            ),
                          if (widget.giftsEnabled) const HomeGiftsCard(),
                          _TodayCard(host: loaded.data),
                          _PricingCard(host: loaded.data),
                          _QuickLinks(host: loaded.data),
                          const HomeTipCard(),
                          const HomeSafetyCard(),
                        ],
                      ),
                    ),
                ],
              ),
            },
          ),
        );
      },
    ),
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
                        ? DashuriColors.of(context).onlineDot
                        : Theme.of(context).colorScheme.outline,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
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

/// Verified Host status, level, current price, max eligible price, the next
/// level's ceiling and the Verified Host call to action (2026-11-23). All
/// numbers come from GET /v1/host; the app computes none of them.
class _PricingCard extends StatelessWidget {
  const _PricingCard({required this.host});

  final HostStatus host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HostDashboardCubit>();
    final levelMax = host.levelMaxRatePerMinute;
    final next = host.nextLevelMaxRatePerMinute;
    return HostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabelValueRow(
            label: Text('Pricing', style: theme.textTheme.titleLarge),
            value: host.isVerified
                ? const VerifiedHostBadge()
                : StatusTag(
                    label: VerificationStatuses.label(host.verificationStatus),
                    tone: StatusTone.neutral,
                  ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          HostCardGrid(
            columns: 2,
            children: [
              HostStatCard(
                label: 'Your price',
                value: CurrencyAmount.diamonds(
                  host.ratePerMinute,
                  style: theme.textTheme.headlineSmall,
                ),
                caption: 'per minute',
              ),
              HostStatCard(
                label: 'Max you can set',
                value: CurrencyAmount.diamonds(
                  host.maxRatePerMinute,
                  style: theme.textTheme.headlineSmall,
                ),
                caption: host.level == null
                    ? 'per minute'
                    : 'Level ${host.level}'
                          '${levelMax == null ? '' : ' · level limit ${DashuriFormat.count(levelMax)}'}',
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: DashuriTokens.space2),
            Text(
              'Next level: up to ${DashuriFormat.count(next)} Diamonds/minute'
              '${!host.isVerified && next > host.verifiedRateThreshold ? ' (Verified Hosts only above ${DashuriFormat.count(host.verifiedRateThreshold)})' : ''}.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (!host.isVerified) ...[
            const SizedBox(height: DashuriTokens.space3),
            VerifiedHostCta(
              onPressed: () async {
                await context.push(RoutePaths.hostVerifiedHost);
                await cubit.refresh();
              },
            ),
          ],
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
