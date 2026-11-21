import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/free_call_card_cubit.dart';
import '../../application/free_call_match_cubit.dart';

/// Plain-language copy for Free Call Card failures.
String freeCallFailureMessage(Failure f) => switch (f) {
  NetworkFailure() => "You're offline. Check your connection and try again.",
  _ => switch (f.code) {
    'integrity_unavailable' =>
      "We couldn't verify this device with Google Play. Make sure Google Play "
          'services are up to date and try again.',
    'integrity_check_failed' =>
      "This device couldn't be verified, so the free call isn't available.",
    'integrity_not_configured' ||
    'free_call_disabled' => "Free calls aren't available right now.",
    'card_already_used' => "You've already used your Free Call Card.",
    'device_already_used' =>
      'A Free Call Card was already used on this device.',
    'free_call_unavailable_on_platform' =>
      "Free calls aren't available on this device.",
    'not_age_eligible' => 'Calls are only for verified adults (18+).',
    'account_restricted' => "Your account can't make calls right now.",
    'phone_required' => 'Add a verified phone number to use the free call.',
    'caller_in_call' => "You're already in another call.",
    _ => 'Something went wrong. Please try again.',
  },
};

/// C02 card state and C10 matching. Starts matching as soon as the card is
/// confirmed available (the user already tapped "Start free call").
class FreeCallPage extends StatelessWidget {
  const FreeCallPage({super.key, this.supported = true});

  /// False on iOS: the Free Call Card is Android only.
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final dark = DashuriTheme.dark();
    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: DashuriTokens.burgundy950,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: CloseButton(onPressed: () => _leave(context)),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -.2),
              radius: 1.1,
              colors: [
                DashuriTokens.burgundy800,
                DashuriTokens.burgundy950,
                DashuriTokens.neutral950,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: !supported
                ? const _Message(
                    icon: Icons.phone_android_rounded,
                    title: 'Free calls are Android only',
                    message:
                        "The Free Call Card isn't available on this device.",
                  )
                : const _Flow(),
          ),
        ),
      ),
    );
  }
}

void _leave(BuildContext context) {
  context.read<FreeCallMatchCubit?>()?.cancel();
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RoutePaths.discovery);
  }
}

class _Flow extends StatelessWidget {
  const _Flow();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<FreeCallCardCubit, FreeCallCardState>(
        listener: (context, s) {
          if (s is FreeCallCardStateLoaded && s.data.isAvailable) {
            unawaited(context.read<FreeCallMatchCubit>().start());
          }
        },
        builder: (context, card) => switch (card) {
          FreeCallCardStateInitial() ||
          FreeCallCardStateLoading() => const LoadingView(),
          FreeCallCardStateFailed(:final failure) => ErrorStateView(
            message: freeCallFailureMessage(failure),
            onRetry: context.read<FreeCallCardCubit>().load,
          ),
          FreeCallCardStateLoaded(:final data) when !data.isAvailable =>
            _Message(
              icon: Icons.card_giftcard_rounded,
              title: switch (data.status) {
                'used' => 'Free Call Card used',
                'unavailable_on_platform' => 'Free calls are Android only',
                _ => 'Free call not available',
              },
              message: switch (data.status) {
                'used' =>
                  "You've already had your free minute. Buy Diamonds to call "
                      'any host.',
                'unavailable_on_platform' =>
                  "The Free Call Card isn't available on this device.",
                _ => 'The Free Call Card is for new customers only.',
              },
              actionLabel: data.status == 'used' ? 'Buy Diamonds' : null,
              onAction: data.status == 'used'
                  ? () => context.push(RoutePaths.buyDiamonds)
                  : null,
            ),
          FreeCallCardStateLoaded() => const _Matching(),
        },
      );
}

class _Matching extends StatelessWidget {
  const _Matching();

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<FreeCallMatchCubit, FreeCallMatchState>(
        listener: (context, s) {
          if (s is FreeCallMatchFound) {
            context.pushReplacement(
              RoutePaths.withParams(RoutePaths.call, {'callId': s.callId}),
            );
          }
        },
        builder: (context, s) {
          final cubit = context.read<FreeCallMatchCubit>();
          return switch (s) {
            FreeCallMatchIdle() ||
            FreeCallMatchSearching() ||
            FreeCallMatchFound() => _Searching(onCancel: () => _leave(context)),
            FreeCallMatchNoHost() => _Message(
              icon: Icons.nightlight_round,
              title: 'No hosts are free right now',
              message:
                  'Your Free Call Card is still unused. Try again in a little '
                  'while.',
              actionLabel: 'Try again',
              onAction: cubit.start,
            ),
            FreeCallMatchCancelled() => _Message(
              icon: Icons.card_giftcard_rounded,
              title: 'Matching cancelled',
              message: 'Your Free Call Card is still unused.',
              actionLabel: 'Try again',
              onAction: cubit.start,
            ),
            FreeCallMatchFailed(:final failure) => _Message(
              icon: Icons.error_outline_rounded,
              title: "We couldn't start your free call",
              message: freeCallFailureMessage(failure),
              actionLabel: 'Try again',
              onAction: cubit.start,
            ),
          };
        },
      );
}

class _Searching extends StatefulWidget {
  const _Searching({required this.onCancel});

  final VoidCallback onCancel;

  @override
  State<_Searching> createState() => _SearchingState();
}

class _SearchingState extends State<_Searching>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final ring = (c.biggest.shortestSide * .55).clamp(120.0, 300.0);
        return SingleChildScrollView(
          padding: EdgeInsets.all(context.pageGutter),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: c.maxHeight - context.pageGutter * 2,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Text(
                          'Free Call Card · 1 min free',
                          style: TextStyle(color: DashuriTokens.gold100),
                        ),
                      ),
                    ),
                    const SizedBox(height: DashuriTokens.space6),
                    SizedBox.square(
                      dimension: ring,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final f in const [1.0, .78, .56])
                              Container(
                                width: ring * f,
                                height: ring * f,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: .08 + .2 * (1 - _pulse.value) * f,
                                    ),
                                  ),
                                ),
                              ),
                            Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: ring * .22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: DashuriTokens.space6),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        'Finding someone for you…',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: DashuriTokens.space3),
                    Text(
                      "We're matching you with a host who's online now. Your "
                      "free minute starts when you're both connected.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DashuriTokens.space8),
                    OutlinedButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: EmptyStateView(
          icon: icon,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(DashuriTokens.space4),
        child: TextButton(
          onPressed: () => context.go(RoutePaths.discovery),
          child: const Text('Back to Discover'),
        ),
      ),
    ],
  );
}
