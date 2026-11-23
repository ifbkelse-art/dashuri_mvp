import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/payment_result_cubit.dart';
import '../../domain/entities/payment_rail.dart';
import '../../domain/entities/payment_result.dart';
import '../widgets/purchase_copy.dart';

/// W05 success, W06 failure and W07 pending. Every number comes from the
/// server (credited Diamonds, amount, order reference).
class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(RoutePaths.wallet),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<PaymentResultCubit, PaymentResultState>(
          builder: (context, state) => switch (state) {
            PaymentResultLoading() => const LoadingView(),
            PaymentResultFailed(:final failure) => ErrorStateView(
              title: "We couldn't load this payment",
              message:
                  '${PurchaseCopy.failure(failure)} Your wallet history shows '
                  'every credited purchase.',
              onRetry: () => context.read<PaymentResultCubit>().load(),
            ),
            PaymentResultLoaded(:final result, :final checking) => _Result(
              result: result,
              checking: checking,
            ),
          },
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.result, required this.checking});

  final PaymentResult result;
  final bool checking;

  String _checkoutPath({PaymentRail? rail}) => Uri(
    path: RoutePaths.withParams(RoutePaths.checkout, {
      'productId': result.productId,
    }),
    queryParameters: rail == null ? null : {'rail': rail.wire},
  ).toString();

  String get _supportPath => Uri(
    path: RoutePaths.helpSupport,
    queryParameters: {if (result.orderId.isNotEmpty) 'ref': result.orderId},
  ).toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = result.orderId.isEmpty ? null : result.orderId;
    final amount = result.amountPaise == null
        ? null
        : DashuriFormat.rupees(result.amountPaise!);
    final (
      IconData icon,
      DashuriTone tone,
      String over,
      String title,
      String body,
    ) = switch (result.outcome) {
      PaymentOutcome.success => (
        Icons.check_rounded,
        DashuriColors.of(context).success,
        'Payment successful',
        '+${DashuriFormat.count(result.diamondsCredited)}',
        'Diamonds added to your wallet',
      ),
      PaymentOutcome.failed => (
        Icons.close_rounded,
        DashuriColors.of(context).error,
        'Payment failed',
        "Payment didn't go through",
        '${PurchaseCopy.failureReason(result.failureCode)} '
            'No Diamonds were added.',
      ),
      PaymentOutcome.pending => (
        Icons.schedule_rounded,
        DashuriColors.of(context).warning,
        'Pending',
        'Confirming your payment',
        'This is taking a little longer than usual. Your Diamonds will be '
            'added as soon as the payment is confirmed. You can leave this '
            'screen; your balance will update.',
      ),
    };
    final rows = <(String, Widget)>[
      if (amount != null)
        (
          result.outcome == PaymentOutcome.success ? 'Paid' : 'Amount',
          Text(amount),
        ),
      if (result.diamonds != null && result.outcome != PaymentOutcome.success)
        ('Diamonds', CurrencyAmount.diamonds(result.diamonds!)),
      if (result.outcome == PaymentOutcome.pending)
        ('Status', const StatusTag(label: 'Pending', tone: StatusTone.warning)),
      ('Method', Text(PurchaseCopy.rail(result.rail))),
      if (ref != null) ('Order', SelectableText(ref)),
    ];
    final actions = <Widget>[
      ...switch (result.outcome) {
        PaymentOutcome.success => [
          PrimaryButton(
            label: 'Start a call',
            onPressed: () => context.go(RoutePaths.discovery),
          ),
          TextButton(
            onPressed: () => context.go(RoutePaths.wallet),
            child: const Text('Back to wallet'),
          ),
        ],
        PaymentOutcome.failed => [
          PrimaryButton(
            label: amount == null ? 'Try again' : 'Try again · $amount',
            onPressed: () =>
                context.pushReplacement(_checkoutPath(rail: result.rail)),
          ),
          const SizedBox(height: DashuriTokens.space2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.pushReplacement(_checkoutPath()),
              child: const Text('Use another method'),
            ),
          ),
          TextButton(
            onPressed: () => context.push(_supportPath),
            child: const Text('Contact support'),
          ),
        ],
        PaymentOutcome.pending => [
          PrimaryButton(
            label: 'Got it',
            onPressed: () => context.go(RoutePaths.wallet),
          ),
          if (result.rail == PaymentRail.cashfree)
            TextButton(
              onPressed: checking
                  ? null
                  : () => context.read<PaymentResultCubit>().recheck(),
              child: Text(checking ? 'Checking…' : 'Check again'),
            ),
        ],
      },
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space6),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: tone.container,
                    shape: BoxShape.circle,
                  ),
                  child: result.outcome == PaymentOutcome.success
                      ? const Center(child: DiamondIcon(size: 48))
                      : Icon(icon, color: tone.icon, size: 48),
                ),
              ),
              const SizedBox(height: DashuriTokens.space5),
              Text(
                over.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  // onContainer is AA on the page surface too (the base
                  // success green is 4.0:1 there).
                  color: tone.onContainer,
                ),
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                title,
                textAlign: TextAlign.center,
                style: result.outcome == PaymentOutcome.success
                    ? theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )
                    : theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (result.outcome == PaymentOutcome.failed) ...[
                const SizedBox(height: DashuriTokens.space4),
                Container(
                  padding: const EdgeInsets.all(DashuriTokens.space3),
                  decoration: BoxDecoration(
                    color: DashuriColors.of(context).info.container,
                    borderRadius: BorderRadius.circular(
                      DashuriTokens.radiusMedium,
                    ),
                  ),
                  child: Text(
                    'If money was debited from your account, it will be '
                    'reversed automatically by your bank or credited here '
                    'once confirmed.${ref == null ? '' : ' Reference $ref.'}',
                    // Dark mode: the default text colour is light; the
                    // tint needs its own on-colour.
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: DashuriColors.of(context).info.onContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: DashuriTokens.space5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusLarge,
                  ),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              rows[i].$1,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: DashuriTokens.space4),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: DefaultTextStyle.merge(
                                  style: theme.textTheme.titleSmall,
                                  textAlign: TextAlign.end,
                                  child: rows[i].$2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: DashuriTokens.space6),
              ...actions,
            ],
          ),
        ),
      ],
    );
  }
}
