import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/diamond_package.dart';
import 'purchase_copy.dart';

/// DS10 package card: default and selected states, optional ribbon.
class PackageCard extends StatelessWidget {
  const PackageCard({
    required this.package,
    required this.selected,
    required this.onTap,
    super.key,
    this.hint,
  });

  final DiamondPackage package;
  final bool selected;
  final VoidCallback onTap;

  /// Talk-time hint, e.g. "≈ 22 min with Ananya".
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (package.label ?? '').toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.radio_button_checked,
                      color: scheme.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: DashuriTokens.space2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CurrencyAmount.diamonds(
                  package.diamonds,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hint != null)
                // Two lines: "≈ 22 min with Ananya" was cut to "with An…"
                // in the two-column grid (Phase 9).
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                PurchaseCopy.price(package),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? scheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: '${package.diamonds} Diamonds for ${PurchaseCopy.price(package)}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: const EdgeInsets.only(top: 10), child: card),
          if (package.badge != null)
            Positioned(
              left: 14,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
                ),
                child: Text(
                  package.badge!.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
