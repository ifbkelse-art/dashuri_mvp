import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_application_cubit.dart';
import '../../application/host_application_flow.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/ports/host_photo_picker.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H01 host introduction and H02 verification steps (RoutePaths.hostOnboarding).
class HostOnboardingPage extends StatelessWidget {
  const HostOnboardingPage({super.key, this.hostModeEnter});

  /// Enters host mode once approved (see [HostModeEnter]).
  final HostModeEnter? hostModeEnter;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HostApplicationCubit, HostApplicationState>(
    listenWhen: (a, b) =>
        a.appliedNow != b.appliedNow || a.failure != b.failure,
    listener: (context, state) {
      // A failed application is shown inline above the button (below): a
      // floating SnackBar over the tall bottom bar could end up off screen
      // at large text sizes, and this message must not vanish.
      if (state.appliedNow) context.go(RoutePaths.hostAgreement);
    },
    builder: (context, state) {
      final cubit = context.read<HostApplicationCubit>();
      final Widget body;
      Widget? bottom;
      switch (state.status) {
        case HostApplicationStatus.loading:
          body = const LoadingView();
        case HostApplicationStatus.loadFailed:
          body = ErrorStateView(
            message: hostFailureMessage(state.failure!),
            onRetry: cubit.load,
          );
        case HostApplicationStatus.ready || HostApplicationStatus.submitting:
          final host = state.host ?? HostStatus.notApplied;
          if (!host.hasApplied) {
            body = const _Intro();
            final failure = state.status == HostApplicationStatus.ready
                ? state.failure
                : null;
            bottom = HostBottomBar(
              children: [
                if (failure != null) ...[
                  InfoBanner(
                    tone: InfoBannerTone.error,
                    icon: Icons.info_outline,
                    message: hostFailureMessage(failure),
                  ),
                  const SizedBox(height: DashuriTokens.space3),
                ],
                PrimaryButton(
                  label: 'Start application',
                  busy: state.status == HostApplicationStatus.submitting,
                  onPressed: cubit.apply,
                ),
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  'Women 18+ · Government ID and selfie verification required',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          } else {
            body = _Steps(host: host);
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () async {
                    final router = GoRouter.of(context);
                    // Approved: enter host mode first, or the router sends
                    // the new host back to Discover (stale account).
                    if (state.nextStep == HostApplicationStep.approved) {
                      await hostModeEnter?.enter();
                    }
                    router.go(_routeFor(state.nextStep));
                  },
                ),
              ],
            );
          }
      }
      return Scaffold(
        appBar: AppBar(),
        body: body,
        bottomNavigationBar: bottom,
      );
    },
  );

  static String _routeFor(HostApplicationStep step) => switch (step) {
    HostApplicationStep.apply => RoutePaths.hostOnboarding,
    HostApplicationStep.agreement => RoutePaths.hostAgreement,
    HostApplicationStep.verification ||
    HostApplicationStep.review ||
    HostApplicationStep.attention => RoutePaths.hostVerification,
    HostApplicationStep.approved => RoutePaths.hostDashboard,
    HostApplicationStep.suspended => RoutePaths.enforcement,
  };
}

class _Intro extends StatelessWidget {
  const _Intro();

  static const _points = [
    (
      Icons.toggle_on_outlined,
      'Go online whenever you like',
      'No schedules, no quotas. Accept or decline any call.',
    ),
    (
      null,
      'Earn Beans every second',
      "Paid for every second you're on a call, at the rate you set.",
    ),
    (
      Icons.account_balance_outlined,
      'Withdraw weekly',
      'To your own bank account or UPI ID once payouts launch. Minimum ₹500.',
    ),
    (
      Icons.verified_user_outlined,
      'Safety first',
      'End any call instantly. Report and block in one tap.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostFormBody(
      children: [
        Text(
          'HOST ON DASHURI',
          style: theme.textTheme.labelMedium?.copyWith(
            // goldDark is 3.9:1 on the dark surface; secondary is the
            // theme's gold (≥ 4.7:1 in both modes).
            color: theme.colorScheme.secondary,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text('Your time, your terms.', style: theme.textTheme.displaySmall),
        const SizedBox(height: DashuriTokens.space6),
        for (final (icon, title, body) in _points)
          Padding(
            padding: const EdgeInsets.only(bottom: DashuriTokens.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      DashuriTokens.radiusMedium,
                    ),
                  ),
                  child: Center(
                    child: icon == null
                        ? const BeanIcon(size: 22)
                        : Icon(icon, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: DashuriTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(body, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.host});

  final HostStatus host;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TimelineState s(bool done, bool current) => done
        ? TimelineState.done
        : current
        ? TimelineState.current
        : TimelineState.pending;
    final agreementDone = !host.kycNotStarted;
    return HostFormBody(
      children: [
        Text(
          "Let's verify it's really you",
          style: theme.textTheme.displaySmall,
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          'Every host is verified. It keeps you and the community safe. '
          'You can leave and come back to any step.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DashuriTokens.space5),
        HostCard(
          child: Column(
            children: [
              HostTimelineStep(
                title: 'Application',
                subtitle: 'Submitted',
                state: s(host.hasApplied, false),
              ),
              HostTimelineStep(
                title: 'Host agreement',
                subtitle: 'Read and accept',
                state: s(agreementDone, !agreementDone),
              ),
              HostTimelineStep(
                title: 'Identity verification',
                subtitle: host.kycRejected
                    ? 'Needs attention'
                    : 'Government ID, PAN and a live selfie, checked by our team',
                state: s(
                  host.kycApproved,
                  host.kycInProgress || host.kycRejected,
                ),
              ),
              HostTimelineStep(
                title: 'Profile & rate',
                subtitle: 'Photos, bio, languages and your rate',
                state: s(host.isApproved, agreementDone && !host.isApproved),
              ),
              HostTimelineStep(
                title: 'Ready to host',
                subtitle: 'You can go online',
                state: s(host.isApproved, false),
              ),
            ],
          ),
        ),
        const SizedBox(height: DashuriTokens.space4),
        Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DashuriTokens.space2),
            Expanded(
              child: Text(
                'Your documents are never shown to customers.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
