import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_earnings_cubit.dart';
import '../../domain/entities/host_earnings.dart';
import '../host_paths.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H14 earnings (RoutePaths.hostEarnings, Earnings tab).
class HostEarningsPage extends StatelessWidget {
  const HostEarningsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocBuilder<HostEarningsCubit, HostEarningsState>(
        builder: (context, state) {
          final cubit = context.read<HostEarningsCubit>();
          final title = HostLargeTitle(
            'Earnings',
            trailing: IconButton.outlined(
              tooltip: 'How Beans work',
              onPressed: () => context.push(HostPaths.beansExplainer),
              icon: const Icon(Icons.help_outline_rounded),
            ),
          );
          return switch (state.status) {
            HostEarningsStatus.loading => const LoadingView(),
            HostEarningsStatus.failed => ErrorStateView(
              message: hostFailureMessage(state.failure!),
              onRetry: cubit.load,
            ),
            HostEarningsStatus.loaded => HostWideBody(
              onRefresh: cubit.load,
              children: [
                title,
                HostCardGrid(
                  children: [
                    _BalanceCard(earnings: state.earnings!),
                    _PendingCard(earnings: state.earnings!),
                    _Links(),
                  ],
                ),
              ],
            ),
          };
        },
      ),
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.earnings});

  final HostEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const muted = Color(0xB3F7F3EE);
    Widget split(String label, int paise, int beans) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Text(
            DashuriFormat.rupees(paise),
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          Text(
            '${DashuriFormat.count(beans)} Beans',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
    final holdPaise = BeanRules.beansToPaise(earnings.beansOnHold);
    return BeansHeroCard(
      label: 'Beans balance',
      trailing: 'Never expire',
      beans: earnings.balanceBeans,
      caption: HostFormat.approxRupees(earnings.availableInrPaise + holdPaise),
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
              split(
                'WITHDRAWABLE',
                earnings.availableInrPaise,
                earnings.beansAvailable,
              ),
              const SizedBox(width: DashuriTokens.space3),
              split('ON HOLD · 7 DAYS', holdPaise, earnings.beansOnHold),
            ],
          ),
        ),
        const SizedBox(height: DashuriTokens.space4),
        FilledButton(
          onPressed: () => context.push(RoutePaths.hostWithdraw),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(DashuriTokens.buttonHeight),
            backgroundColor: BeansHeroCard.goldLight,
            foregroundColor: BeansHeroCard.background,
          ),
          child: Text(
            earnings.canWithdraw
                ? 'Withdraw ${DashuriFormat.rupees(earnings.availableInrPaise)}'
                : 'Withdraw',
          ),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.earnings});

  final HostEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HostStatCard(
            label: 'Pending payout',
            value: CurrencyAmount.beans(
              earnings.beansPendingPayout,
              style: theme.textTheme.headlineSmall,
            ),
            caption: earnings.nextPayoutDate == null
                ? HostFormat.approxRupees(
                    BeanRules.beansToPaise(earnings.beansPendingPayout),
                  )
                : '${HostFormat.approxRupees(BeanRules.beansToPaise(earnings.beansPendingPayout))}'
                      ' · next payout ${HostFormat.date(earnings.nextPayoutDate!)}',
          ),
          const SizedBox(height: DashuriTokens.space4),
          Text('The 7-day hold', style: theme.textTheme.titleMedium),
          const SizedBox(height: DashuriTokens.space1),
          Text(
            'Beans you earn are on hold for 7 days, then become withdrawable. '
            'The hold protects you and customers if a payment is refunded. '
            '200 Beans = ₹1; ₹ amounts are approximate and before tax.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Links extends StatelessWidget {
  @override
  Widget build(BuildContext context) => HostLinkGroup(
    tiles: [
      HostLinkTile(
        icon: Icons.calculate_outlined,
        title: 'How Beans work',
        onTap: () => context.push(HostPaths.beansExplainer),
      ),
      HostLinkTile(
        icon: Icons.receipt_long_outlined,
        title: 'Payout history',
        onTap: () => context.push(RoutePaths.hostPayoutHistory),
      ),
      HostLinkTile(
        icon: Icons.account_balance_outlined,
        title: 'Payout method',
        onTap: () => context.push(RoutePaths.hostPayoutMethod),
      ),
    ],
  );
}
