import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

/// Customer wallet hero (DS10): available Diamond balance and actions.
class WalletHero extends StatelessWidget {
  const WalletHero({
    required this.availableDiamonds,
    required this.onBuy,
    required this.onHistory,
    super.key,
  });

  final int availableDiamonds;
  final VoidCallback onBuy;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onHero = DashuriTokens.neutral0;
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusXLarge),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [DashuriTokens.burgundy600, DashuriTokens.burgundy900],
        ),
        boxShadow: DashuriTokens.shadow2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'DIAMOND BALANCE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onHero.withValues(alpha: .75),
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Icon(
                Icons.diamond_outlined,
                color: onHero.withValues(alpha: .7),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: DashuriTokens.space3),
          Row(
            children: [
              const DiamondIcon(size: 32, color: DashuriTokens.burgundy200),
              const SizedBox(width: DashuriTokens.space3),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    DashuriFormat.count(availableDiamonds),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: onHero,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DashuriTokens.space2),
          Text(
            'Available to spend on calls',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onHero.withValues(alpha: .75),
            ),
          ),
          const SizedBox(height: DashuriTokens.space5),
          Wrap(
            spacing: DashuriTokens.space3,
            runSpacing: DashuriTokens.space3,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: onHero,
                  foregroundColor: DashuriTokens.neutral900,
                ),
                onPressed: onBuy,
                icon: const Icon(Icons.add),
                label: const Text('Buy Diamonds'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: onHero.withValues(alpha: .14),
                  foregroundColor: onHero,
                ),
                onPressed: onHistory,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('History'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
