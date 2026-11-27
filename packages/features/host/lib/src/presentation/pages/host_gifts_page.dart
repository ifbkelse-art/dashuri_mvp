import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_gifts_cubit.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// Gifts the host received: totals, then each gift with sender, time,
/// Diamond value, the host's Beans and whether they are still on hold.
class HostGiftsPage extends StatelessWidget {
  const HostGiftsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gifts received')),
    body: BlocBuilder<HostGiftsCubit, HostGiftsState>(
      builder: (context, s) => switch (s) {
        HostGiftsLoading() => const LoadingView(),
        HostGiftsFailed(:final failure) => ErrorStateView(
          title: "Couldn't load your gifts",
          message: hostFailureMessage(failure),
          onRetry: context.read<HostGiftsCubit>().load,
        ),
        final HostGiftsLoaded l => RefreshIndicator(
          onRefresh: context.read<HostGiftsCubit>().load,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) {
                context.read<HostGiftsCubit>().loadMore();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.all(DashuriTokens.space4),
              children: [
                HostCardGrid(
                  children: [
                    HostStatCard(
                      label: 'Gifts',
                      value: Text(DashuriFormat.count(l.summary.totalGifts)),
                    ),
                    HostStatCard(
                      label: 'Beans earned',
                      value: CurrencyAmount.beans(l.summary.totalBeans),
                    ),
                    HostStatCard(
                      label: 'Diamond value',
                      value: CurrencyAmount.diamonds(
                        l.summary.totalDiamondValue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DashuriTokens.space3),
                if (l.items.isEmpty)
                  const EmptyStateView(
                    icon: Icons.card_giftcard_rounded,
                    title: 'No gifts yet',
                    message:
                        'Gifts customers send during calls will appear here.',
                  ),
                for (final g in l.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      g.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      '${g.giftName} from ${g.senderName.isEmpty ? 'a customer' : g.senderName}',
                    ),
                    subtitle: Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(g.sentAt.toLocal())} · '
                      '${TimeOfDay.fromDateTime(g.sentAt.toLocal()).format(context)} · '
                      '${DashuriFormat.count(g.diamondValue)} Diamonds',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CurrencyAmount.beans(g.beansEarned),
                        Text(
                          g.onHold ? 'On hold' : 'Released',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                if (l.loadingMore)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      },
    ),
  );
}
