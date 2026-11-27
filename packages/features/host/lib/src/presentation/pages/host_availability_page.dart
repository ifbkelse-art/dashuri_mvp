import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/host_dashboard_cubit.dart';
import '../widgets/host_copy.dart';
import '../widgets/host_widgets.dart';

/// H13 availability and free calls (HostPaths.availability).
class HostAvailabilityPage extends StatelessWidget {
  const HostAvailabilityPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<HostDashboardCubit, HostDashboardState>(
    listenWhen: (a, b) =>
        b is HostDashboardStateLoaded &&
        b.actionFailure != null &&
        (a is! HostDashboardStateLoaded || a.actionFailure != b.actionFailure),
    listener: (context, state) => showHostSnack(
      context,
      hostFailureMessage((state as HostDashboardStateLoaded).actionFailure!),
    ),
    builder: (context, state) {
      final cubit = context.read<HostDashboardCubit>();
      return Scaffold(
        appBar: AppBar(title: const Text('Availability')),
        body: switch (state) {
          HostDashboardStateInitial() ||
          HostDashboardStateLoading() => const LoadingView(),
          HostDashboardStateFailed(:final failure) => ErrorStateView(
            title: "Couldn't load your availability",
            message: hostFailureMessage(failure),
            onRetry: cubit.load,
          ),
          final HostDashboardStateLoaded s => _Body(state: s),
        },
      );
    },
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final HostDashboardStateLoaded state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<HostDashboardCubit>();
    final host = state.data;
    return HostFormBody(
      children: [
        HostCard(
          padding: const EdgeInsets.symmetric(horizontal: DashuriTokens.space2),
          child: SwitchListTile(
            value: host.isAvailable,
            onChanged: state.updating || !host.isApproved
                ? null
                : (v) => cubit.setAvailable(available: v),
            title: const Text('Online'),
            subtitle: Text(
              host.isApproved
                  ? 'Customers can see you and call you'
                  : 'Available once your application is approved',
            ),
          ),
        ),
        const SectionHeader(title: 'Free Call Card'),
        HostCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                value: host.freeCallOptIn,
                contentPadding: EdgeInsets.zero,
                onChanged: state.updating
                    ? null
                    : (v) => cubit.setFreeCallOptIn(optIn: v),
                title: const Text('Accept free calls'),
                subtitle: const Text('One-minute calls with new customers'),
              ),
              const Divider(),
              LabelValueRow(
                label: Text(
                  'You earn per completed free minute',
                  style: theme.textTheme.bodyMedium,
                ),
                value: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const CurrencyAmount.beans(2000),
                    Text(' (≈ ₹10)', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: DashuriTokens.space2),
              Text(
                'Free calls are matched randomly among hosts who opted in. '
                'Up to 20 per day.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        HostLinkGroup(
          title: 'Messages',
          tiles: [
            HostLinkTile(
              icon: Icons.mark_chat_read_outlined,
              title: 'Who can message me',
              onTap: () => context.push(RoutePaths.privacyMessaging),
            ),
          ],
        ),
        const SizedBox(height: DashuriTokens.space5),
        const HostNotice(
          icon: Icons.favorite_border_rounded,
          tone: StatusTone.success,
          message:
              "You're always free to decline any call or end it at any time. "
              'There are no quotas or penalties.',
        ),
      ],
    );
  }
}
