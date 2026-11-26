import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/purchase_bloc.dart';
import '../../domain/entities/diamond_package.dart';
import '../../domain/entities/payment_rail.dart';
import '../../domain/entities/payment_result.dart';
import '../widgets/purchase_copy.dart';

/// W03 checkout: order summary and payment rail. W04 "processing" is the
/// payment UI itself (Play sheet or Cashfree checkout) plus the processing
/// view below while the server confirms.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({required this.productId, super.key, this.preferredRail});

  final String productId;

  /// From `?rail=` (W06 "Try again" keeps the same rail).
  final PaymentRail? preferredRail;

  static String resultPath(PaymentResult r) => RoutePaths.withParams(
    RoutePaths.paymentResult,
    {'orderId': r.orderId.isEmpty ? 'pending' : r.orderId},
  );

  Future<void> _pay(BuildContext context, PurchaseState state) async {
    final bloc = context.read<PurchaseBloc>();
    PaymentRail? rail;
    if (preferredRail != null && state.rails.contains(preferredRail)) {
      rail = preferredRail;
    } else if (state.rails.length == 1) {
      rail = state.rails.first;
    } else {
      rail = await showModalBottomSheet<PaymentRail>(
        context: context,
        showDragHandle: true,
        builder: (context) => _RailSheet(rails: state.rails),
      );
    }
    switch (rail) {
      case PaymentRail.googlePlay:
        bloc.add(PurchasePackageSelected(productId));
      case PaymentRail.cashfree:
        bloc.add(PurchaseCashfreeRequested(productId));
      case null:
        break;
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showConfirmDialog(
      context,
      title: 'Leave checkout?',
      message:
          'Your payment is still being confirmed. If you paid, your Diamonds '
          'will be added automatically.',
      confirmLabel: 'Leave',
    );
    if (leave && context.mounted) context.go(RoutePaths.wallet);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseBloc, PurchaseState>(
      listenWhen: (a, b) => a.result != b.result || a.status != b.status,
      listener: (context, state) {
        final result = state.result;
        if (result != null &&
            (state.status == PurchaseStatus.completed ||
                state.status == PurchaseStatus.pendingPayment)) {
          context.pushReplacement(resultPath(result), extra: result);
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.isProcessing,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave(context);
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Checkout')),
            body: SafeArea(top: false, child: _body(context, state)),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PurchaseState state) {
    final bloc = context.read<PurchaseBloc>();
    if (state.status == PurchaseStatus.initial ||
        state.status == PurchaseStatus.loading) {
      return const LoadingView();
    }
    if (state.packages.isEmpty && state.failure != null) {
      return ErrorStateView(
        message: PurchaseCopy.failure(state.failure!),
        onRetry: () =>
            bloc.add(PurchasePackagesRequested(productId: productId)),
      );
    }
    if (state.isProcessing) return _Processing(state: state);
    final package = state.packages
        .where((p) => p.productId == productId)
        .firstOrNull;
    if (package == null) {
      return EmptyStateView(
        icon: Icons.diamond_outlined,
        title: 'Pack not available',
        message: 'This pack is no longer on sale. Pick another pack.',
        actionLabel: 'See packs',
        onAction: () => context.pushReplacement(RoutePaths.buyDiamonds),
      );
    }
    final noRail = state.rails.isEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space4),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Summary(package: package),
                    const SizedBox(height: DashuriTokens.space5),
                    if (noRail)
                      _Banner(
                        icon: Icons.info_outline,
                        text: state.serverRails.contains(PaymentRail.googlePlay)
                            ? 'Buying Diamonds needs Google Play on an Android '
                                  "device. It isn't available here."
                            : 'Purchases are not available right now. '
                                  'Please try again later.',
                      )
                    else ...[
                      Text(
                        'Payment method',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: DashuriTokens.space2),
                      for (final r in state.rails)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            r == PaymentRail.googlePlay
                                ? Icons.shop_outlined
                                : Icons.account_balance_wallet_outlined,
                          ),
                          title: Text(PurchaseCopy.rail(r)),
                          subtitle: Text(PurchaseCopy.railDetail(r)),
                        ),
                    ],
                    if (state.status == PurchaseStatus.failed &&
                        state.failure != null) ...[
                      const SizedBox(height: DashuriTokens.space4),
                      _Banner(
                        icon: Icons.error_outline,
                        error: true,
                        text: PurchaseCopy.failure(state.failure!),
                        action: state.canRetryVerification
                            ? TextButton(
                                onPressed: () => bloc.add(
                                  const PurchaseVerificationRetried(),
                                ),
                                child: const Text('Retry confirmation'),
                              )
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ResponsiveCenter(
          padding: EdgeInsets.fromLTRB(
            context.pageGutter,
            DashuriTokens.space2,
            context.pageGutter,
            DashuriTokens.space3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                label: 'Pay ${PurchaseCopy.price(package)}',
                onPressed: noRail || state.canRetryVerification
                    ? null
                    : () => _pay(context, state),
              ),
              const SizedBox(height: DashuriTokens.space2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Diamonds are added only after the payment is verified.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.package});

  final DiamondPackage package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusLarge),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DashuriTokens.burgundy50,
                  borderRadius: BorderRadius.circular(
                    DashuriTokens.radiusMedium,
                  ),
                ),
                child: const Center(child: DiamondIcon(size: 26)),
              ),
              const SizedBox(width: DashuriTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PurchaseCopy.packageName(package),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${DashuriFormat.count(package.diamonds)} Diamonds',
                      style: muted,
                    ),
                  ],
                ),
              ),
              Text(
                PurchaseCopy.price(package),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const Divider(height: DashuriTokens.space6),
          Row(
            children: [
              Expanded(child: Text('Total', style: theme.textTheme.titleSmall)),
              Text(
                PurchaseCopy.price(package),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Includes GST', style: muted),
          if (package.provisional) ...[
            const SizedBox(height: 4),
            Text('Provisional price', style: muted),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.error = false,
    this.action,
  });

  final IconData icon;
  final String text;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = error
        ? (DashuriTokens.error100, DashuriTokens.error)
        : (DashuriTokens.info100, DashuriTokens.info);
    return Container(
      padding: const EdgeInsets.all(DashuriTokens.space3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DashuriTokens.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: DashuriTokens.space2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          ?action,
        ],
      ),
    );
  }
}

