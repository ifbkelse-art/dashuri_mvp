import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/transaction_detail_cubit.dart';
import '../../domain/entities/wallet_entry.dart';
import '../widgets/transaction_row.dart';
import '../widgets/wallet_format.dart';

/// W09 receipt-style transaction detail.
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction')),
      body: SafeArea(
        top: false,
        child: BlocBuilder<TransactionDetailCubit, TransactionDetailState>(
          builder: (context, state) => switch (state) {
            TransactionDetailLoading() => const LoadingView(),
            TransactionDetailFailed(:final failure) => ErrorStateView(
              message: WalletFormat.failureMessage(
                failure,
                subject: 'this transaction',
              ),
              onRetry: () => context.read<TransactionDetailCubit>().load(),
            ),
            TransactionDetailLoaded(:final entry) => _Receipt(entry: entry),
          },
        ),
      ),
    );
  }
}

class _Receipt extends StatelessWidget {
  const _Receipt({required this.entry});

  final WalletEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = WalletFormat.iconColors(entry, theme.colorScheme);
    final beans = WalletFormat.isBeans(entry);
    final rows = <(String, String)>[
      ('Date', WalletFormat.dateTime(entry.createdAt)),
      ('Currency', beans ? 'Beans' : 'Diamonds'),
      if (entry.reference != null) ('Reference', entry.reference!),
      ('Ledger ref.', entry.id),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space4),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(DashuriTokens.space5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(
                          DashuriTokens.radiusLarge,
                        ),
                      ),
                      child: Icon(
                        WalletFormat.icon(entry),
                        color: fg,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: DashuriTokens.space4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (beans)
                            const BeanIcon(size: 26)
                          else
                            const DiamondIcon(size: 26),
                          const SizedBox(width: DashuriTokens.space2),
                          Text(
                            WalletFormat.signedAmount(entry),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      WalletFormat.title(entry),
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DashuriTokens.space3),
                    const StatusTag(
                      label: 'Completed',
                      tone: StatusTone.success,
                    ),
                    const Divider(height: DashuriTokens.space8),
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label and value share the row (2:3) so
                            // neither overflows at large text.
                            Flexible(
                              flex: 2,
                              child: Text(
                                label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: DashuriTokens.space4),
                            Expanded(
                              flex: 3,
                              child: SelectableText(
                                value,
                                textAlign: TextAlign.end,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: DashuriTokens.space4),
              ListCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.support_outlined),
                    title: const Text('Get help with this transaction'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      Uri(
                        path: RoutePaths.helpSupport,
                        queryParameters: {'ref': entry.reference ?? entry.id},
                      ).toString(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
