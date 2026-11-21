import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/call_summary_cubit.dart';
import '../../domain/entities/call_session.dart';
import '../widgets/call_widgets.dart';

/// Server end reasons that mean the balance ran out (V10).
const _balanceReasons = {
  'low_balance',
  'balance_exhausted',
  'insufficient_balance',
  'insufficient_diamonds',
};

/// V08 not answered, V09 customer summary (no rating, D-11), V10 ended at
/// zero balance, V14 failed and refunded, V18 host summary.
class CallSummaryPage extends StatelessWidget {
  const CallSummaryPage({required this.callId, super.key});

  final String callId;

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<CallSummaryCubit, CallSummaryState>(
    builder: (context, s) => Scaffold(
      appBar: AppBar(leading: CloseButton(onPressed: () => _done(context, s))),
      body: switch (s) {
        CallSummaryLoading() => const LoadingView(),
        CallSummaryFailed(:final failure) => ErrorStateView(
          message: callFailureMessage(failure),
          onRetry: () => context.read<CallSummaryCubit>().load(callId),
        ),
        CallSummaryLoaded() => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space5),
            child: ResponsiveCenter(child: _Content(state: s)),
          ),
        ),
      },
    ),
  );
}

void _done(BuildContext context, CallSummaryState s) {
  final host = s is CallSummaryLoaded && s.session.role == CallRole.receiver;
  context.go(host ? RoutePaths.hostDashboard : RoutePaths.discovery);
}

