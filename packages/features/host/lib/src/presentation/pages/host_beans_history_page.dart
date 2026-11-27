import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_beans_history_cubit.dart';
import '../../application/paged_list_state.dart';
import '../../domain/entities/bean_history.dart';
import '../../domain/entities/host_earnings.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// Beans history (RoutePaths.hostEarnings/history): the balance, what was
/// earned and when, and every Bean movement newest first with a running
/// balance. Each line is a real ledger entry, so the lines add up to the
/// balance at the top.
class HostBeansHistoryPage extends StatelessWidget {
  const HostBeansHistoryPage({super.key, this.now});

  /// Injected "now" for day grouping in tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Beans history')),
    body: BlocBuilder<HostBeansHistoryCubit, HostBeansHistoryState>(
      builder: (context, state) {
        final cubit = context.read<HostBeansHistoryCubit>();
        final list = state.list;
        if (list.status == PagedStatus.failed && state.summary == null) {
          return ErrorStateView(
            title: "Couldn't load your Beans history",
            message: hostFailureMessage(list.failure!),
            onRetry: cubit.load,
          );
        }
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) cubit.loadMore();
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(DashuriTokens.space4),
              children: [
                ResponsiveCenter(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.summary != null)
                        _SummaryHeader(summary: state.summary!),
                      const SizedBox(height: DashuriTokens.space4),
                      _Filters(
                        selected: state.filter,
                        onSelect: cubit.setFilter,
                      ),
                      const SizedBox(height: DashuriTokens.space2),
                      _Body(
                        state: state,
                        now: (now ?? DateTime.now)(),
                        onRetry: cubit.load,
                        onLoadMore: cubit.loadMore,
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
  );
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary});

