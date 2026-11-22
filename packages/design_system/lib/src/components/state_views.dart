import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../tokens/dashuri_tokens.dart';

/// Full-area loading indicator with an optional message.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (message != null) ...[
          const SizedBox(height: DashuriTokens.space4),
          Text(message!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    ),
  );
}

/// Empty state (C04, CH03, …): icon, title, message and an optional action.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    required this.icon,
    required this.title,
    super.key,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageGutter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: DashuriTokens.space5),
              Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: DashuriTokens.space2),
                Text(
                  message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: DashuriTokens.space6),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry action. Pass a user-facing message, never a
/// raw exception.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.message,
    super.key,
    // Neutral and accurate for both offline and server errors ("Something
    // went wrong" contradicted messages like "You're offline").
    this.title = "Couldn't load this",
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyStateView(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: message,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// Placeholder rows shown while a list loads (inbox, notifications, call
/// history, transactions). Same pulse as the Discover card skeleton, so
/// loading looks the same everywhere; static when the system asks for
/// reduced motion. Announced once as "Loading".
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 6, this.avatar = true});

  final int rows;

  /// Leading circle (people) or rounded square (transactions, calls).
  final bool avatar;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusSmall),
        ),
      ),
    );
    return Semantics(
      label: 'Loading',
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: .45, end: 1).animate(_c),
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: context.pageGutter,
              vertical: DashuriTokens.space3,
            ),
            itemCount: widget.rows,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: DashuriTokens.space3,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: widget.avatar
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: widget.avatar
                          ? null
                          : BorderRadius.circular(DashuriTokens.radiusMedium),
                    ),
                  ),
                  const SizedBox(width: DashuriTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(i.isEven ? .55 : .4, 14),
                        const SizedBox(height: DashuriTokens.space2),
                        bar(i.isEven ? .8 : .7, 12),
                      ],
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