class _RailSheet extends StatelessWidget {
  const _RailSheet({required this.rails});

  final Set<PaymentRail> rails;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: DashuriTokens.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How would you like to pay?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DashuriTokens.space2),
            for (final r in PaymentRail.values.where(rails.contains))
              ListTile(
                leading: Icon(
                  r == PaymentRail.googlePlay
                      ? Icons.shop_outlined
                      : Icons.account_balance_wallet_outlined,
                ),
                title: Text(PurchaseCopy.rail(r)),
                subtitle: Text(PurchaseCopy.railDetail(r)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, r),
              ),
          ],
        ),
      ),
    );
  }
}

class _Processing extends StatelessWidget {
  const _Processing({required this.state});

  final PurchaseState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, body) = switch (state.status) {
      PurchaseStatus.inStore => (
        'Complete the purchase in Google Play',
        'Follow the steps in the Google Play window.',
      ),
      PurchaseStatus.verifying => (
        'Confirming your purchase',
        'Checking the purchase with Google Play…',
      ),
      PurchaseStatus.creatingOrder => (
        'Preparing secure checkout',
        'Setting up your order…',
      ),
      PurchaseStatus.inCashfree => (
        'Complete the payment',
        'Approve the payment in the Cashfree window or your UPI app.',
      ),
      _ => ('Waiting for confirmation', "Please don't close this screen."),
    };
    final order = state.cashfreeOrder;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.pageGutter),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 72,
                child: CircularProgressIndicator(strokeWidth: 5),
              ),
              const SizedBox(height: DashuriTokens.space6),
              Text(
                title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                body,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (order != null) ...[
                const SizedBox(height: DashuriTokens.space5),
                Text(
                  '${DashuriFormat.rupees(order.amountPaise)} · Order ${order.orderId}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
