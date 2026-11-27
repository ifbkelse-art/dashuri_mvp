import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_application_flow.dart';
import '../../application/host_verification_cubit.dart';
import '../../domain/entities/host_status.dart';
import '../../domain/ports/host_photo_picker.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H03–H05 identity verification (manual review in the MVP), H07 under
/// review and H08 needs attention (RoutePaths.hostVerification).
///
/// The KYC vendor is unresolved. The MVP backend uses a manual provider:
/// starting a session puts the host in a staff review queue. No documents
/// are collected here, because no document endpoint exists.
class HostVerificationPage extends StatefulWidget {
  const HostVerificationPage({super.key, this.hostModeEnter});

  /// Enters host mode once approved (see [HostModeEnter]).
  final HostModeEnter? hostModeEnter;

  @override
  State<HostVerificationPage> createState() => _HostVerificationPageState();
}

class _HostVerificationPageState extends State<HostVerificationPage> {
  /// True when the session was started from the first-time step, so the
  /// flow continues to profile setup (a restart after H08 stays here).
  bool _firstStart = false;
  bool _entering = false;

  /// Approved: refresh the account and select host mode before going home,
  /// so the router does not bounce the new host back to Discover.
  Future<void> _goToHostHome() async {
    final router = GoRouter.of(context);
    setState(() => _entering = true);
    try {
      await widget.hostModeEnter?.enter();
    } finally {
      if (mounted) setState(() => _entering = false);
    }
    router.go(RoutePaths.hostDashboard);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HostVerificationCubit, HostVerificationState>(
    listenWhen: (a, b) =>
        a.sessionStartedNow != b.sessionStartedNow || a.failure != b.failure,
    listener: (context, state) {
      if (state.sessionStartedNow && _firstStart) {
        context.go(HostPaths.inApplication(RoutePaths.hostProfileSetup));
      } else if (state.status == HostVerificationStatus.ready &&
          state.failure != null) {
        showHostSnack(context, hostFailureMessage(state.failure!));
      }
    },
    builder: (context, state) {
      final cubit = context.read<HostVerificationCubit>();
      final host = state.host;
      final starting = state.status == HostVerificationStatus.starting;
      Widget body;
      Widget? bottom;
      if (state.status == HostVerificationStatus.loading) {
        body = const LoadingView();
      } else if (state.status == HostVerificationStatus.loadFailed ||
          host == null) {
        body = ErrorStateView(
          title: "Couldn't load your verification",
          message: hostFailureMessage(
            state.failure ?? const UnexpectedFailure(),
          ),
          onRetry: cubit.load,
        );
      } else {
        switch (state.step!) {
          case HostApplicationStep.apply:
            body = const EmptyStateView(
              icon: Icons.badge_outlined,
              title: 'Start your host application first',
              message: 'Identity verification opens after you apply to host.',
            );
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'Start application',
                  onPressed: () => context.go(RoutePaths.hostOnboarding),
                ),
              ],
            );
          case HostApplicationStep.agreement ||
              HostApplicationStep.verification:
            body = const _ManualVerification();
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'Request verification',
                  busy: starting,
                  onPressed: () {
                    _firstStart = true;
                    cubit.startVerification();
                  },
                ),
              ],
            );
          case HostApplicationStep.review:
            body = _UnderReview(
              host: host,
              sessionId: state.session?.sessionId,
            );
            bottom = HostBottomBar(
              children: [
                OutlinedButton(
                  onPressed: () => context.push(RoutePaths.hostProfileSetup),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      DashuriTokens.buttonHeight,
                    ),
                  ),
                  child: const Text('Edit my profile'),
                ),
                TextButton(
                  onPressed: cubit.load,
                  child: const Text('Refresh status'),
                ),
              ],
            );
          case HostApplicationStep.attention:
            body = _Attention(reason: host.kycRejectionReason);
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'Request verification again',
                  busy: starting,
                  onPressed: () {
                    _firstStart = false;
                    cubit.startVerification();
                  },
                ),
              ],
            );
          case HostApplicationStep.approved:
            body = const EmptyStateView(
              icon: Icons.verified_rounded,
              title: "You're approved",
              message: 'Welcome to hosting. Go online whenever you like.',
            );
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'Go to host home',
                  busy: _entering,
                  onPressed: _goToHostHome,
                ),
              ],
            );
          case HostApplicationStep.suspended:
            body = const EmptyStateView(
              icon: Icons.block_rounded,
              title: 'Your host account is suspended',
              message:
                  'See your account status for the reason and how to appeal.',
            );
            bottom = HostBottomBar(
              children: [
                PrimaryButton(
                  label: 'View account status',
                  onPressed: () => context.push(RoutePaths.enforcement),
                ),
              ],
            );
        }
      }
      final showProgress =
          host != null &&
          (state.step == HostApplicationStep.agreement ||
              state.step == HostApplicationStep.verification);
      return Scaffold(
        appBar: AppBar(
          bottom: showProgress ? const HostStepProgress(step: 3) : null,
        ),
        body: body,
        bottomNavigationBar: bottom,
      );
    },
  );
}

