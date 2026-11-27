import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_dashboard_cubit.dart';
import '../../application/host_gifts_cubit.dart';
import '../../application/host_session_bloc.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';
import 'arrival_flow.dart';
import 'session_copy.dart';

/// Host Home's availability card, driven by the online-session state
/// ([HostSessionBloc]): offline, going online (arrival photo first), online
/// with its duration, a call ringing, connection problems, session ended
/// and "unavailable". The Free Call switch is part of the same card.
class HomeAvailabilityCard extends StatelessWidget {
  const HomeAvailabilityCard({
    required this.session,
    required this.dashboard,
    super.key,
  });

  final HostSessionState session;
  final HostDashboardStateLoaded dashboard;

  @override
  Widget build(BuildContext context) => switch (session) {
    HostSessionLoading() => const HostCard(
      child: SizedBox(height: 160, child: LoadingView()),
    ),
    HostSessionLoadFailed(:final failure) => HostCard(
      child: ErrorStateView(
        title: "Couldn't load your online status",
        message: hostFailureMessage(failure),
        onRetry: () =>
            context.read<HostSessionBloc>().add(const HostSessionStarted()),
      ),
    ),
    final HostSessionOnlineLike live => _OnlineCard(
      session: live,
      dashboard: dashboard,
    ),
    final HostSessionWithStatus other => _OfflineCard(
      session: other,
      dashboard: dashboard,
    ),
  };
}

class _FreeCallSwitch extends StatelessWidget {
  const _FreeCallSwitch({required this.dashboard});

  final HostDashboardStateLoaded dashboard;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: dashboard.data.freeCallOptIn,
    onChanged: dashboard.updating
        ? null
        : (v) => context.read<HostDashboardCubit>().setFreeCallOptIn(optIn: v),
    contentPadding: EdgeInsets.zero,
    secondary: const Icon(Icons.card_giftcard_rounded),
    title: const Text('Free Call Card calls'),
  );
}

/// Offline, going online/offline, session ended, unavailable.
class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.session, required this.dashboard});

  final HostSessionWithStatus session;
  final HostDashboardStateLoaded dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = DashuriColors.of(context).success;
    final light = theme.brightness == Brightness.light;
    final busy =
        session is HostSessionGoingOnline || session is HostSessionGoingOffline;
    final (title, message) = switch (session) {
      HostSessionGoingOnline() => (
        'Going online…',
        'Setting up your online session.',
      ),
      HostSessionGoingOffline() => (
        'Going offline…',
        'Ending your online session.',
      ),
      HostSessionSessionEnded(:final duration, :final reason) => (
        'Session ended',
        reason == SessionEndReason.endedByServer
            ? 'You were taken offline (no connection for a while). You were online for ${onlineDuration(duration)}.'
            : 'You were online for ${onlineDuration(duration)}. Your arrival photo for that session was removed.',
      ),
      HostSessionUnavailable(:final reason) => (
        "You can't go online right now",
        switch (reason) {
          UnavailableReason.notApproved =>
            'Hosting becomes available once your application is approved.',
          UnavailableReason.suspended =>
            'Hosting is suspended on this account.',
          UnavailableReason.restricted =>
            'Calls are restricted on this account right now.',
        },
      ),
      _ => ("You're offline", "Customers can't see or call you."),
    };
    final canGoOnline = session is! HostSessionUnavailable;
    return HostCard(
      padding: const EdgeInsets.all(DashuriTokens.space5),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainer,
            ),
            child: Icon(
              session is HostSessionUnavailable
                  ? Icons.block_rounded
                  : Icons.bedtime_outlined,
              size: 36,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: DashuriTokens.space1),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (canGoOnline) ...[
            const SizedBox(height: DashuriTokens.space5),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy || dashboard.updating
                    ? null
                    : () => context.read<HostSessionBloc>().add(
                        const HostSessionGoOnlinePressed(),
                      ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  // White on the base green is 4.0:1; these are ≥ 6:1
                  // (light) and ≥ 9:1 (dark).
                  backgroundColor: light ? DashuriTokens.successText : ok.icon,
                  foregroundColor: light
                      ? Colors.white
                      : DashuriTokens.neutral950,
                ),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radio_button_checked_rounded),
                label: Text(
                  session is HostSessionSessionEnded
                      ? 'Go online again'
                      : 'Go online',
                ),
              ),
            ),
            const SizedBox(height: DashuriTokens.space2),
            _FreeCallSwitch(dashboard: dashboard),
          ],
        ],
      ),
    );
  }
}