  final BeanSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const muted = Color(0xB3F7F3EE);
    Widget split(String label, int beans) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            DashuriFormat.count(beans),
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
    Widget stat(String label, int beans) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          CurrencyAmount.beans(beans, style: theme.textTheme.titleSmall),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeansHeroCard(
          label: 'Beans balance',
          trailing: 'Never expire',
          beans: summary.balance,
          caption: HostFormat.approxRupees(
            BeanRules.beansToPaise(summary.balance),
          ),
          children: [
            const SizedBox(height: DashuriTokens.space4),
            Container(
              padding: const EdgeInsets.all(DashuriTokens.space4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
              ),
              child: Row(
                children: [
                  split('AVAILABLE', summary.available),
                  split('ON HOLD', summary.onHold),
                  split('IN PAYOUT', summary.pendingPayout),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space3),
        HostCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Earned', style: theme.textTheme.titleMedium),
              const SizedBox(height: DashuriTokens.space3),
              Row(
                children: [
                  stat('Today', summary.earnedToday),
                  stat('7 days', summary.earned7Days),
                  stat('30 days', summary.earned30Days),
                ],
              ),
              const Divider(height: DashuriTokens.space6),
              Text(
                'Lifetime ${DashuriFormat.count(summary.lifetimeEarned)} Beans',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: DashuriTokens.space1),
              Text(
                'Calls ${DashuriFormat.count(summary.fromCalls)} · '
                'Gifts ${DashuriFormat.count(summary.fromGifts)} · '
                'Free calls ${DashuriFormat.count(summary.fromFreeCalls)}',
                style: theme.textTheme.bodySmall,
              ),
              if (summary.paidOut > 0 || summary.reversed > 0) ...[
                const SizedBox(height: DashuriTokens.space1),
                Text(
                  [
                    if (summary.paidOut > 0)
                      'Paid out ${DashuriFormat.count(summary.paidOut)}',
                    if (summary.reversed > 0)
                      'Reversed ${DashuriFormat.count(summary.reversed)}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.selected, required this.onSelect});

  final BeanFilter selected;
  final ValueChanged<BeanFilter> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final f in BeanFilter.values)
          Padding(
            padding: const EdgeInsets.only(right: DashuriTokens.space2),
            child: ChoiceChip(
              label: Text(f.label),
              selected: selected == f,
              onSelected: (_) => onSelect(f),
            ),
          ),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.now,
    required this.onRetry,
    required this.onLoadMore,
  });

  final HostBeansHistoryState state;
  final DateTime now;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final list = state.list;
    switch (list.status) {
      case PagedStatus.loading:
        return const SizedBox(height: 320, child: SkeletonList(rows: 5));
      case PagedStatus.failed:
        return ErrorStateView(
          title: "Couldn't load these lines",
          message: hostFailureMessage(list.failure!),
          onRetry: onRetry,
        );
      case PagedStatus.loaded:
        if (list.items.isEmpty) {
          return EmptyStateView(
            icon: Icons.toll_outlined,
            title: state.filter == BeanFilter.all
                ? 'No Beans yet'
                : 'Nothing here',
            message: state.filter == BeanFilter.all
                ? 'Earn Beans from calls and gifts and every movement will '
                      'show up here.'
                : 'Try another filter.',
          );
        }
        final theme = Theme.of(context);
        final children = <Widget>[];
        String? lastDay;
        for (final item in list.items) {
          final day = HostFormat.dayLabel(item.occurredAt, now);
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
          children.add(_Line(item: item));
        }
        if (list.loadingMore) {
          children.add(
            const Padding(
              padding: EdgeInsets.all(DashuriTokens.space4),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (list.loadMoreFailure != null) {
          children.add(
            TextButton(
              onPressed: onLoadMore,
              child: const Text("Couldn't load more. Try again"),
            ),
          );
        } else if (!list.hasMore) {
          children.add(
            Padding(
              padding: const EdgeInsets.all(DashuriTokens.space4),
              child: Text(
                'That is everything. Every line above is a Bean movement '
                'recorded on your account.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
    }
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.item});

  final BeanHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = DashuriColors.of(context);
    final (icon, tone) = switch (item.type) {
      BeanLineType.call => (Icons.videocam_rounded, colors.success),
      BeanLineType.freeCall => (Icons.card_giftcard_rounded, colors.success),
      BeanLineType.gift => (Icons.redeem_rounded, colors.success),
      BeanLineType.release => (Icons.lock_open_rounded, colors.info),
      BeanLineType.withdrawal => (Icons.north_east_rounded, colors.warning),
      BeanLineType.payoutPaid => (Icons.check_circle_outline, colors.success),
      BeanLineType.payoutFailed => (Icons.undo_rounded, colors.warning),
      BeanLineType.reversal => (Icons.remove_circle_outline, colors.error),
      BeanLineType.adjustment => (Icons.tune_rounded, colors.neutral),
      BeanLineType.other => (Icons.toll_outlined, colors.neutral),
    };
    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: item.beans > 0
          ? colors.positiveText
          : item.beans < 0
          ? theme.colorScheme.error
          : theme.colorScheme.onSurfaceVariant,
    );
    final amount = item.beans != 0
        ? '${item.beans > 0 ? '+' : '−'}${DashuriFormat.count(item.beans.abs())}'
        : item.movedBeans != null
        ? DashuriFormat.count(item.movedBeans!)
        : '0';
    final status = _statusText(item);
    // Large text: the amount moves under the title instead of squeezing
    // beside it (a long word like "Diamonds/min" plus the amount does not fit
    // next to the icon on a small phone at 2x).
    final compact = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;
    final amountBlock = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.beans == 0 && item.movedBeans != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const BeanIcon(size: 14),
            const SizedBox(width: 4),
            Text(amount, style: amountStyle),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Balance ${DashuriFormat.count(item.balanceAfter)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final label =
        '${item.title}, $amount Beans'
        '${item.beans == 0 && item.movedBeans != null ? ' moved' : ''}'
        ', balance ${DashuriFormat.count(item.balanceAfter)}'
        '${status == null ? '' : ', $status'}';
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: tone.container,
              child: Icon(icon, size: 20, color: tone.icon),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: theme.textTheme.titleSmall),
                  if (item.subtitle != null)
                    Text(item.subtitle!, style: theme.textTheme.bodySmall),
                  Text(
                    HostFormat.time(item.occurredAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (status != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: item.onHold == true
                              ? colors.warning.onContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (compact)
                    Padding(
                      padding: const EdgeInsets.only(top: DashuriTokens.space2),
                      child: amountBlock,
                    ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: DashuriTokens.space3),
              amountBlock,
            ],
          ],
        ),
      ),
    );
  }

  /// "On hold · withdrawable 5 Dec" / "Released 3 Dec" for earnings.
  String? _statusText(BeanHistoryItem i) {
    if (i.onHold == null) return null;
    if (i.onHold!) {
      return i.releasesAt == null
          ? 'On hold'
          : 'On hold · withdrawable ${HostFormat.date(i.releasesAt!)}';
    }
    return i.releasedAt == null
        ? 'Released'
        : 'Released ${HostFormat.date(i.releasedAt!)}';
  }
}
