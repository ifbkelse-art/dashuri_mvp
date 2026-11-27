import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/wallet_cubit.dart';
import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/wallet_summary.dart';
import '../widgets/transaction_row.dart';
import '../widgets/wallet_format.dart';
import '../widgets/wallet_hero.dart';

/// W01 wallet overview (customer tab; hosts also see Beans).
class WalletPage extends StatelessWidget {
  const WalletPage({super.key, this.onGiftsSent});

  /// Opens the customer's gift history (null hides the link).
  final VoidCallback? onGiftsSent;

  static void openEntry(BuildContext context, WalletEntry e) => context.push(
    RoutePaths.withParams(RoutePaths.transactionDetail, {'entryId': e.id}),
    extra: e,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) => switch (state) {
            WalletStateInitial() || WalletStateLoading() => const LoadingView(),
            WalletStateFailed(:final failure) => ErrorStateView(
              title: "Couldn't load your wallet",
              message: WalletFormat.failureMessage(failure),
              onRetry: () => context.read<WalletCubit>().load(),
            ),
            final WalletStateLoaded s => RefreshIndicator(
              onRefresh: () => context.read<WalletCubit>().refresh(),
              child: _Loaded(state: s, onGiftsSent: onGiftsSent),
            ),
          },
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state, this.onGiftsSent});

  final WalletStateLoaded state;
  final VoidCallback? onGiftsSent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balances = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletHero(
          availableDiamonds: state.summary.availableDiamonds,
          onBuy: () => context.push(RoutePaths.buyDiamonds),
          onHistory: () => context.push(RoutePaths.transactions),
        ),
        const SizedBox(height: DashuriTokens.space4),
        _DiamondBreakdown(summary: state.summary),
        if (state.isHost) ...[
          const SizedBox(height: DashuriTokens.space4),
          _BeansCard(summary: state.summary),
        ],
        if (onGiftsSent != null) ...[
          const SizedBox(height: DashuriTokens.space2),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.card_giftcard_rounded),
            title: const Text('Gifts sent'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onGiftsSent,
          ),
        ],
      ],
    );
    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Recent activity',
          trailing: TextButton(
            onPressed: () => context.push(RoutePaths.transactions),
            child: const Text('See all'),
          ),
        ),
        if (state.recentFailed)
          Text(
            "Recent activity couldn't load. Pull down to refresh.",
            style: theme.textTheme.bodyMedium,
          )
        else if (state.recent.isEmpty)
          Text(
            'No activity yet. Purchases and calls will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ListCard(
            children: [
              for (final e in state.recent)
                TransactionRow(
                  entry: e,
                  onTap: () => WalletPage.openEntry(context, e),
                ),
            ],
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: DashuriTokens.space8),
          children: [
            ResponsiveCenter(
              maxWidth: wide
                  ? DashuriTokens.maxWideContentWidth
                  : DashuriTokens.maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DashuriTokens.space4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Wallet',
                            style: theme.textTheme.displaySmall,
                          ),
                        ),
                        if (state.refreshing)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        IconButton.filledTonal(
                          tooltip: 'Help',
                          onPressed: () => context.push(RoutePaths.helpSupport),
                          icon: const Icon(Icons.help_outline),
                        ),
                      ],
                    ),
                  ),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: balances),
                        const SizedBox(width: DashuriTokens.space8),
                        Expanded(child: activity),
                      ],
                    )
                  else ...[
                    balances,
                    activity,
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.amount,
    required this.note,
    this.beans = false,
  });

  final String label;
  final int amount;
  final String? note;
  final bool beans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: muted),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: beans
              ? CurrencyAmount.beans(amount)
              : CurrencyAmount.diamonds(amount),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note!, style: muted),
        ],
      ],
    );
  }
}

class _DiamondBreakdown extends StatelessWidget {
  const _DiamondBreakdown({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Cell(
                  label: 'Purchased',
                  amount: summary.purchasedDiamonds,
                  note: 'Never expire',
                ),
              ),
              const SizedBox(width: DashuriTokens.space4),
              Expanded(
                child: _Cell(
                  label: 'Promotional',
                  amount: summary.promotionalDiamonds,
                  note: 'Expire after 30 days',
                ),
              ),
            ],
          ),
          if (summary.reservedDiamonds > 0) ...[
            const Divider(height: DashuriTokens.space6),
            Row(
              children: [
                const Icon(Icons.lock_clock_outlined, size: 18),
                const SizedBox(width: DashuriTokens.space2),
                Expanded(
                  child: Text(
                    'Reserved for a call in progress',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                CurrencyAmount.diamonds(
                  summary.reservedDiamonds,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BeansCard extends StatelessWidget {
  const _BeansCard({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Host earnings', style: theme.textTheme.titleMedium),
          const SizedBox(height: DashuriTokens.space3),
          Wrap(
            spacing: DashuriTokens.space6,
            runSpacing: DashuriTokens.space3,
            children: [
              _Cell(
                label: 'Available',
                amount: summary.beansAvailable,
                note: null,
                beans: true,
              ),
              _Cell(
                label: 'On hold',
                amount: summary.beansOnHold,
                note: '7-day hold',
                beans: true,
              ),
              if (summary.beansPendingPayout > 0)
                _Cell(
                  label: 'Pending payout',
                  amount: summary.beansPendingPayout,
                  note: null,
                  beans: true,
                ),
            ],
          ),
          const SizedBox(height: DashuriTokens.space2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.push(RoutePaths.hostEarnings),
              child: const Text('View earnings'),
            ),
          ),
        ],
      ),
    );
  }
}
