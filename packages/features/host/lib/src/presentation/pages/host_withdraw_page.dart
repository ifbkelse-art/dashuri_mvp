import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_withdraw_cubit.dart';
import '../../domain/entities/host_earnings.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H16 withdraw, H17 confirm, H18 requested, H21 withdrawals unavailable and
/// H25 below minimum (RoutePaths.hostWithdraw, POST /v1/host/withdrawals).
class HostWithdrawPage extends StatelessWidget {
  const HostWithdrawPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<HostWithdrawCubit, HostWithdrawState>(
        listenWhen: (a, b) => a.failure != b.failure && b.failure != null,
        listener: (context, state) {
          if (state.phase != WithdrawPhase.loadFailed) {
            showHostSnack(context, hostFailureMessage(state.failure!));
          }
        },
        builder: (context, state) {
          final cubit = context.read<HostWithdrawCubit>();
          final (Widget body, Widget? bottom) = switch (state.phase) {
            WithdrawPhase.loading => (const LoadingView(), null),
            WithdrawPhase.loadFailed => (
              ErrorStateView(
                message: hostFailureMessage(state.failure!),
                onRetry: cubit.load,
              ),
              null,
            ),
            WithdrawPhase.editing || WithdrawPhase.submitting => (
              _AmountForm(state: state),
              HostBottomBar(
                children: [
                  PrimaryButton(
                    label: 'Withdraw ${DashuriFormat.rupees(state.amountPaise)}',
                    busy: state.phase == WithdrawPhase.submitting,
                    onPressed: state.amountError == null
                        ? () => _confirm(context, state)
                        : null,
                  ),
                ],
              ),
            ),
            WithdrawPhase.belowMinimum => (
              _BelowMinimum(earnings: state.earnings!),
              const HostBottomBar(
                children: [PrimaryButton(label: 'Withdraw', onPressed: null)],
              ),
            ),
            WithdrawPhase.requested => (
              _Requested(state: state),
              HostBottomBar(
                children: [
                  PrimaryButton(
                    label: 'Done',
                    onPressed: () => context.go(RoutePaths.hostEarnings),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.pushReplacement(RoutePaths.hostPayoutHistory),
                    child: const Text('View payout history'),
                  ),
                ],
              ),
            ),
            WithdrawPhase.payoutsDisabled => (
              _Unavailable(earnings: state.earnings!),
              HostBottomBar(
                children: [
                  OutlinedButton(
                    onPressed: () => context.push(RoutePaths.hostPayoutMethod),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        DashuriTokens.buttonHeight,
                      ),
                    ),
                    child: const Text('About payout methods'),
                  ),
                ],
              ),
            ),
          };
          final showTitle =
              state.phase != WithdrawPhase.requested &&
              state.phase != WithdrawPhase.payoutsDisabled;
          return Scaffold(
            appBar: AppBar(title: showTitle ? const Text('Withdraw') : null),
            body: body,
            bottomNavigationBar: bottom,
          );
        },
      );

  /// H17 confirmation sheet.
  static Future<void> _confirm(
    BuildContext context,
    HostWithdrawState state,
  ) async {
    final cubit = context.read<HostWithdrawCubit>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        Widget row(String a, Widget b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space2),
          child: Row(
            children: [
              Expanded(child: Text(a, style: theme.textTheme.bodyMedium)),
              b,
            ],
          ),
        );
        return SafeArea(
          child: SingleChildScrollView(
            child: ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Confirm withdrawal',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: DashuriTokens.space3),
                  row('Beans', CurrencyAmount.beans(state.beans)),
                  row(
                    'Amount',
                    Text(
                      HostFormat.approxRupees(state.amountPaise),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  row(
                    'Expected',
                    Text(
                      state.earnings?.nextPayoutDate == null
                          ? 'Next weekly payout'
                          : HostFormat.date(state.earnings!.nextPayoutDate!),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: DashuriTokens.space2),
                  Text(
                    'Tax deducted at source (if any) will be shown on your payout '
                    'slip. Payouts flagged for review are held until checks are '
                    'complete.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: DashuriTokens.space4),
                  PrimaryButton(
                    label: 'Confirm withdrawal',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: DashuriTokens.space2),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (confirmed ?? false) await cubit.submit();
  }
}

class _AmountForm extends StatefulWidget {
  const _AmountForm({required this.state});

  final HostWithdrawState state;

  @override
  State<_AmountForm> createState() => _AmountFormState();
}

class _AmountFormState extends State<_AmountForm> {
  late final TextEditingController _beans = TextEditingController(
    text: '${widget.state.beans}',
  );

  @override
  void dispose() {
    _beans.dispose();
    super.dispose();
  }

  void _set(int beans) {
    _beans.text = '$beans';
    context.read<HostWithdrawCubit>().setBeans(beans);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final earnings = state.earnings!;
    final available = earnings.beansAvailable;
    final presets = <(String, int)>[
      ('₹500', BeanRules.minWithdrawalBeans),
      if (available >= 200000) ('₹1,000', 200000),
      ('Max', available),
    ];
    Widget kv(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: DashuriTokens.space2),
      child: Row(
        children: [
          Expanded(child: Text(a, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              b,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
    return HostFormBody(
      children: [
        Text(
          'AMOUNT',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            HostFormat.approxRupees(state.amountPaise),
            style: theme.textTheme.displayMedium,
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        TextField(
          controller: _beans,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(
            labelText: 'Beans to withdraw',
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: BeanIcon(size: 20),
            ),
            errorText: switch (state.amountError) {
              null => null,
              WithdrawAmountError.belowMinimum =>
                'The minimum is 1,00,000 Beans (₹500).',
              WithdrawAmountError.aboveAvailable =>
                'You have ${DashuriFormat.count(available)} withdrawable Beans.',
            },
          ),
          onChanged: (v) =>
              context.read<HostWithdrawCubit>().setBeans(int.tryParse(v) ?? 0),
        ),
        const SizedBox(height: DashuriTokens.space3),
        Wrap(
          spacing: DashuriTokens.space2,
          children: [
            for (final (label, beans) in presets)
              ChoiceChip(
                label: Text(label),
                selected: state.beans == beans,
                onSelected: (_) => _set(beans),
              ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          'Available ${DashuriFormat.rupees(earnings.availableInrPaise)} · '
          'Minimum ₹500',
          style: theme.textTheme.bodySmall,
        ),
        const SectionHeader(title: 'Pay to'),
        HostCard(
          padding: EdgeInsets.zero,
          child: HostLinkTile(
            icon: Icons.account_balance_outlined,
            title: 'Payout method',
            subtitle: 'Set up when payouts launch',
            onTap: () => context.push(RoutePaths.hostPayoutMethod),
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        kv('Paid in', 'Next weekly payout'),
        kv(
          'Expected',
          earnings.nextPayoutDate == null
              ? 'Shown after you request'
              : HostFormat.date(earnings.nextPayoutDate!),
        ),
        kv('Tax (TDS)', 'Shown on payout slip'),
      ],
    );
  }
}

class _BelowMinimum extends StatelessWidget {
  const _BelowMinimum({required this.earnings});

  final HostEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missing = BeanRules.minWithdrawalBeans - earnings.beansAvailable;
    final progress = earnings.beansAvailable / BeanRules.minWithdrawalBeans;
    return HostFormBody(
      children: [
        Text(
          'AVAILABLE TO WITHDRAW',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          DashuriFormat.rupees(earnings.availableInrPaise),
          style: theme.textTheme.displayMedium,
        ),
        CurrencyAmount.beans(
          earnings.beansAvailable,
          suffix: ' Beans',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: DashuriTokens.space5),
        HostNotice(
          tone: StatusTone.warning,
          icon: Icons.info_outline_rounded,
          message:
              'Minimum withdrawal is ₹500. You need '
              '${HostFormat.approxRupees(BeanRules.beansToPaise(missing))} more '
              '(${DashuriFormat.count(missing)} Beans).'
              '${earnings.beansOnHold > 0 ? ' On-hold Beans worth ${HostFormat.approxRupees(BeanRules.beansToPaise(earnings.beansOnHold))} become withdrawable 7 days after you earned them.' : ''}',
        ),
        const SizedBox(height: DashuriTokens.space5),
        Row(
          children: [
            Expanded(
              child: Text(
                'Progress to ₹500',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${(progress * 100).clamp(0, 100).floor()}%',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space2),
        ClipRRect(
          borderRadius: BorderRadius.circular(DashuriTokens.radiusPill),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1).toDouble(),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _Requested extends StatelessWidget {
  const _Requested({required this.state});

  final HostWithdrawState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = state.withdrawal!;
    return HostFormBody(
      children: [
        const SizedBox(height: DashuriTokens.space4),
        const HostHeroIcon(
          icon: Icons.check_rounded,
          color: DashuriTokens.success,
          background: DashuriTokens.success100,
        ),
        const SizedBox(height: DashuriTokens.space5),
        Text(
          'Withdrawal requested',
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        Text(
          DashuriFormat.rupees(w.amountPaise),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          "We'll include it in the next weekly payout.",
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space5),
        HostCard(
          child: Column(
            children: [
              HostTimelineStep(
                title: 'Requested',
                subtitle:
                    '${HostFormat.date(w.requestedAt)}, ${HostFormat.time(w.requestedAt)}',
                state: TimelineState.done,
              ),
              const HostTimelineStep(
                title: 'Processing',
                subtitle: 'Weekly payout run',
                state: TimelineState.current,
              ),
              HostTimelineStep(
                title: 'Paid',
                subtitle: state.earnings?.nextPayoutDate == null
                    ? null
                    : 'Expected ${HostFormat.date(state.earnings!.nextPayoutDate!)}',
                state: TimelineState.pending,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.earnings});

  final HostEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HostFormBody(
      children: [
        const SizedBox(height: DashuriTokens.space4),
        const HostHeroIcon(icon: Icons.account_balance_outlined),
        const SizedBox(height: DashuriTokens.space5),
        Text(
          'Withdrawals are coming soon',
          style: theme.textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space2),
        Text(
          "We're finishing the setup needed to pay hosts safely and legally. "
          'Your Beans are safe and never expire.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: DashuriTokens.space5),
        BeansHeroCard(
          label: 'Your Beans',
          beans: earnings.balanceBeans,
          trailing: HostFormat.approxRupees(
            earnings.availableInrPaise +
                BeanRules.beansToPaise(earnings.beansOnHold),
          ),
        ),
        const SizedBox(height: DashuriTokens.space3),
        const HostNotice(
          icon: Icons.notifications_active_outlined,
          message: "We'll notify you the moment withdrawals open.",
        ),
      ],
    );
  }
}
