import 'package:flutter/material.dart';

import '../tokens/dashuri_tokens.dart';
import 'currency_icons.dart';
import 'formatting.dart';

/// Diamond balance pill with a top-up "+" (C01 header).
class BalancePill extends StatelessWidget {
  const BalancePill({required this.diamonds, super.key, this.onTap});

  final int? diamonds;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label: diamonds == null ? 'Wallet' : '${diamonds!} Diamonds. Buy more',
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DiamondIcon(),
                const SizedBox(width: 8),
                Text(
                  diamonds == null ? '—' : DashuriFormat.count(diamonds!),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Amount with currency glyph, e.g. "◆ 2,400 /min".
class CurrencyAmount extends StatelessWidget {
  const CurrencyAmount.diamonds(
    this.amount, {
    super.key,
    this.suffix,
    this.style,
  }) : beans = false;
  const CurrencyAmount.beans(this.amount, {super.key, this.suffix, this.style})
    : beans = true;

  final int amount;
  final bool beans;
  final String? suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style ?? Theme.of(context).textTheme.titleMedium!;
    final size = (s.fontSize ?? 16) * 1.05;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (beans) BeanIcon(size: size) else DiamondIcon(size: size),
        const SizedBox(width: 6),
        Text(
          DashuriFormat.count(amount) + (suffix ?? ''),
          style: s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    );
  }
}

enum StatusTone {
  online,
  busy,
  offline,
  success,
  warning,
  error,
  info,
  neutral,
}

/// Small status tag ("Online", "Pending", "Verified"…), DS07.
class StatusTag extends StatelessWidget {
  const StatusTag({
    required this.label,
    required this.tone,
    super.key,
    this.dot = false,
  });

  final String label;
  final StatusTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.online => (DashuriTokens.success100, DashuriTokens.success),
      StatusTone.busy => (DashuriTokens.warning100, DashuriTokens.warning),
      StatusTone.offline => (
        DashuriTokens.neutral100,
        DashuriTokens.neutral600,
      ),
      StatusTone.success => (DashuriTokens.success100, DashuriTokens.success),
      StatusTone.warning => (DashuriTokens.warning100, DashuriTokens.warning),
      StatusTone.error => (DashuriTokens.error100, DashuriTokens.error),
      StatusTone.info => (DashuriTokens.info100, DashuriTokens.info),
      StatusTone.neutral => (
        DashuriTokens.neutral100,
        DashuriTokens.neutral700,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: tone == StatusTone.online ? DashuriTokens.online : fg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Avatar from a URL with initials fallback (never crashes on bad URLs).
class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.name, super.key, this.url, this.radius = 24});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * .7,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Section header with an optional trailing action (DS08).
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: DashuriTokens.space6,
      bottom: DashuriTokens.space2,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Full-width primary action that shows a progress indicator while busy.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (icon == null ? const SizedBox.shrink() : Icon(icon)),
      label: Text(label),
    ),
  );
}

/// Shows a confirmation dialog; resolves true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
