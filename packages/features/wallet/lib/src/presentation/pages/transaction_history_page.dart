import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/wallet_history_cubit.dart';
import '../../domain/entities/wallet_entry.dart';
import '../widgets/transaction_row.dart';
import '../widgets/wallet_format.dart';
import 'wallet_page.dart';

enum HistoryFilter { all, purchases, calls, refunds }

extension on HistoryFilter {
  String get label => switch (this) {
    HistoryFilter.all => 'All',
    HistoryFilter.purchases => 'Purchases',
    HistoryFilter.calls => 'Calls',
    HistoryFilter.refunds => 'Refunds',
  };

  bool accepts(WalletEntry e) => switch (this) {
    HistoryFilter.all => true,
    HistoryFilter.purchases =>
      e.kind == 'purchase_credit' || e.kind == 'promo_grant',
    HistoryFilter.calls =>
      e.kind == 'call_settlement' || e.kind == 'free_call_compensation',
    HistoryFilter.refunds =>
      e.kind == 'purchase_reversal' || e.kind == 'payout_failed',
  };
}

/// W08 transaction history: cursor paging, grouped by day.
class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  HistoryFilter _filter = HistoryFilter.all;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 400) {
      context.read<WalletHistoryCubit>().loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        top: false,
        child: BlocBuilder<WalletHistoryCubit, WalletHistoryState>(
          builder: (context, state) {
            final cubit = context.read<WalletHistoryCubit>();
            switch (state.status) {
              case WalletHistoryStatus.initial:
              case WalletHistoryStatus.loading:
                return const SkeletonList(avatar: false);
              case WalletHistoryStatus.failed:
                return ErrorStateView(
                  title: "Couldn't load your history",
                  message: WalletFormat.failureMessage(
                    state.failure!,
                    subject: 'your activity',
                  ),
                  onRetry: cubit.load,
                );
              case WalletHistoryStatus.loaded:
                break;
            }
            final visible = state.entries.where(_filter.accepts).toList();
            final groups = <DateTime, List<WalletEntry>>{};
            for (final e in visible) {
              groups
                  .putIfAbsent(WalletFormat.dayOf(e.createdAt), () => [])
                  .add(e);
            }
            return NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: RefreshIndicator(
                onRefresh: cubit.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: DashuriTokens.space8),
                  children: [
                    ResponsiveCenter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: DashuriTokens.space2),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<HistoryFilter>(
                              showSelectedIcon: false,
                              segments: [
                                for (final f in HistoryFilter.values)
                                  ButtonSegment(value: f, label: Text(f.label)),
                              ],
                              selected: {_filter},
                              onSelectionChanged: (s) =>
                                  setState(() => _filter = s.first),
                            ),
                          ),
                          if (visible.isEmpty && !state.hasMore)
                            const Padding(
                              padding: EdgeInsets.only(
                                top: DashuriTokens.space10,
                              ),
                              child: EmptyStateView(
                                icon: Icons.receipt_long_outlined,
                                title: 'No transactions yet',
                                message:
                                    'Purchases, calls and refunds will appear here.',
                              ),
                            ),
                          for (final g in groups.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                4,
                                DashuriTokens.space5,
                                4,
                                DashuriTokens.space2,
                              ),
                              child: Text(
                                WalletFormat.day(g.key),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            ListCard(
                              children: [
                                for (final e in g.value)
                                  TransactionRow(
                                    entry: e,
                                    showDay: false,
                                    onTap: () =>
                                        WalletPage.openEntry(context, e),
                                  ),
                              ],
                            ),
                          ],
                          if (state.loadingMore)
                            const Padding(
                              padding: EdgeInsets.all(DashuriTokens.space4),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (state.moreFailure != null)
                            Padding(
                              padding: const EdgeInsets.all(
                                DashuriTokens.space4,
                              ),
                              child: Center(
                                child: TextButton.icon(
                                  onPressed: cubit.loadMore,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Load more'),
                                ),
                              ),
                            )
                          else if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.all(
                                DashuriTokens.space4,
                              ),
                              child: Center(
                                child: TextButton(
                                  onPressed: cubit.loadMore,
                                  child: const Text('Load more'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
