import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';

/// A02 welcome for signed-out users.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.backendConfigured = true});

  /// False in development builds without `config/<env>.json`.
  final bool backendConfigured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = !context.windowSize.isCompact;
    final hero = _ArchTrio(height: wide ? 300 : 240);
    final copy = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!backendConfigured) ...[
          const InfoBanner(
            tone: InfoBannerTone.error,
            icon: Icons.cloud_off_rounded,
            message:
                'Backend not configured. This development build has no '
                'API or Supabase settings, so sign-in will not work. Run '
                'with --dart-define-from-file=config/development.json.',
          ),
          const SizedBox(height: DashuriTokens.space5),
        ],
        const DashuriMonogram(size: 48),
        const SizedBox(height: DashuriTokens.space5),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Meet someone '),
              TextSpan(
                text: 'real',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.primary,
                ),
              ),
              const TextSpan(text: ',\nface to face.'),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        const SizedBox(height: DashuriTokens.space3),
        Text(
          'Private one-to-one video calls with verified hosts who are '
          'online right now.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: DashuriTokens.space6),
        PrimaryButton(
          label: 'Create account',
          onPressed: () => context.push('${RoutePaths.signIn}?mode=register'),
        ),
        const SizedBox(height: DashuriTokens.space3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push(RoutePaths.signIn),
            child: const Text('I already have an account'),
          ),
        ),
        if (const bool.fromEnvironment('DASHURI_UI_PREVIEW'))
          TextButton(
            onPressed: () => context.go(RoutePaths.discovery),
            child: const Text('Skip (UI preview)'),
          ),
        const SizedBox(height: DashuriTokens.space4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'By continuing you confirm you are 18 or older and agree to our',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () => context.push('${RoutePaths.legal}?doc=terms'),
              child: const Text('Terms'),
            ),
            Text('and', style: theme.textTheme.bodySmall),
            TextButton(
              onPressed: () => context.push('${RoutePaths.legal}?doc=privacy'),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 840) {
              return Row(
                children: [
                  Expanded(child: Center(child: hero)),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(context.pageGutter),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: copy,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.pageGutter,
                vertical: DashuriTokens.space6,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      hero,
                      const SizedBox(height: DashuriTokens.space6),
                      copy,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Decorative arched shapes standing in for verified-host imagery (A02
/// uses only verified-host photos, which come from the server later).
class _ArchTrio extends StatelessWidget {
  const _ArchTrio({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    Widget arch(double h, List<Color> colors) => Expanded(
      child: Container(
        height: h,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(h),
            bottom: const Radius.circular(DashuriTokens.radiusLarge),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: DashuriTokens.shadow2,
        ),
      ),
    );
    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              arch(height * 0.78, const [
                DashuriTokens.burgundy200,
                DashuriTokens.burgundy500,
              ]),
              arch(height, const [DashuriTokens.gold100, DashuriTokens.gold]),
              arch(height * 0.7, const [
                DashuriTokens.burgundy300,
                DashuriTokens.burgundy800,
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
