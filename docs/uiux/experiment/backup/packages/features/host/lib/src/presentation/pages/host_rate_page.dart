import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_rate_cubit.dart';
import '../../domain/entities/host_earnings.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H10 set your rate (RoutePaths.hostRate, PUT /v1/host/rate).
class HostRatePage extends StatelessWidget {
  const HostRatePage({super.key, this.fromApplication = false});

  /// Part of FL04: saving continues to the review screen (H07).
  final bool fromApplication;

  static String errorText(RateError error, int limit) => switch (error) {
    RateError.belowMinimum => 'The minimum rate is 500 Diamonds per minute.',
    RateError.abovePlatformMaximum =>
      'The maximum rate is 10,000 Diamonds per minute.',
    RateError.aboveLevelLimit =>
      'Your level allows up to ${DashuriFormat.count(limit)} Diamonds per minute.',
  };

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<HostRateCubit, HostRateState>(
        listenWhen: (a, b) => a.status != b.status || a.failure != b.failure,
        listener: (context, state) {
          if (state.status == HostRateStatus.saved) {
            if (fromApplication) {
              context.go(RoutePaths.hostVerification);
            } else {
              showHostSnack(
                context,
                'Rate saved. It applies from your next call.',
              );
              if (context.canPop()) context.pop();
            }
          } else if (state.status == HostRateStatus.ready &&
              state.failure != null &&
              state.error == null) {
            showHostSnack(context, hostFailureMessage(state.failure!));
          }
        },
        builder: (context, state) {
          final cubit = context.read<HostRateCubit>();
          return Scaffold(
            appBar: AppBar(
              title: const Text('Your rate'),
              bottom: fromApplication ? const HostStepProgress(step: 5) : null,
            ),
            body: switch (state.status) {
              HostRateStatus.loading => const LoadingView(),
              HostRateStatus.loadFailed => ErrorStateView(
                message: hostFailureMessage(state.failure!),
                onRetry: cubit.load,
              ),
              _ => _RateEditor(state: state),
            },
            bottomNavigationBar:
                state.status == HostRateStatus.loading ||
                    state.status == HostRateStatus.loadFailed
                ? null
                : HostBottomBar(
                    children: [
                      Text(
                        'Changes apply from your next call.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: DashuriTokens.space2),
                      PrimaryButton(
                        label: 'Save rate',
                        busy: state.status == HostRateStatus.saving,
                        onPressed: state.error == null ? cubit.save : null,
                      ),
                    ],
                  ),
          );
        },
      );
}

class _RateEditor extends StatelessWidget {
  const _RateEditor({required this.state});

  final HostRateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HostRateCubit>();
    final beans = state.beansPerMinute;
    final paisePerMin = BeanRules.beansToPaise(beans);
    Widget stepButton(IconData icon, String label, VoidCallback onTap) =>
        IconButton.outlined(
          onPressed: onTap,
          tooltip: label,
          iconSize: 28,
          style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
          icon: Icon(icon),
        );
    return HostFormBody(
      children: [
        Text(
          "Customers pay this rate in Diamonds for every second you're on a call.",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space6),
        Row(
          children: [
            stepButton(Icons.remove, 'Lower rate', cubit.decrement),
            Expanded(
              child: Column(
                children: [
                  FittedBox(
                    child: CurrencyAmount.diamonds(
                      state.rate,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFamily: theme.textTheme.titleLarge?.fontFamily,
                      ),
                    ),
                  ),
                  Text(
                    'DIAMONDS / MINUTE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            stepButton(Icons.add, 'Raise rate', cubit.increment),
          ],
        ),
        const SizedBox(height: DashuriTokens.space4),
        Slider(
          value: state.rate
              .clamp(BeanRules.minRate, BeanRules.maxRate)
              .toDouble(),
          min: BeanRules.minRate.toDouble(),
          max: BeanRules.maxRate.toDouble(),
          divisions:
              (BeanRules.maxRate - BeanRules.minRate) ~/ BeanRules.rateStep,
          label: DashuriFormat.count(state.rate),
          onChanged: (v) => cubit.setRate(v.round()),
        ),
        Row(
          children: [
            const Text('500'),
            Expanded(
              child: Text(
                'Your limit ${DashuriFormat.count(state.limit)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Text('10,000'),
          ],
        ),
        if (state.error != null) ...[
          const SizedBox(height: DashuriTokens.space3),
          HostNotice(
            tone: StatusTone.error,
            icon: Icons.error_outline_rounded,
            message: HostRatePage.errorText(state.error!, state.limit),
          ),
        ],
        const SizedBox(height: DashuriTokens.space5),
        BeansHeroCard(
          label: 'You earn',
          beans: beans,
          suffix: 'Beans / min',
          trailing: '${HostFormat.approxRupees(paisePerMin)}/min',
          caption:
              '${HostFormat.approxRupees(paisePerMin * 60)} for every hour on calls '
              '(approximate, before tax)',
        ),
        const SizedBox(height: DashuriTokens.space4),
        const HostNotice(
          icon: Icons.trending_up_rounded,
          message:
              'Your level sets your maximum rate. Level up to unlock higher rates.',
        ),
      ],
    );
  }
}
