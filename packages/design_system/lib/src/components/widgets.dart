import 'package:flutter/material.dart';

import '../theme/dashuri_colors.dart';
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
    // A compact header chip: its number must never truncate, so its text
    // grows with the system size only up to 1.5x (still clearly larger).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Semantics(
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
    // One Text (glyph as an inline span), not a Row: it wraps when the
    // space is bounded (narrow cells, large text) and keeps its natural
    // width when it is not (inside FittedBox / IntrinsicHeight), where a
    // Flexible or LayoutBuilder would throw.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: beans ? BeanIcon(size: size) : DiamondIcon(size: size),
            ),
          ),
          TextSpan(text: DashuriFormat.count(amount) + (suffix ?? '')),
        ],
      ),
      style: s.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
    final c = DashuriColors.of(context);
    final t = switch (tone) {
      StatusTone.online || StatusTone.success => c.success,
      StatusTone.busy || StatusTone.warning => c.warning,
      StatusTone.offline || StatusTone.neutral => c.neutral,
      StatusTone.error => c.error,
      StatusTone.info => c.info,
    };
    final (bg, fg) = (t.container, t.onContainer);
    final text = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dot ? 99 : 14),
      ),
      // Without a dot the tag is just text: it wraps when space is bounded
      // (large text, narrow screens) and keeps its natural width when not
      // (e.g. inside a FittedBox). Dot tags are short availability labels.
      child: !dot
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tone == StatusTone.online ? t.icon : fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                text,
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
        // Long messages at large text sizes scroll instead of overflowing.
        scrollable: true,
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