void _report(BuildContext context, CallSession s) => context.push(
  Uri(
    path: RoutePaths.report,
    queryParameters: {
      'userId': s.peerUserId,
      'callId': s.callId,
      if (s.peerName.isNotEmpty) 'name': s.peerName,
    },
  ).toString(),
);

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final CallSummaryLoaded state;

  @override
  Widget build(BuildContext context) {
    final s = state.session;
    final theme = Theme.of(context);
    final name = s.peerName.isEmpty
        ? (s.role == CallRole.caller ? 'the host' : 'the customer')
        : s.peerName;
    final header = Column(
      children: [
        UserAvatar(name: name, url: s.peer?.photoUrl, radius: 44),
        const SizedBox(height: DashuriTokens.space4),
      ],
    );
    final title = theme.textTheme.headlineMedium;

    // V08: never connected because the host declined or did not answer.
    if (s.role == CallRole.caller &&
        (s.phase == CallPhase.declined || s.phase == CallPhase.missed)) {
      return Column(
        children: [
          header,
          Text(
            "$name couldn't take your call",
            style: title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DashuriTokens.space3),
          const StatusTag(
            label: "You haven't been charged",
            tone: StatusTone.success,
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(
            'Hosts are free to accept calls when they can. Other hosts are '
            'online now.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DashuriTokens.space6),
          PrimaryButton(
            label: 'Back to Discover',
            onPressed: () => context.go(RoutePaths.discovery),
          ),
        ],
      );
    }

    // V14: failed before both were on video; nothing billed.
    if (s.phase == CallPhase.failed) {
      return Column(
        children: [
          Icon(
            Icons.link_off_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text(
            "The call couldn't connect",
            style: title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DashuriTokens.space3),
          Text(
            "Something went wrong before you were both on video. You haven't "
            'been charged.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (s.role == CallRole.caller && !s.isFreeCall) ...[
            const SizedBox(height: DashuriTokens.space3),
            const StatusTag(
              label: 'All Diamonds returned',
              tone: StatusTone.success,
            ),
          ],
          const SizedBox(height: DashuriTokens.space6),
          if (s.role == CallRole.caller && !s.isFreeCall) ...[
            PrimaryButton(
              label: 'Try again',
              onPressed: () => context.go(
                RoutePaths.withParams(RoutePaths.preCall, {
                  'userId': s.peerUserId,
                }),
              ),
            ),
            const SizedBox(height: DashuriTokens.space3),
          ],
          OutlinedButton(
            onPressed: () => _done(context, state),
            child: Text(
              s.role == CallRole.caller ? 'Back to Discover' : 'Done',
            ),
          ),
        ],
      );
    }

    final duration = DashuriFormat.duration(s.billedSeconds);
    final moderation = s.endReason == 'moderation';
    final rows = <Widget>[
      SummaryRow(
        label: 'Billed time',
        value: Text(minutesSeconds(s.billedSeconds)),
      ),
      if (!s.isFreeCall)
        SummaryRow(
          label: s.role == CallRole.receiver ? 'Your rate' : 'Rate',
          value: CurrencyAmount.diamonds(
            s.ratePerMinute,
            suffix: ' / min',
            style: theme.textTheme.titleSmall,
          ),
        ),
    ];
    final notice = moderation
        ? 'This call was ended by our automated safety check.'
        : null;

    // V18: host summary. Beans only when the server reports them.
    if (s.role == CallRole.receiver) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Text(
            'Call with $name ended · $duration',
            style: title,
            textAlign: TextAlign.center,
          ),
          if (notice != null) _Notice(text: notice),
          const SizedBox(height: DashuriTokens.space5),
          if (s.beansEarned != null) ...[
            Text(
              'YOU EARNED',
              style: theme.textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DashuriTokens.space2),
            Center(
              child: CurrencyAmount.beans(
                s.beansEarned!,
                suffix: ' Beans',
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ] else
            Text(
              s.isFreeCall
                  ? 'Free calls are paid only for a full connected minute. '
                        'Any earnings for this call will appear in Earnings.'
                  : 'Your earnings for this call will appear in Earnings.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: DashuriTokens.space4),
          ...rows,
          const SizedBox(height: DashuriTokens.space6),
          PrimaryButton(
            label: 'Back to dashboard',
            onPressed: () => context.go(RoutePaths.hostDashboard),
          ),
          const SizedBox(height: DashuriTokens.space3),
          OutlinedButton(
            onPressed: () => context.go(RoutePaths.hostEarnings),
            child: const Text('View earnings'),
          ),
          TextButton.icon(
            onPressed: () => _report(context, s),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report'),
          ),
        ],
      );
    }

    final ranOut =
        _balanceReasons.contains(s.endReason) ||
        (state.balance == 0 && !s.isFreeCall);
    // V09 / V10 customer summary. No rating (D-11).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Text(
          'Call ended · $duration with $name',
          style: title,
          textAlign: TextAlign.center,
        ),
        if (ranOut && !s.isFreeCall)
          const _Notice(
            text:
                'Your balance ran out, so the call ended automatically. You '
                'were warned 30 seconds before.',
          ),
        if (notice != null) _Notice(text: notice),
        const SizedBox(height: DashuriTokens.space4),
        ...rows,
        if (s.isFreeCall)
          const SummaryRow(label: 'Free Call Card', value: Text('Used')),
        const Divider(),
        SummaryRow(
          label: 'Diamonds used',
          value: CurrencyAmount.diamonds(
            s.diamondsCharged,
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (state.balance != null)
          SummaryRow(
            label: 'Balance remaining',
            value: CurrencyAmount.diamonds(
              state.balance!,
              style: theme.textTheme.titleSmall,
            ),
          ),
        const SizedBox(height: DashuriTokens.space6),
        if (ranOut || s.isFreeCall) ...[
          PrimaryButton(
            label: s.isFreeCall
                ? 'Buy Diamonds to keep talking'
                : 'Top up Diamonds',
            icon: Icons.add_rounded,
            onPressed: () => context.push(RoutePaths.buyDiamonds),
          ),
          const SizedBox(height: DashuriTokens.space3),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  Uri(
                    path: RoutePaths.withParams(RoutePaths.conversation, {
                      'conversationId': 'new',
                    }),
                    queryParameters: {'peerUserId': s.peerUserId},
                  ).toString(),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Message'),
              ),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: FilledButton(
                onPressed: () => _done(context, state),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => _report(context, s),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Report a problem'),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: DashuriTokens.space4),
    child: Container(
      padding: const EdgeInsets.all(DashuriTokens.space3),
      decoration: BoxDecoration(
        color: DashuriTokens.warning100,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            color: DashuriTokens.warning,
          ),
          const SizedBox(width: DashuriTokens.space3),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: DashuriTokens.neutral800),
            ),
          ),
        ],
      ),
    ),
  );
}
