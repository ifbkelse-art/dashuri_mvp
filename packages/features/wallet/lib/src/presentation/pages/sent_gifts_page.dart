import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/sent_gifts_cubit.dart';

/// Gifts the customer sent: gift, recipient, Diamond cost, date. The same
/// spends appear in the wallet history as "Gift sent".
class SentGiftsPage extends StatelessWidget {
  const SentGiftsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gifts sent')),
    body: BlocBuilder<SentGiftsCubit, SentGiftsState>(
      builder: (context, s) => switch (s) {
        SentGiftsLoading() => const LoadingView(),
        SentGiftsFailed() => ErrorStateView(
          message: "Your gifts couldn't load. Please try again.",
          onRetry: context.read<SentGiftsCubit>().load,
        ),
        SentGiftsLoaded(:final items) when items.isEmpty =>
          const EmptyStateView(
            icon: Icons.card_giftcard_rounded,
            title: 'No gifts sent yet',
            message: 'Gifts you send during calls will appear here.',
          ),
        final SentGiftsLoaded l => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 300) {
              context.read<SentGiftsCubit>().loadMore();
            }
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(DashuriTokens.space4),
            itemCount: l.items.length + (l.loadingMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i >= l.items.length) {
                return const Center(child: CircularProgressIndicator());
              }
              final g = l.items[i];
              final local = g.sentAt.toLocal();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(g.emoji, style: const TextStyle(fontSize: 28)),
                title: Text(
                  '${g.giftName} to ${g.recipientName.isEmpty ? 'a host' : g.recipientName}',
                ),
                subtitle: Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(local)} · '
                  '${TimeOfDay.fromDateTime(local).format(context)} · during a call',
                ),
                trailing: CurrencyAmount.diamonds(-g.diamondCost),
              );
            },
          ),
        ),
      },
    ),
  );
}
