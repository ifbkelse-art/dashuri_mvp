import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/consents_cubit.dart';
import '../widgets/settings_list.dart';

/// S05 notification settings, backed by the DPDP consents
/// (GET/PUT /v1/me/consents). Safety and account notices are always on.
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BlocConsumer<ConsentsCubit, ConsentsState>(
        listenWhen: (a, b) =>
            b.saveFailure != null && a.saveFailure != b.saveFailure,
        listener: (context, state) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Couldn't save. ${failureMessage(state.saveFailure!)}",
                ),
              ),
            ),
        builder: (context, state) {
          final cubit = context.read<ConsentsCubit>();
          if (state.loading) return const LoadingView();
          if (state.data == null) {
            return ErrorStateView(
              title: "Couldn't load these settings",
              message: failureMessage(state.failure!),
              onRetry: cubit.load,
            );
          }
          final data = state.data!;
          return SettingsList(
            children: [
              const SizedBox(height: DashuriTokens.space4),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Offers and reminders'),
                      subtitle: const Text(
                        'Occasional offers and reminders, such as an unused '
                        'Free Call Card.',
                      ),
                      value: data.marketing,
                      onChanged: state.saving ? null : cubit.setMarketing,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Help improve Dashuri'),
                      subtitle: const Text(
                        'Share anonymous usage data so we can fix problems. '
                        'Never includes messages or calls.',
                      ),
                      value: data.analytics,
                      onChanged: state.saving ? null : cubit.setAnalytics,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DashuriTokens.space4),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Safety & account'),
                  subtitle: const Text(
                    'Report outcomes, security alerts, messages, purchases '
                    'and receipts. Always on.',
                  ),
                  trailing: Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: DashuriTokens.space3),
              Text(
                'You can also turn notification categories off in your '
                "phone's settings.",
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
