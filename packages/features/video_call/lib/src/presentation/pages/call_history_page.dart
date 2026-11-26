import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/call_history_cubit.dart';
import '../../domain/entities/call_session.dart';
import '../widgets/call_widgets.dart';

/// Own call history (customer; hosts see the same list in H22).
class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calls')),
    body: BlocBuilder<CallHistoryCubit, CallHistoryState>(
      builder: (context, s) {
        final cubit = context.read<CallHistoryCubit>();
        return switch (s) {
          CallHistoryLoading() => const SkeletonList(),
          CallHistoryFailed(:final failure) => ErrorStateView(
            message: callFailureMessage(failure),
            onRetry: cubit.load,
          ),
          CallHistoryLoaded(:final items) when items.isEmpty => EmptyStateView(
            icon: Icons.videocam_outlined,
            title: 'No calls yet',
            message: 'Calls you make or receive will appear here.',
            actionLabel: 'Refresh',
            onAction: cubit.load,
          ),
          CallHistoryLoaded() => RefreshIndicator(
            onRefresh: cubit.load,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.extentAfter < 400) cubit.loadMore();
                return false;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  vertical: DashuriTokens.space3,
                ),
                itemCount: s.items.length + (s.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == s.items.length) {
                    return Padding(
                      padding: const EdgeInsets.all(DashuriTokens.space4),
                      child: Center(
                        child: s.loadMoreFailed
                            ? TextButton(
                                onPressed: cubit.loadMore,
                                child: const Text('Load more'),
                              )
                            : const CircularProgressIndicator(),
                      ),
                    );
                  }
                  return ResponsiveCenter(child: _CallTile(call: s.items[i]));
                },
              ),
            ),
          ),
        };
      },
    ),
  );
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});

  final CallSession call;

  String get _status => switch (call.phase) {
    CallPhase.missed => 'Missed',
    CallPhase.declined => 'Not answered',
    CallPhase.failed => "Couldn't connect",
    _ => minutesSeconds(call.billedSeconds),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = call.peerName.isEmpty ? 'Call' : call.peerName;
    final started = (call.createdAt ?? call.startedAt)?.toLocal();
    final date = started == null
        ? null
        : '${started.day.toString().padLeft(2, '0')}/'
              '${started.month.toString().padLeft(2, '0')}/${started.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: name, url: call.peer?.photoUrl),
      title: Row(
        children: [
          Flexible(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (call.peer?.isVerified ?? false) ...[
            const SizedBox(width: DashuriTokens.space1),
            const VerifiedHostBadge(compact: true, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (call.isFreeCall) 'Free call',
          if (call.role == CallRole.receiver) 'Incoming',
          _status,
          ?date,
        ].join(' · '),
      ),
      trailing: call.role == CallRole.caller && call.diamondsCharged > 0
          ? CurrencyAmount.diamonds(
              call.diamondsCharged,
              style: theme.textTheme.titleSmall,
            )
          : null,
      onTap: () => context.push(
        RoutePaths.withParams(RoutePaths.callSummary, {'callId': call.callId}),
      ),
    );
  }
}
