import 'package:flutter/material.dart';

import '../theme/dashuri_colors.dart';
import '../tokens/dashuri_tokens.dart';

/// Brand monogram ("D" with a gold spark), A01/A02.
class DashuriMonogram extends StatelessWidget {
  const DashuriMonogram({super.key, this.size = 56, this.inverted = false});

  final double size;

  /// White tile with burgundy letter (for dark backgrounds).
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final bg = inverted ? DashuriTokens.neutral0 : DashuriTokens.burgundy700;
    final fg = inverted ? DashuriTokens.burgundy700 : DashuriTokens.neutral0;
    return Semantics(
      label: 'Dashuri',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * 0.24),
          boxShadow: DashuriTokens.shadow2,
        ),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ExcludeSemantics(
              child: Text(
                'D',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: fg,
                  fontSize: size * 0.58,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              right: -size * 0.12,
              top: -size * 0.02,
              child: Icon(
                Icons.auto_awesome,
                size: size * 0.2,
                color: DashuriTokens.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented onboarding progress ("3/6"), A04–A12 header.
class OnboardingStepBar extends StatelessWidget {
  const OnboardingStepBar({required this.step, required this.total, super.key});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Step $step of $total',
      child: Row(
        children: [
          for (var i = 1; i <= total; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < total) const SizedBox(width: 6),
          ],
          const SizedBox(width: DashuriTokens.space3),
          ExcludeSemantics(
            child: Text(
              '$step/$total',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded group of navigation rows (S01, S03, S08).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Semantics(
              header: true,
              child: Text(
                title!.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(indent: 72, height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row inside a [SettingsGroup]: icon tile, title, optional value and chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.value,
    this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: destructive
              ? scheme.errorContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    value!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (onTap != null && !destructive)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
    );
  }
}

/// Selectable option card used for single-choice questions (A11, A12, S04).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    required this.title,
    required this.selected,
    required this.onTap,
    super.key,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
          ),
          child: Padding(
            padding: const EdgeInsets.all(DashuriTokens.space4),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: DashuriTokens.space3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: DashuriTokens.space2),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum InfoBannerTone { info, warning, error, success }

/// Inline notice box (V11 call warning, A15, S09 balance warning).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.message,
    super.key,
    this.tone = InfoBannerTone.info,
    this.icon,
  });

  final String message;
  final InfoBannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Semantic tones (light/dark): text meets WCAG AA (4.5:1) on its tint;
    // see test/theme_contrast_test.dart.
    final c = DashuriColors.of(context);
    final (t, defaultIcon) = switch (tone) {
      InfoBannerTone.info => (c.info, Icons.info_outline),
      InfoBannerTone.warning => (c.warning, Icons.warning_amber_rounded),
      InfoBannerTone.error => (c.error, Icons.error_outline),
      InfoBannerTone.success => (c.success, Icons.check_circle_outline),
    };
    final (bg, fg, iconColor) = (t.container, t.onContainer, t.icon);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DashuriTokens.space4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: iconColor, size: 22),
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

/// Scrollable single-column page body with an optional bottom action area
/// that stays visible (forms, onboarding). Width capped for tablets.
class FormPageBody extends StatelessWidget {
  const FormPageBody({
    required this.children,
    super.key,
    this.bottom,
    this.maxWidth = DashuriTokens.maxContentWidth,
  });

  final List<Widget> children;
  final Widget? bottom;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 600
        ? DashuriTokens.space5
        : DashuriTokens.space8;
    Widget constrain(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
    return SafeArea(
      top: false,
      // LayoutBuilder: the cap below must use the height this body really
      // has (Scaffold removes the keyboard inset from MediaQuery here).
      child: LayoutBuilder(
        builder: (context, c) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: DashuriTokens.space6),
                child: constrain(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
            // The pinned actions take at most 45% of the visible height and
            // scroll inside it, so a long error or large text never pushes
            // the form (or the actions themselves) off screen.
            if (bottom != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: c.maxHeight * .45),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(
                    top: DashuriTokens.space2,
                    bottom: DashuriTokens.space4,
                  ),
                  child: constrain(bottom!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A label at the start of a row and a value at its end ("Your age · 28
/// years", "Total · ₹1,199"). The label takes the remaining width and
/// wraps; the value keeps its natural width at the end, up to
/// [maxValueFraction] of the row, and wraps beyond that. Never overflows,
/// and (unlike Expanded + Flexible) never splits the row in half.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    required this.label,
    required this.value,
    super.key,
    this.maxValueFraction = .5,
    this.gap = DashuriTokens.space3,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final Widget label;
  final Widget value;
  final double maxValueFraction;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Row(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Expanded(child: label),
        SizedBox(width: gap),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: c.maxWidth * maxValueFraction),
          child: value,
        ),
      ],
    ),
  );
}
