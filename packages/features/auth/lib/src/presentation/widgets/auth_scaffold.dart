import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';

/// Shared layout for onboarding steps: back button, optional step bar,
/// a serif headline, body text, scrollable content and a pinned action.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
    this.step,
    this.bottom,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// 1-based onboarding step out of [totalSteps]; null hides the bar.
  final int? step;
  final List<Widget> children;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;

  static const totalSteps = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBack && (onBack != null || Navigator.canPop(context))
            ? BackButton(onPressed: onBack)
            : null,
        title: step == null
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: OnboardingStepBar(step: step!, total: totalSteps),
              ),
      ),
      body: FormPageBody(
        bottom: bottom,
        children: [
          const SizedBox(height: DashuriTokens.space4),
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.displaySmall),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DashuriTokens.space2),
            Text(
              subtitle!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DashuriTokens.space6),
          ...children,
        ],
      ),
    );
  }
}
