import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_calls_cubit.dart';
import '../../application/paged_list_state.dart';
import '../../domain/entities/host_call.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H22 host call history (RoutePaths.hostCalls, Calls tab).
class HostCallsPage extends StatelessWidget {
  const HostCallsPage({super.key, this.now});

  /// Injected "now" for day grouping in tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocBuilder<HostCallsCubit, HostCallsState>(
        builder: (context, state) {
          final cubit = context.read<HostCallsCubit>();
          final list = state.list;
          final header = <Widget>[
            const HostLargeTitle('Calls'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in HostCallFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(
                        right: DashuriTokens.space2,
                      ),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          HostCallFilter.all => 'All',
                          HostCallFilter.paid => 'Paid',
                          HostCallFilter.free => 'Free',
                          HostCallFilter.missed => 'Missed',
                        }),
                        selected: state.filter == f,
                        onSelected: (_) => cubit.setFilter(f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: DashuriTokens.space2),
          ];
          Widget content;
          switch (list.status) {
            case PagedStatus.loading:
              content = const Padding(
                padding: EdgeInsets.only(top: DashuriTokens.space10),
                child: LoadingView(),
              );
            case PagedStatus.failed:
              content = ErrorStateView(
                message: hostFailureMessage(list.failure!),
                onRetry: cubit.load,
              );
            case PagedStatus.loaded:
              final calls = state.visible;
              if (calls.isEmpty && !list.hasMore) {
                content = EmptyStateView(
                  icon: Icons.videocam_outlined,
                  title: list.items.isEmpty ? 'No calls yet' : 'No calls here',
                  message: list.items.isEmpty
                      ? 'Go online from Home and your calls will appear here.'
                      : 'Try another filter.',
                );
              } else {
                content = _CallList(
                  calls: calls,
                  state: list,
                  now: (now ?? DateTime.now)(),
                  onLoadMore: cubit.loadMore,
                );
              }
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ResponsiveCenter(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [...header, content],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _CallList extends StatelessWidget {
  const _CallList({
    required this.calls,
    required this.state,
    required this.now,
    required this.onLoadMore,
  });

  final List<HostCall> calls;
  final PagedListState<HostCall> state;
  final DateTime now;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    String? lastDay;
    for (final call in calls) {
      final day = call.startedAt == null
          ? 'Earlier'
          : HostFormat.dayLabel(call.startedAt!, now);
      if (day != lastDay) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(
              top: DashuriTokens.space4,
              bottom: DashuriTokens.space1,
            ),
            child: Text(
              day.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
        lastDay = day;
      }
      children.add(_CallRow(call: call));
    }
    if (state.hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(DashuriTokens.space4),
          child: Center(
            child: state.loadingMore
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: onLoadMore,
                    child: Text(
                      state.loadMoreFailure == null
                          ? 'Load more'
                          : "Couldn't load more. Try again",
                    ),
                  ),
          ),
        ),
      );
    }
    children.add(const SizedBox(height: DashuriTokens.space8));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.call});

  final HostCall call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = call.peerName ?? 'Customer';
    final time = call.startedAt == null
        ? null
        : HostFormat.time(call.startedAt!);
    final detail = call.isMissed
        ? 'Missed'
        : call.isFreeCall
        ? 'Free call · ${HostFormat.callDuration(call.billedSeconds)}'
        : HostFormat.callDuration(call.billedSeconds);
    final beans = call.beansEarned;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: name, url: call.peerPhotoUrl),
      title: Text(name, style: theme.textTheme.titleMedium),
      subtitle: Row(
        children: [
          Icon(
            call.isMissed
                ? Icons.phone_missed_rounded
                : call.isFreeCall
                ? Icons.card_giftcard_rounded
                : Icons.videocam_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              time == null ? detail : '$detail · $time',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (beans != null && beans > 0)
            CurrencyAmount.beans(
              beans,
              style: theme.textTheme.titleSmall?.copyWith(
                color: DashuriTokens.success,
              ),
            )
          else
            Text('—', style: theme.textTheme.bodyMedium),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (_) => context.push(
              hostReportLocation(
                userId: call.peerUserId,
                callId: call.callId,
                name: call.peerName,
              ),
            ),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
    );
  }
}
