import 'dart:async';

import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/pre_call_cubit.dart';
import '../../domain/entities/pre_call_info.dart';
import '../widgets/call_widgets.dart';

/// V01 pre-call confirmation and V06 insufficient balance.
class PreCallPage extends StatelessWidget {
  const PreCallPage({required this.hostUserId, super.key});

  final String hostUserId;

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<PreCallCubit, PreCallState>(
    listener: (context, s) {
      if (s is PreCallStarted) {
        context.pushReplacement(
          RoutePaths.withParams(RoutePaths.call, {'callId': s.session.callId}),
        );
      }
    },
    builder: (context, s) => Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        title: Text(
          s is PreCallReady && s.insufficient ? 'Top up to call' : 'Video call',
        ),
      ),
      body: switch (s) {
        PreCallLoading() || PreCallStarted() => const LoadingView(),
        PreCallFailed(:final failure) => ErrorStateView(
          message: callFailureMessage(failure),
          onRetry: () => context.read<PreCallCubit>().load(hostUserId),
        ),
        PreCallReady() => _Ready(state: s, hostUserId: hostUserId),
      },
    ),
  );
}

class _Ready extends StatelessWidget {
  const _Ready({required this.state, required this.hostUserId});

  final PreCallReady state;
  final String hostUserId;

  @override
  Widget build(BuildContext context) {
    final info = state.info;
    final theme = Theme.of(context);
    final cubit = context.read<PreCallCubit>();
    final title = info.hostAge == null
        ? info.hostName
        : '${info.hostName}, ${info.hostAge}';
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space5),
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(
                    name: info.hostName,
                    url: info.hostPhotoUrl,
                    radius: 32,
                  ),
                  const SizedBox(width: DashuriTokens.space4),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
              const SizedBox(height: DashuriTokens.space5),
              if (state.insufficient)
                _Insufficient(info: info)
              else
                _Confirm(info: info),
              if (state.requestFailure != null && !state.insufficient) ...[
                const SizedBox(height: DashuriTokens.space4),
                Text(
                  callFailureMessage(state.requestFailure!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: DashuriTokens.space6),
              if (state.insufficient) ...[
                PrimaryButton(
                  label: 'Buy Diamonds',
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    await context.push(RoutePaths.buyDiamonds);
                    // Purchase success returns straight to V01 (re-checked).
                    unawaited(cubit.load(hostUserId));
                  },
                ),
              ] else if (!info.isAvailable)
                PrimaryButton(
                  label: info.availability == 'busy'
                      ? 'In a call. Try again soon'
                      : 'Not available right now',
                  onPressed: null,
                )
              else
                PrimaryButton(
                  label: 'Start video call',
                  icon: Icons.videocam_rounded,
                  busy: state.requesting,
                  onPressed: cubit.startCall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.info});

  final PreCallInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approx = info.approxPaisePerMinute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(DashuriTokens.space4),
            child: Column(
              children: [
                SummaryRow(
                  label: 'Rate',
                  value: CurrencyAmount.diamonds(
                    info.ratePerMinute,
                    suffix: ' / min',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (approx != null)
                  SummaryRow(
                    label: 'Approx. cost',
                    value: Text('≈ ${DashuriFormat.rupees(approx)} / min'),
                  ),
                SummaryRow(
                  label: 'Your balance',
                  value: CurrencyAmount.diamonds(
                    info.availableDiamonds,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SummaryRow(
                  label: 'Talk time',
                  value: Text('about ${minutesSeconds(info.talkTimeSeconds)}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DashuriTokens.space5),
        for (final (icon, text) in const [
          (
            Icons.timer_outlined,
            "Billed per second, only once you're both on video.",
          ),
          (
            Icons.notifications_active_outlined,
            "We'll warn you 30 seconds before your balance runs out.",
          ),
          (
            Icons.verified_user_outlined,
            'You can end the call or report at any time.',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: DashuriTokens.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: DashuriTokens.space3),
                Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Insufficient extends StatelessWidget {
  const _Insufficient({required this.info});

  final PreCallInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget box(String label, int amount) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(DashuriTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: DashuriTokens.space2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: CurrencyAmount.diamonds(
                  amount,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryRow(
          label: 'Rate',
          value: CurrencyAmount.diamonds(
            info.ratePerMinute,
            suffix: ' / min',
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        Row(
          children: [
            box('YOU HAVE', info.availableDiamonds),
            const SizedBox(width: DashuriTokens.space3),
            box('NEEDED TO START', info.minimumToStart),
          ],
        ),
        const SizedBox(height: DashuriTokens.space4),
        Text(
          'You need at least 1 minute of balance to start a call.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