class _OnlineCard extends StatelessWidget {
  const _OnlineCard({required this.session, required this.dashboard});

  final HostSessionOnlineLike session;
  final HostDashboardStateLoaded dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<HostSessionBloc>();
    final s = session;
    final host = s.status;
    final ok = DashuriColors.of(context).success;
    final ringing = s is HostSessionRinging;
    final (title, subtitle) = switch (s) {
      HostSessionRinging() => ('Incoming call', null),
      HostSessionReconnecting() => ('Reconnecting…', null),
      HostSessionNetworkUnavailable() => ('No connection', null),
      _ => ("You're online", 'Waiting for calls · visible in Discover'),
    };
    return HostCard(
      color: s is HostSessionOnline ? ok.container : null,
      borderColor: s is HostSessionOnline
          ? ok.icon.withValues(alpha: .4)
          : null,
      padding: const EdgeInsets.all(DashuriTokens.space5),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(color: ok.icon, width: 2),
            ),
            child: Icon(
              ringing ? Icons.call_rounded : Icons.videocam_rounded,
              size: 36,
              color: ok.icon,
            ),
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: s is HostSessionOnline ? ok.onContainer : null,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DashuriTokens.space1),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: s is HostSessionOnline ? ok.onContainer : null,
              ),
            ),
          ],
          const SizedBox(height: DashuriTokens.space2),
          HomeTicker(
            builder: (context, now) => Semantics(
              label: 'Online for ${onlineDuration(now.difference(s.since))}',
              child: ExcludeSemantics(
                child: Text(
                  'Online for ${onlineDuration(now.difference(s.since))}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: s is HostSessionOnline ? ok.onContainer : null,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DashuriTokens.space3),
          Wrap(
            spacing: DashuriTokens.space2,
            runSpacing: DashuriTokens.space2,
            alignment: WrapAlignment.center,
            children: [
              if (host.level != null)
                Chip(
                  avatar: const Icon(Icons.star_rounded, size: 16),
                  label: Text('Level ${host.level}'),
                ),
              Chip(
                avatar: const DiamondIcon(size: 14),
                label: Text('${DashuriFormat.count(host.ratePerMinute)} / min'),
              ),
              if (host.isVerified) const VerifiedHostBadge(),
              // No "Free calls on/off" chip: the Free Call Card switch below
              // shows (and changes) the same setting (Phase 9).
            ],
          ),
          const SizedBox(height: DashuriTokens.space5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: ringing
                  ? null
                  : () => bloc.add(const HostSessionGoOfflinePressed()),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: theme.colorScheme.surface,
              ),
              child: const Text('Go offline'),
            ),
          ),
          if (ringing)
            const Padding(
              padding: EdgeInsets.only(top: DashuriTokens.space3),
              child: HostNotice(
                icon: Icons.call_rounded,
                message: 'A customer is calling — opening the call…',
              ),
            ),
          if (s is HostSessionReconnecting ||
              s is HostSessionNetworkUnavailable) ...[
            const SizedBox(height: DashuriTokens.space3),
            HostNotice(
              icon: Icons.wifi_off_rounded,
              tone: s is HostSessionNetworkUnavailable
                  ? StatusTone.error
                  : StatusTone.warning,
              message: s is HostSessionNetworkUnavailable
                  ? "You're not connected. You'll be taken offline if this continues."
                  : 'Connection problem — trying to stay online…',
            ),
            TextButton(
              onPressed: () => bloc.add(const HostSessionRetryPressed()),
              child: const Text('Retry now'),
            ),
          ],
          if (s case HostSessionOnline(
            :final notice,
          ) when notice != CallNotice.none) ...[
            const SizedBox(height: DashuriTokens.space3),
            HostNotice(
              message: switch (notice) {
                CallNotice.declined => "Call declined. You're still online.",
                CallNotice.missed => "You missed a call. You're still online.",
                _ => "Call ended. You're still online.",
              },
            ),
          ],
          const SizedBox(height: DashuriTokens.space2),
          _FreeCallSwitch(dashboard: dashboard),
        ],
      ),
    );
  }
}

