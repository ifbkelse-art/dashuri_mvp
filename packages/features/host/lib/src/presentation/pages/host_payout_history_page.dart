import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_payouts_cubit.dart';
import '../../application/paged_list_state.dart';
import '../../domain/entities/withdrawal.dart';
import '../widgets/host_copy.dart';

/// H19 payout history (RoutePaths.hostPayoutHistory).
class HostPayoutHistoryPage extends StatelessWidget {
  const HostPayoutHistoryPage({super.key});

  static (String, StatusTone) statusLabel(String status) => switch (status) {
    WithdrawalStatuses.requested => ('Requested', StatusTone.info),
    WithdrawalStatuses.inCycle => ('Processing', StatusTone.warning),
    WithdrawalStatuses.paid => ('Paid', StatusTone.success),
    WithdrawalStatuses.failed => ('Failed · returned', StatusTone.error),
    WithdrawalStatuses.reversed => ('Reversed · returned', StatusTone.error),
    _ => (status, StatusTone.neutral),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payouts')),
    body: BlocBuilder<HostPayoutsCubit, PagedListState<Withdrawal>>(
      builder: (context, state) {
        final cubit = context.read<HostPayoutsCubit>();
        return switch (state.status) {
          PagedStatus.loading => const SkeletonList(avatar: false),
          PagedStatus.failed => ErrorStateView(
            message: hostFailureMessage(state.failure!),
            onRetry: cubit.load,
          ),
          PagedStatus.loaded when state.items.isEmpty => const EmptyStateView(
            icon: Icons.receipt_long_outlined,
            title: 'No withdrawals yet',
            message:
                'Your withdrawal requests and payouts will appear here. '
                'Failed payouts are returned to your Beans automatically.',
          ),
          PagedStatus.loaded => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              children: [
                ResponsiveCenter(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final w in state.items) _Row(withdrawal: w),
                      if (state.hasMore)
                        Padding(
                          padding: const EdgeInsets.all(DashuriTokens.space4),
                          child: Center(
                            child: state.loadingMore
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: cubit.loadMore,
                                    child: Text(
                                      state.loadMoreFailure == null
                                          ? 'Load more'
                                          : "Couldn't load more. Try again",
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        };
      },
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, tone) = HostPayoutHistoryPage.statusLabel(withdrawal.status);
    final when = withdrawal.paidAt != null
        ? 'Paid ${HostFormat.longDate(withdrawal.paidAt!)}'
        : 'Requested ${HostFormat.longDate(withdrawal.requestedAt)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        DashuriFormat.rupees(withdrawal.amountPaise),
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text('$when · ${DashuriFormat.count(withdrawal.beans)} Beans'),
      // Capped so a long status at large text cannot take the whole row.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 128),
        child: StatusTag(label: label, tone: tone),
      ),
    );
  }
}
