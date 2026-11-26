import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/gift_sheet_bloc.dart';
import '../../domain/entities/gift.dart';
import 'gift_copy.dart';
import 'gift_visuals.dart';

/// Opens the gift picker over the call. The video keeps playing behind it.
Future<void> showGiftSheet(
  BuildContext context, {
  required GiftSheetBloc bloc,
  required String callId,
  required String recipientUserId,
  required String recipientName,
  VoidCallback? onOpenWallet,
}) {
  bloc.add(GiftSheetOpened(callId: callId, recipientUserId: recipientUserId));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: DashuriTokens.neutral900.withValues(alpha: .96),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: GiftSheet(
        recipientName: recipientName,
        onOpenWallet: onOpenWallet,
      ),
    ),
  );
}

/// Catalogue grid, selected gift, cost, balance and Send.
class GiftSheet extends StatelessWidget {
  const GiftSheet({required this.recipientName, super.key, this.onOpenWallet});

  final String recipientName;

  /// Wallet navigation (null hides the action).
  final VoidCallback? onOpenWallet;

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<GiftSheetBloc, GiftSheetState>(
        listenWhen: (a, b) =>
            (b.sentCount != a.sentCount) ||
            (b.send == GiftSendStatus.failed && b.failure != a.failure),
        listener: (context, s) {
          if (s.send == GiftSendStatus.sent) {
            // The celebration plays over the call: close the sheet.
            Navigator.of(context).maybePop();
          }
        },
        builder: (context, s) {
          final height = MediaQuery.sizeOf(context).height;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height * .72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DashuriTokens.space4,
                0,
                DashuriTokens.space4,
                DashuriTokens.space4,
              ),
              child: switch (s.load) {
                GiftLoadStatus.idle || GiftLoadStatus.loading => const SizedBox(
                  height: 220,
                  child: LoadingView(message: 'Loading gifts…'),
                ),
                GiftLoadStatus.failed => SizedBox(
                  height: 260,
                  child: ErrorStateView(
                    title: "Gifts couldn't load",
                    message: giftFailureMessage(s.failure!),
                    onRetry: () => context.read<GiftSheetBloc>().add(
                      GiftSheetOpened(
                        callId: s.callId!,
                        recipientUserId: s.recipientUserId!,
                      ),
                    ),
                  ),
                ),
                GiftLoadStatus.ready => _Ready(
                  state: s,
                  recipientName: recipientName,
                  onOpenWallet: onOpenWallet,
                ),
              },
            ),
          );
        },
      );
}

class _Ready extends StatelessWidget {
  const _Ready({
    required this.state,
    required this.recipientName,
    required this.onOpenWallet,
  });

  final GiftSheetState state;
  final String recipientName;
  final VoidCallback? onOpenWallet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<GiftSheetBloc>();
    final s = state;
    final selected = s.selected;
    final name = recipientName.isEmpty ? 'the host' : recipientName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Send a gift to $name',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (s.balance != null)
              Semantics(
                label: 'Your balance: ${s.balance} Diamonds',
                child: ExcludeSemantics(
                  child: CurrencyAmount.diamonds(
                    s.balance!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space3),
        if (s.gifts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: DashuriTokens.space6),
            child: Text(
              'No gifts are available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          )
        else
          Flexible(
            child: LayoutBuilder(
              builder: (context, c) {
                final columns = (c.maxWidth / 104).floor().clamp(3, 6);
                return GridView.builder(
                  shrinkWrap: true,
                  itemCount: s.gifts.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: DashuriTokens.space2,
                    crossAxisSpacing: DashuriTokens.space2,
                    childAspectRatio: .78,
                  ),
                  itemBuilder: (context, i) {
                    final g = s.gifts[i];
                    return _GiftTile(
                      gift: g,
                      selected: g.id == s.selectedId,
                      affordable:
                          s.balance == null || s.balance! >= g.diamondPrice,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        bloc.add(GiftSelected(g.id));
                      },
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: DashuriTokens.space3),
        if (!s.callEligible)
          const InfoBanner(
            message: 'The call has ended, so gifts can no longer be sent.',
            tone: InfoBannerTone.warning,
          )
        else if (selected != null && s.insufficient) ...[
          InfoBanner(
            message:
                'Not enough Diamonds for ${selected.name}. You have '
                '${DashuriFormat.count(s.balance ?? 0)}; it costs '
                '${DashuriFormat.count(selected.diamondPrice)}.',
            tone: InfoBannerTone.warning,
          ),
          if (onOpenWallet != null)
            TextButton.icon(
              onPressed: onOpenWallet,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Open wallet'),
            ),
        ] else if (s.send == GiftSendStatus.failed && s.failure != null)
          InfoBanner(
            message: giftFailureMessage(s.failure!),
            tone: InfoBannerTone.error,
          ),
        if (selected != null) ...[
          const SizedBox(height: DashuriTokens.space2),
          Row(
            children: [
              Text(selected.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: DashuriTokens.space2),
              Expanded(
                child: Text(
                  selected.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CurrencyAmount.diamonds(
                selected.diamondPrice,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: DashuriTokens.space3),
        PrimaryButton(
          label: selected == null ? 'Choose a gift' : 'Send ${selected.name}',
          icon: Icons.card_giftcard_rounded,
          busy: s.send == GiftSendStatus.sending,
          onPressed: s.canSend ? () => bloc.add(const GiftSendPressed()) : null,
        ),
      ],
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.gift,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final Gift gift;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = giftTierColor(gift.tier);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${gift.name}, ${gift.diamondPrice} Diamonds'
          '${affordable ? '' : ', not enough Diamonds'}',
      child: Material(
        color: selected
            ? accent.withValues(alpha: .28)
            : Colors.white.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
          side: BorderSide(
            color: selected ? accent : Colors.white.withValues(alpha: .10),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
          child: Opacity(
            opacity: affordable ? 1 : .55,
            child: Padding(
              padding: const EdgeInsets.all(DashuriTokens.space2),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        child: Text(
                          gift.emoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      child: CurrencyAmount.diamonds(
                        gift.diamondPrice,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