/// The optional arrival photo of the current online session.
class HomeArrivalCard extends StatelessWidget {
  const HomeArrivalCard({required this.onRetake, super.key});

  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) => HostCard(
    child: HomeTicker(
      builder: (context, now) => ArrivalPhotoCard(now: now, onRetake: onRetake),
    ),
  );
}

/// Gifts received today and the latest few; "History" lists them all. Gifts
/// are an app-wide feature, so this is a normal Host Home card.
class HomeGiftsCard extends StatelessWidget {
  const HomeGiftsCard({super.key});

  @override
  Widget build(BuildContext context) => HostCard(
    child: BlocBuilder<HostGiftsCubit, HostGiftsState>(
      builder: (context, s) {
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LabelValueRow(
              label: Text('Gifts', style: theme.textTheme.titleLarge),
              value: TextButton(
                onPressed: () => context.push(RoutePaths.hostGifts),
                child: const Text('History'),
              ),
            ),
            const SizedBox(height: DashuriTokens.space2),
            switch (s) {
              HostGiftsLoaded(:final summary, :final items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${summary.todayGifts} gift${summary.todayGifts == 1 ? '' : 's'} today',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      CurrencyAmount.beans(
                        summary.todayBeans,
                        suffix: ' today',
                      ),
                    ],
                  ),
                  const SizedBox(height: DashuriTokens.space2),
                  if (items.isEmpty)
                    Text(
                      'Gifts customers send during calls will appear here.',
                      style: theme.textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: DashuriTokens.space2,
                      runSpacing: DashuriTokens.space2,
                      children: [
                        for (final g in items.take(8))
                          Tooltip(
                            message:
                                '${g.giftName} from ${g.senderName.isEmpty ? 'a customer' : g.senderName}',
                            child: Chip(
                              label: Text('${g.emoji} ${g.giftName}'),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              HostGiftsFailed() => Text(
                "Gifts couldn't load.",
                style: theme.textTheme.bodySmall,
              ),
              HostGiftsLoading() => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ],
        );
      },
    ),
  );
}

/// A short practical tip, rotating every couple of minutes.
class HomeTipCard extends StatelessWidget {
  const HomeTipCard({super.key});

  @override
  Widget build(BuildContext context) => HostCard(
    child: Row(
      children: [
        const Text('💡', style: TextStyle(fontSize: 22)),
        const SizedBox(width: DashuriTokens.space3),
        Expanded(
          child: Text(hostTips[(DateTime.now().minute ~/ 2) % hostTips.length]),
        ),
      ],
    ),
  );
}

/// Hosting and safety reminders with a link to the Host Agreement.
class HomeSafetyCard extends StatelessWidget {
  const HomeSafetyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hosting and safety', style: theme.textTheme.titleLarge),
          const SizedBox(height: DashuriTokens.space2),
          for (final r in safetyReminders)
            Padding(
              padding: const EdgeInsets.only(bottom: DashuriTokens.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 18),
                  const SizedBox(width: DashuriTokens.space2),
                  Expanded(child: Text(r, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          TextButton(
            onPressed: () => context.push('${RoutePaths.hostAgreement}?view=1'),
            child: const Text('Read the Host Agreement'),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds every second for display clocks (never billing).
class HomeTicker extends StatefulWidget {
  const HomeTicker({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<HomeTicker> createState() => _HomeTickerState();
}

class _HomeTickerState extends State<HomeTicker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, DateTime.now().toUtc());
}