class _ManualVerification extends StatelessWidget {
  const _ManualVerification();

  static const _checks = [
    (
      Icons.badge_outlined,
      'Government ID',
      'Confirms your name and that you are 18 or over.',
    ),
    (
      Icons.credit_card_outlined,
      'PAN',
      'Needed for tax on payouts. Matched to your ID name.',
    ),
    (
      Icons.face_retouching_natural_outlined,
      'Live selfie',
      'A quick video check that it is really you.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostFormBody(
      children: [
        Text('Verify your identity', style: theme.textTheme.displaySmall),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          'Every host is verified by our team before going online. '
          'When you request verification, our team will contact you to verify '
          'your ID. Nothing is uploaded from this screen.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DashuriTokens.space5),
        HostCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabelValueRow(
                label: Text(
                  'What our team will check',
                  style: theme.textTheme.titleMedium,
                ),
                value: const StatusTag(
                  label: 'Manual review',
                  tone: StatusTone.info,
                ),
              ),
              const SizedBox(height: DashuriTokens.space3),
              for (final (icon, title, body) in _checks)
                Padding(
                  padding: const EdgeInsets.only(bottom: DashuriTokens.space3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: theme.colorScheme.primary),
                      const SizedBox(width: DashuriTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleSmall),
                            Text(body, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DashuriTokens.space4),
        const HostNotice(
          icon: Icons.lock_outline_rounded,
          message:
              'We use your ID only to confirm you are over 18 and to match '
              'your payouts. Your documents are never shown to customers.',
        ),
      ],
    );
  }
}

class _UnderReview extends StatelessWidget {
  const _UnderReview({required this.host, this.sessionId});

  final HostStatus host;
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idDone = host.kycApproved;
    return HostFormBody(
      children: [
        const SizedBox(height: DashuriTokens.space4),
        const HostHeroIcon(icon: Icons.hourglass_top_rounded),
        const SizedBox(height: DashuriTokens.space5),
        Text(
          "You're almost there",
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          "We're reviewing your application. We'll notify you as soon as you "
          'can go online.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space5),
        HostCard(
          child: Column(
            children: [
              const HostTimelineStep(
                title: 'Application submitted',
                state: TimelineState.done,
              ),
              HostTimelineStep(
                title: 'Identity & age verification',
                subtitle: idDone
                    ? 'Verified'
                    : 'Our team will contact you to verify your ID',
                state: idDone ? TimelineState.done : TimelineState.current,
              ),
              HostTimelineStep(
                title: 'Profile review',
                subtitle: 'Checking your photos and bio',
                state: idDone ? TimelineState.current : TimelineState.pending,
              ),
              const HostTimelineStep(
                title: 'Ready to host',
                subtitle: 'You can go online',
                state: TimelineState.pending,
              ),
            ],
          ),
        ),
        if (sessionId != null) ...[
          const SizedBox(height: DashuriTokens.space3),
          SelectableText(
            'Verification reference: $sessionId',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: DashuriTokens.space3),
        Text(
          'You can still edit your profile and rate while you wait.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostFormBody(
      children: [
        const SizedBox(height: DashuriTokens.space4),
        const HostHeroIcon(
          icon: Icons.report_gmailerrorred_rounded,
          tone: _warning,
        ),
        const SizedBox(height: DashuriTokens.space5),
        Text(
          'Verification needs attention',
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          "Our team couldn't complete your identity check.",
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space4),
        HostNotice(
          tone: StatusTone.warning,
          icon: Icons.info_outline_rounded,
          message: reason == null || reason!.trim().isEmpty
              ? 'Request verification again and our team will contact you to '
                    'redo the check.'
              : 'Reason: ${reason!.trim()}',
        ),
        const SizedBox(height: DashuriTokens.space4),
        HostCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips for a good check', style: theme.textTheme.titleSmall),
              const SizedBox(height: DashuriTokens.space2),
              for (final (icon, tip) in const [
                (Icons.wb_sunny_outlined, 'Face a window or bright light'),
                (Icons.face_outlined, 'Remove glasses and hats'),
                (Icons.smartphone_outlined, 'Hold the phone at eye level'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: DashuriTokens.space3),
                      Expanded(child: Text(tip)),
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

DashuriTone _warning(DashuriColors c) => c.warning;
