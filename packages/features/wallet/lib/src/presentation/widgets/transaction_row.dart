import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/wallet_entry.dart';
import 'wallet_format.dart';

/// One ledger entry row (DS10 transaction row).
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.entry,
    required this.onTap,
    super.key,
    this.showDay = true,
  });

  final WalletEntry entry;
  final VoidCallback onTap;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = WalletFormat.iconColors(
      entry,
      theme.colorScheme,
      DashuriColors.of(context),
    );
    final positive = entry.amount > 0;
    final subtitle = [
      if (showDay) WalletFormat.day(entry.createdAt),
      WalletFormat.time(entry.createdAt),
      if (WalletFormat.isBeans(entry)) 'Beans',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DashuriTokens.space4,
          vertical: DashuriTokens.space3,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
              ),
              child: Icon(WalletFormat.icon(entry), color: fg, size: 22),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    WalletFormat.title(entry),
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: DashuriTokens.space2),
            // Natural width at the end, capped so a large amount at large
            // text wraps instead of pushing the row past the screen edge.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      WalletFormat.signedAmount(entry),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleSmall?.copyWith(
                        // AA-safe green for text in both themes.
                        color: positive
                            ? DashuriColors.of(context).positiveText
                            : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (WalletFormat.isBeans(entry))
                    const BeanIcon(size: 14)
                  else
                    const DiamondIcon(size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded card that groups rows with dividers.
class ListCard extends StatelessWidget {
  const ListCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            children[i],
          ],
        ],
      ),
    );
  }
}
