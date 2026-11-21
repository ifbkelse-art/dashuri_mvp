import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/purchase_bloc.dart';
import '../../domain/entities/diamond_package.dart';
import '../widgets/package_card.dart';
import '../widgets/purchase_copy.dart';

/// W02 Diamond packages. Optional [ratePerMinute] and [hostName] (route
/// query `rate` and `host`) produce the "≈ x min with `host`" hint.
class BuyDiamondsPage extends StatelessWidget {
  const BuyDiamondsPage({super.key, this.ratePerMinute, this.hostName});

  final int? ratePerMinute;
  final String? hostName;

  /// Approximate talk time for display only (labelled "≈").
  String? _hint(DiamondPackage p) {
    final rate = ratePerMinute;
    if (rate == null || rate <= 0) return null;
    final tenths = p.diamonds * 10 ~/ rate;
    final minutes = tenths < 100
        ? '${tenths ~/ 10}.${tenths % 10}'
        : '${tenths ~/ 10}';
    return hostName == null
        ? '≈ $minutes min at ${DashuriFormat.count(rate)}/min'
        : '≈ $minutes min with $hostName';
  }

  static int columnsFor(double width) => width < 600
      ? 2
      : width < 900
      ? 3
      : 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(RoutePaths.wallet),
        ),
        title: const Text('Buy Diamonds'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<PurchaseBloc, PurchaseState>(
          builder: (context, state) {
            final bloc = context.read<PurchaseBloc>();
            if (state.status == PurchaseStatus.initial ||
                state.status == PurchaseStatus.loading) {
              return const LoadingView();
            }
            if (state.packages.isEmpty) {
              return state.failure != null
                  ? ErrorStateView(
                      message: PurchaseCopy.failure(state.failure!),
                      onRetry: () =>
                          bloc.add(const PurchasePackagesRequested()),
                    )
                  : const EmptyStateView(
                      icon: Icons.diamond_outlined,
                      title: 'No packs available',
                      message: 'Diamond packs are not on sale right now.',
                    );
            }
            final selected = state.selectedPackage;
            final provisional = state.packages.any((p) => p.provisional);
            return Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = columnsFor(constraints.maxWidth);
                      final rows = <List<DiamondPackage>>[
                        for (var i = 0; i < state.packages.length; i += cols)
                          state.packages.sublist(
                            i,
                            (i + cols).clamp(0, state.packages.length),
                          ),
                      ];
                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: DashuriTokens.space4,
                        ),
                        children: [
                          ResponsiveCenter(
                            maxWidth: cols > 2
                                ? DashuriTokens.maxWideContentWidth
                                : DashuriTokens.maxContentWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (state.currentBalance != null)
                                  _BalanceRow(balance: state.currentBalance!),
                                const SizedBox(height: DashuriTokens.space3),
                                for (final row in rows)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: DashuriTokens.space3,
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (var c = 0; c < cols; c++) ...[
                                            if (c > 0)
                                              const SizedBox(
                                                width: DashuriTokens.space3,
                                              ),
                                            Expanded(
                                              child: c < row.length
                                                  ? PackageCard(
                                                      package: row[c],
                                                      hint: _hint(row[c]),
                                                      selected:
                                                          row[c].productId ==
                                                          state
                                                              .selectedProductId,
                                                      onTap: () => bloc.add(
                                                        PurchasePackageHighlighted(
                                                          row[c].productId,
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: DashuriTokens.space2),
                                _Note(
                                  icon: Icons.receipt_outlined,
                                  text:
                                      'Prices include GST · Purchased Diamonds never expire',
                                ),
                                if (provisional)
                                  const _Note(
                                    icon: Icons.info_outline,
                                    text:
                                        'Prices are provisional and may change before launch.',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                ResponsiveCenter(
                  padding: EdgeInsets.fromLTRB(
                    context.pageGutter,
                    DashuriTokens.space2,
                    context.pageGutter,
                    DashuriTokens.space3,
                  ),
                  child: PrimaryButton(
                    label: selected == null
                        ? 'Choose a pack'
                        : 'Continue · ${PurchaseCopy.price(selected)}',
                    onPressed: selected == null
                        ? null
                        : () => context.push(
                            RoutePaths.withParams(RoutePaths.checkout, {
                              'productId': selected.productId,
                            }),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Current balance', style: theme.textTheme.bodyMedium),
          ),
          CurrencyAmount.diamonds(balance),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
