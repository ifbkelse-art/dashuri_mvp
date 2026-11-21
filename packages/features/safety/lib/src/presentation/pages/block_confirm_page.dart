import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/block_cubit.dart';
import '../widgets/safety_copy.dart';

/// V13 block confirmation, at `RoutePaths.report?mode=block&userId=…&name=…`.
/// Shown as a centred dialog card over a scrim. Pops with `true` once the
/// user is blocked, `false` on cancel.
class BlockConfirmPage extends StatelessWidget {
  const BlockConfirmPage({required this.name, super.key});

  final String name;

  void _close(BuildContext context, bool blocked) {
    if (context.canPop()) {
      context.pop(blocked);
    } else {
      context.go(RoutePaths.discovery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<BlockCubit, BlockState>(
      listenWhen: (a, b) => !a.done && b.done,
      listener: (context, state) => _close(context, true),
      builder: (context, state) => Scaffold(
        backgroundColor: theme.colorScheme.scrim.withValues(alpha: 0.45),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(context.pageGutter),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusXLarge,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DashuriTokens.space6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(name: name, radius: 32),
                        const SizedBox(height: DashuriTokens.space4),
                        Semantics(
                          header: true,
                          child: Text(
                            'Block $name?',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: DashuriTokens.space2),
                        Text(
                          "You won't see each other on Dashuri, and neither "
                          'of you can call or message the other. They '
                          "won't be notified.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (state.failure != null) ...[
                          const SizedBox(height: DashuriTokens.space4),
                          InfoBanner(
                            tone: InfoBannerTone.error,
                            message: safetyFailureMessage(state.failure!),
                          ),
                        ],
                        const SizedBox(height: DashuriTokens.space6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                              foregroundColor: theme.colorScheme.onError,
                            ),
                            onPressed: state.busy
                                ? null
                                : context.read<BlockCubit>().confirm,
                            child: state.busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Block'),
                          ),
                        ),
                        const SizedBox(height: DashuriTokens.space2),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => _close(context, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
