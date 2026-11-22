import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

/// Dashboard columns: 1 on phones, 2 on medium windows, 3 on expanded.
int hostColumns(BuildContext context) => switch (context.windowSize) {
  WindowSize.compact => 1,
  WindowSize.medium => 2,
  WindowSize.expanded => 3,
};

/// Lays [children] out in [hostColumns] equal columns.
class HostCardGrid extends StatelessWidget {
  const HostCardGrid({
    required this.children,
    super.key,
    this.columns,
    this.spacing = DashuriTokens.space3,
  });

  final List<Widget> children;
  final int? columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final cols = columns ?? hostColumns(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

/// Wide scrollable page body for dashboards (max 1200 dp).
class HostWideBody extends StatelessWidget {
  const HostWideBody({required this.children, super.key, this.onRefresh});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: DashuriTokens.space8),
      children: [
        ResponsiveCenter(
          maxWidth: DashuriTokens.maxWideContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Single-column readable body for forms and explainers.
class HostFormBody extends StatelessWidget {
  const HostFormBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(
      top: DashuriTokens.space2,
      bottom: DashuriTokens.space8,
    ),
    children: [
      ResponsiveCenter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );
}

/// Bottom action area pinned under a form (respects safe area and width).
class HostBottomBar extends StatelessWidget {
  const HostBottomBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      // Not ResponsiveCenter: its Align would expand to the full height.
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DashuriTokens.maxContentWidth,
          ),
          // Capped at 45% of the visible height so large text or a long
          // notice never pushes the page off screen; scrolls inside.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom) *
                  .45,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.pageGutter,
                DashuriTokens.space3,
                context.pageGutter,
                DashuriTokens.space3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// White rounded card with a hairline border (DS07).
class HostCard extends StatelessWidget {
  const HostCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(DashuriTokens.space4),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        side: BorderSide(color: borderColor ?? scheme.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Small stat card ("TODAY 69,106 ≈ ₹345.53").
class HostStatCard extends StatelessWidget {
  const HostStatCard({
    required this.label,
    required this.value,
    super.key,
    this.caption,
  });

  final String label;
  final Widget value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DashuriTokens.space2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: theme.textTheme.headlineSmall,
              child: value,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: DashuriTokens.space1),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// The dark Beans card used by H10, H14 and H21.
class BeansHeroCard extends StatelessWidget {
  const BeansHeroCard({
    required this.label,
    required this.beans,
    super.key,
    this.trailing,
    this.suffix,
    this.caption,
    this.children = const [],
  });

  final String label;
  final int beans;
  final String? trailing;
  final String? suffix;
  final String? caption;
  final List<Widget> children;

  static const background = Color(0xFF1E1714);
  static const goldLight = Color(0xFFE9C98A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onDark = Color(0xFFF7F3EE);
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DashuriTokens.radiusXLarge),
        gradient: const LinearGradient(
          colors: [background, Color(0xFF3A2A1E)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: goldLight,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: DashuriTokens.space2),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .4,
                  ),
                  child: Text(
                    trailing!,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onDark.withValues(alpha: .7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: DashuriTokens.space3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CurrencyAmount.beans(
                  beans,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: onDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: DashuriTokens.space2),
                  Text(
                    suffix!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: onDark.withValues(alpha: .7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: DashuriTokens.space2),
            Text(
              caption!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: onDark.withValues(alpha: .75),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Navigation row with an icon tile and chevron (H11 quick links, H23, H24).
class HostLinkTile extends StatelessWidget {
  const HostLinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
    this.subtitle,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Not a ListTile: with large text a long trailing value made ListTile
    // assert ("trailing consumes the entire tile width"). Title and subtitle
    // wrap; the trailing value takes at most 40% of the row.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DashuriTokens.minTapTarget + 16,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DashuriTokens.space4,
                vertical: DashuriTokens.space2,
              ),
              child: LayoutBuilder(
                builder: (context, c) => Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(
                          DashuriTokens.radiusMedium,
                        ),
                      ),
                      child: Icon(icon, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(width: DashuriTokens.space4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium),
                          if (subtitle != null)
                            Text(subtitle!, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (trailingText != null) ...[
                      const SizedBox(width: DashuriTokens.space2),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth * .4),
                        child: Text(
                          trailingText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
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

/// A group of [HostLinkTile]s in one card with dividers.
class HostLinkGroup extends StatelessWidget {
  const HostLinkGroup({required this.tiles, super.key, this.title});

  final String? title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DashuriTokens.space1,
              DashuriTokens.space5,
              0,
              DashuriTokens.space2,
            ),
            child: Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        HostCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 72),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum TimelineState { done, current, pending }

/// One step of a vertical status timeline (H07, H18).
class HostTimelineStep extends StatelessWidget {
  const HostTimelineStep({
    required this.title,
    required this.state,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final TimelineState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (bg, fg, icon) = switch (state) {
      TimelineState.done => (DashuriTokens.success, Colors.white, Icons.check),
      TimelineState.current => (scheme.primary, scheme.onPrimary, Icons.circle),
      TimelineState.pending => (
        scheme.surfaceContainerHigh,
        scheme.onSurfaceVariant,
        null,
      ),
    };
    return Semantics(
      label: '$title, ${state.name}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: icon == null
                  ? null
                  : Icon(
                      icon,
                      size: state == TimelineState.current ? 10 : 16,
                      color: fg,
                    ),
            ),
            const SizedBox(width: DashuriTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: state == TimelineState.pending
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline info/warning banner (H10 level note, H14 hold explainer).
class HostNotice extends StatelessWidget {
  const HostNotice({
    required this.message,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.tone = StatusTone.info,
  });

  final String message;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      StatusTone.warning => (DashuriTokens.warning100, DashuriTokens.warning),
      StatusTone.error => (DashuriTokens.error100, DashuriTokens.error),
      StatusTone.success => (DashuriTokens.success100, DashuriTokens.success),
      _ => (DashuriTokens.info100, DashuriTokens.info),
    };
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: DashuriTokens.space3),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large round icon used at the top of status screens (H07, H08, H18, H21).
class HostHeroIcon extends StatelessWidget {
  const HostHeroIcon({
    required this.icon,
    super.key,
    this.color,
    this.background,
  });

  final IconData icon;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        color: background ?? DashuriTokens.gold100,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 44, color: color ?? DashuriTokens.goldDark),
    ),
  );
}

/// Step progress bar for the application flow ("3/6").
class HostStepProgress extends StatelessWidget implements PreferredSizeWidget {
  const HostStepProgress({required this.step, super.key, this.total = 6});

  final int step;
  final int total;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageGutter,
        0,
        context.pageGutter,
        DashuriTokens.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Step $step of $total',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
                child: LinearProgressIndicator(
                  value: step / total,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHigh,
                ),
              ),
            ),
          ),
          const SizedBox(width: DashuriTokens.space3),
          Text('$step/$total', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Large page title ("Earnings", "Calls") for tab roots.
class HostLargeTitle extends StatelessWidget {
  const HostLargeTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: DashuriTokens.space4,
      bottom: DashuriTokens.space4,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.displaySmall),
        ),
        ?trailing,
      ],
    ),
  );
}

void showHostSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
