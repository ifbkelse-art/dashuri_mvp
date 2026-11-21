import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/session_cubit.dart';

/// A01 splash: shown while the session and account status are restored.
/// If `GET /v1/me` fails, explains it and offers a retry.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key, this.onSignOut});

  /// Lets a signed-in user whose account cannot load sign out.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final white = theme.textTheme.bodyLarge?.copyWith(
      color: DashuriTokens.neutral0,
    );
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [
              Color(0xFF9A2D50),
              DashuriTokens.burgundy700,
              DashuriTokens.burgundy900,
              DashuriTokens.burgundy950,
            ],
            stops: [0, 0.38, 0.78, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.pageGutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<SessionCubit, SessionState>(
                  builder: (context, state) {
                    final failure = switch (state) {
                      SessionSignedIn(:final accountFailure) => accountFailure,
                      _ => null,
                    };
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DashuriMonogram(size: 88, inverted: true),
                        const SizedBox(height: DashuriTokens.space5),
                        Text(
                          'Dashuri',
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: DashuriTokens.neutral0,
                          ),
                        ),
                        const SizedBox(height: DashuriTokens.space2),
                        Text(
                          'Real conversations, face to face.',
                          textAlign: TextAlign.center,
                          style: white,
                        ),
                        const SizedBox(height: DashuriTokens.space8),
                        if (failure == null) ...[
                          const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: DashuriTokens.neutral0,
                              semanticsLabel: 'Loading your account',
                            ),
                          ),
                        ] else ...[
                          Text(
                            "We couldn't load your account.",
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: DashuriTokens.neutral0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DashuriTokens.space2),
                          Text(
                            failureMessage(failure),
                            style: white,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: DashuriTokens.space5),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: DashuriTokens.neutral0,
                              foregroundColor: DashuriTokens.burgundy700,
                            ),
                            onPressed: () =>
                                context.read<SessionCubit>().refreshAccount(),
                            child: const Text('Try again'),
                          ),
                          if (onSignOut != null)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: DashuriTokens.neutral0,
                              ),
                              onPressed: onSignOut,
                              child: const Text('Log out'),
                            ),
                        ],
                        const SizedBox(height: DashuriTokens.space8),
                        Text(
                          'FOR ADULTS 18+ ONLY',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: DashuriTokens.burgundy200,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
